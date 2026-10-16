//
//  SyncEngine.swift
//  Yippy
//
//  Syncs the clipboard history and favourites through the sync server. Platform-independent: it sees the histories
//  through `SyncList`, so it is tested without AppKit.
//

import Foundation

/// What sync needs to know about an item in a history.
struct SyncListItem: Equatable {
    var id: UUID
    var copiedAt: Date?
    var title: String? = nil
    var sourceBundleId: String? = nil
}

/// A history as sync sees it (Adapter over `History`): items in order, their content in the synced formats, and the
/// changes another device's records make.
protocol SyncList: AnyObject {
    var syncItems: [SyncListItem] { get }
    var syncMaxItems: Int { get }
    /// The item's content in the synced formats; empty if it has none of them, nil if it can't be read.
    func syncContent(of id: UUID) -> SyncContent?
    /// Adds an item. Returns its id, or nil if the content can't be stored here.
    func insertSynced(_ content: SyncContent, copiedAt: Date, title: String?, at index: Int) -> UUID?
    func deleteSynced(_ id: UUID)
    func moveSynced(_ id: UUID, to index: Int)
    func setSyncedCopiedAt(_ date: Date, of id: UUID)
    func setSyncedTitle(_ title: String?, of id: UUID)
}

enum SyncStatus: Equatable {
    case off
    case connecting
    case upToDate(lastSynced: Date)
    /// The server can't be reached; changes wait and are sent when it can.
    case offline(message: String)
    /// The server refuses the access key or sync key; nothing syncs until the settings change.
    case refused(message: String)
}

/// Syncs two `SyncList`s (the clipboard history and the favourites) with the user's other devices.
///
/// Sends what the user does: copies, deletions and favourites, never trimming or automatic cleaning, and never copies from
/// apps whose items expire. Keeps a queue of changes to send, so nothing is lost while offline, and waits on the server for
/// other devices' changes (long polling), applying them straight to the lists. Runs on the main thread.
@available(macOS 10.15, *)
@MainActor
final class SyncEngine {
    
    /// How many of the newest history items are sent when sync is turned on (all favourites are).
    static let existingHistorySent = 50
    
    static let longPollWait: TimeInterval = 25
    private static let maxRetryDelay: TimeInterval = 60
    
    private let history: SyncList
    private let favourites: SyncList
    private let keyStore: SyncKeyStore
    private let stateStore: SyncStateStore
    private let makeServer: (SyncConnection) -> SyncServer
    private let now: () -> Date
    private let log: (String) -> Void
    
    /// Whether copies from this app are deleted after a minute, and so never synced.
    var isExpiringSource: (String) -> Bool = { _ in false }
    
    private(set) var key: SyncKey?
    private var state: SyncState
    private var server: SyncServer?
    private var running: Task<Void, Never>?
    private var waiting: Task<Void, Error>?
    
    private(set) var status = SyncStatus.off {
        didSet {
            if status != oldValue {
                onStatusChange?(status)
            }
        }
    }
    
    var onStatusChange: ((SyncStatus) -> Void)?
    
    /// Where to sync, or nil when sync is off. Setting it reconnects.
    private(set) var connection: SyncConnection?
    
    var isEnabled: Bool {
        return connection != nil
    }
    
    var pending: [PendingSyncChange] {
        return state.pending
    }
    
    init(history: SyncList, favourites: SyncList, keyStore: SyncKeyStore, stateStore: SyncStateStore,
         makeServer: @escaping (SyncConnection) -> SyncServer, now: @escaping () -> Date = Date.init, log: @escaping (String) -> Void = { print($0) }) {
        self.history = history
        self.favourites = favourites
        self.keyStore = keyStore
        self.stateStore = stateStore
        self.makeServer = makeServer
        self.now = now
        self.log = log
        key = keyStore.load()
        state = stateStore.load()
        if let key = key, state.spaceId != key.spaceId {
            resetState()
        }
    }
    
    /// Uses this server, or turns sync off with nil. Doesn't start the background loop; `start()` does.
    func configure(server address: URL?, accessKey: String?) {
        if let address = address, let key = key {
            connection = SyncConnection(server: address, accessKey: accessKey, key: key)
        }
        else {
            connection = nil
        }
    }
    
    /// Turns sync on with this server and key, or changes them, and starts syncing in the background.
    func turnOn(server address: URL, accessKey: String?, key newKey: SyncKey) {
        if key != newKey {
            keyStore.save(newKey)
            key = newKey
            resetState()
            saveState()
        }
        let trimmed = accessKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        configure(server: address, accessKey: trimmed?.isEmpty == false ? trimmed : nil)
        start()
    }
    
    func turnOff() {
        connection = nil
        start()
    }
    
    /// Deletes everything this sync key stored on the server, then turns sync off and forgets the key.
    func eraseServerData() async throws {
        if let connection = connection {
            try await makeServer(connection).deleteSpace()
        }
        turnOff()
        keyStore.save(nil)
        key = nil
        resetState()
        saveState()
    }
    
    /// (Re)starts the background loop for the current connection, or stops it if sync is off.
    func start() {
        stop()
        guard connection != nil else {
            status = .off
            return
        }
        running = Task { [weak self] in
            await self?.run()
        }
    }
    
    func stop() {
        running?.cancel()
        running = nil
        waiting?.cancel()
        server = nil
    }
    
    // MARK: - What the user did
    
    func copied(_ id: UUID) {
        guard isEnabled, let item = history.syncItems.first(where: { $0.id == id }), !isFromExpiringApp(item) else {
            return
        }
        queuePut(.history, history, id)
    }
    
    /// Call before deleting, while the items' content can still be read.
    func willDelete(_ ids: [UUID], fromFavourites: Bool) {
        guard isEnabled else {
            return
        }
        let list = fromFavourites ? favourites : history
        for id in ids {
            if let recordId = recordId(of: id, in: list) {
                queue(PendingSyncChange(operation: .delete, kind: fromFavourites ? .favourite : .history, recordId: recordId))
            }
            state.recordIds[id] = nil
        }
    }
    
    func cleared(favourites isFavourites: Bool) {
        if isEnabled {
            queue(PendingSyncChange(operation: .clear, kind: isFavourites ? .favourite : .history))
        }
    }
    
    /// A favourite was added, renamed, or replaced by an edited copy (`replaced`, whose content must still be readable or known).
    func favouriteChanged(_ id: UUID, replacing replaced: UUID? = nil, replacedContent: SyncContent? = nil) {
        guard isEnabled else {
            return
        }
        if let replaced = replaced {
            var oldId = state.recordIds[replaced]
            if oldId == nil, let key = key, let content = replacedContent, !content.isEmpty {
                oldId = SyncRecordKey.id(for: content, key: key)
            }
            if let oldId = oldId, !oldId.isEmpty {
                queue(PendingSyncChange(operation: .delete, kind: .favourite, recordId: oldId))
            }
            state.recordIds[replaced] = nil
        }
        queuePut(.favourite, favourites, id)
    }
    
    // MARK: - Syncing
    
    /// Sends the waiting changes, then applies other devices' changes, waiting up to `wait` seconds for some if there are
    /// none. The background loop repeats this; tests call it directly.
    func syncOnce(wait: TimeInterval) async throws {
        guard let connection = connection else {
            return
        }
        let target = server ?? makeServer(connection)
        server = target
        queueExistingItems()
        try await sendPending(to: target)
        try await receive(from: target, wait: wait)
    }
    
    private func run() async {
        var delay: TimeInterval = 2
        status = .connecting
        while !Task.isCancelled {
            do {
                if state.pending.isEmpty {
                    // Wait for other devices' changes, unless a change of ours is queued meanwhile (`queue` cancels it)
                    let wait = Task { try await self.syncOnce(wait: Self.longPollWait) }
                    waiting = wait
                    try await withTaskCancellationHandler(operation: { try await wait.value }, onCancel: { wait.cancel() })
                }
                else {
                    try await syncOnce(wait: 0)
                }
                status = .upToDate(lastSynced: now())
                delay = 2
            }
            catch let error as SyncServerError {
                let refused = error.kind == .accessKeyRefused || error.kind == .keyRefused
                status = refused ? .refused(message: error.message) : .offline(message: error.message)
                try? await Task.sleep(nanoseconds: UInt64((refused ? Self.maxRetryDelay : delay) * 1_000_000_000))
                delay = min(delay * 2, Self.maxRetryDelay)
            }
            catch is CancellationError {
                // Stopping, or a change of ours was queued while waiting: go round and send it
            }
            catch {
                // A bug; keep syncing rather than stop for good, but don't spin
                log("Sync failed unexpectedly: \(error)")
                status = .offline(message: error.localizedDescription)
                try? await Task.sleep(nanoseconds: UInt64(Self.maxRetryDelay * 1_000_000_000))
            }
            waiting = nil
        }
    }
    
    private func sendPending(to target: SyncServer) async throws {
        while let change = state.pending.first {
            do {
                try await send(change, to: target)
            }
            catch let error as SyncServerError where error.kind == .rejected {
                // E.g. an image over the server's size limit: retrying won't help
                log("The sync server refused a change (\(change.operation) \(change.kind)): \(error.message)")
            }
            if state.pending.first == change {
                state.pending.removeFirst()
            }
            saveState()
        }
    }
    
    private func send(_ change: PendingSyncChange, to target: SyncServer) async throws {
        switch change.operation {
        case .clear:
            try await target.clear(change.kind)
        case .delete:
            try await target.delete(SyncRecordKey(kind: change.kind, id: change.recordId!))
        case .put:
            let list = change.kind == .history ? history : favourites
            // The item may have been deleted since; then there's nothing to send
            guard let key = key, let id = change.itemId, let item = list.syncItems.first(where: { $0.id == id }),
                  let content = list.syncContent(of: id), !content.isEmpty else {
                return
            }
            let recordKey = SyncRecordKey(kind: change.kind, id: change.recordId!)
            let payload = SyncPayload(content: content, copiedAt: item.copiedAt ?? now(), title: change.kind == .favourite ? item.title : nil)
            try await target.put(recordKey, data: try SyncRecordCodec.seal(payload, as: recordKey, with: key))
        }
    }
    
    private func receive(from target: SyncServer, wait: TimeInterval) async throws {
        var wait = wait
        while true {
            let page = try await target.changes(since: state.cursor, wait: wait)
            wait = 0
            if page.reset {
                state.cursor = 0
                continue
            }
            for change in page.changes {
                apply(change)
            }
            state.cursor = page.cursor
            saveState()
            if !page.more {
                return
            }
        }
    }
    
    /// Applies another device's change to the lists, without queuing anything to send back.
    private func apply(_ change: SyncChange) {
        guard let key = key, let recordKey = SyncRecordKey(change.key) else {
            return
        }
        let list = recordKey.kind == .history ? history : favourites
        let local = findLocal(recordKey.id, in: list)
        guard let data = change.data else {
            if let local = local {
                list.deleteSynced(local.id)
                state.recordIds[local.id] = nil
            }
            return
        }
        guard let payload = SyncRecordCodec.open(data, as: recordKey, with: key) else {
            log("Couldn't read the synced record \(change.key); it may be from a newer version.")
            return
        }
        if recordKey.kind == .history {
            applyHistory(recordKey, payload, local)
        }
        else {
            applyFavourite(recordKey, payload, local)
        }
    }
    
    private func applyHistory(_ recordKey: SyncRecordKey, _ payload: SyncPayload, _ local: SyncListItem?) {
        if let local = local {
            // Copied again on another device: move it to where its new copy time puts it
            if let localCopiedAt = local.copiedAt, localCopiedAt.millisecondsSince1970 >= payload.copiedAt.millisecondsSince1970 {
                return
            }
            let to = Self.insertionIndex(history.syncItems.filter({ $0.id != local.id }), payload.copiedAt)
            history.moveSynced(local.id, to: to)
            history.setSyncedCopiedAt(payload.copiedAt, of: local.id)
            return
        }
        let index = Self.insertionIndex(history.syncItems, payload.copiedAt)
        // Older than everything a full history keeps
        guard index < history.syncMaxItems,
              let id = history.insertSynced(payload.content, copiedAt: payload.copiedAt, title: nil, at: index) else {
            return
        }
        state.recordIds[id] = recordKey.id
    }
    
    private func applyFavourite(_ recordKey: SyncRecordKey, _ payload: SyncPayload, _ local: SyncListItem?) {
        if let local = local {
            if local.title != payload.title {
                favourites.setSyncedTitle(payload.title, of: local.id)
            }
            return
        }
        if let id = favourites.insertSynced(payload.content, copiedAt: payload.copiedAt, title: payload.title, at: 0) {
            state.recordIds[id] = recordKey.id
        }
    }
    
    /// The first index whose item was copied before `copiedAt`; items with no date count as oldest.
    private static func insertionIndex(_ items: [SyncListItem], _ copiedAt: Date) -> Int {
        return items.firstIndex(where: { ($0.copiedAt ?? .distantPast) < copiedAt }) ?? items.count
    }
    
    /// The local item with this record id: one it was given, or one whose content gives it.
    private func findLocal(_ recordId: String, in list: SyncList) -> SyncListItem? {
        return list.syncItems.first(where: { self.recordId(of: $0.id, in: list) == recordId })
    }
    
    /// The item's record id, worked out from its content the first time. Nil if it has nothing to sync.
    private func recordId(of id: UUID, in list: SyncList) -> String? {
        if let known = state.recordIds[id] {
            return known.isEmpty ? nil : known
        }
        guard let key = key, let content = list.syncContent(of: id) else {
            return nil
        }
        // Kinds share ids; the kind is only in the key's prefix
        let recordId = content.isEmpty ? "" : SyncRecordKey.id(for: content, key: key)
        state.recordIds[id] = recordId
        return recordId.isEmpty ? nil : recordId
    }
    
    private func queuePut(_ kind: SyncRecordKind, _ list: SyncList, _ id: UUID) {
        guard let recordId = recordId(of: id, in: list) else {
            return
        }
        if state.pending.contains(where: { $0.operation == .put && $0.kind == kind && $0.itemId == id }) {
            return
        }
        queue(PendingSyncChange(operation: .put, kind: kind, recordId: recordId, itemId: id))
    }
    
    private func queue(_ change: PendingSyncChange) {
        state.pending.append(change)
        saveState()
        // Stop waiting for the server's changes and send this one
        waiting?.cancel()
    }
    
    /// Once per sync key: sends the favourites and newest history items that were here before sync.
    private func queueExistingItems() {
        guard !state.sentExistingItems else {
            return
        }
        state.sentExistingItems = true
        for item in history.syncItems.prefix(Self.existingHistorySent).filter({ !isFromExpiringApp($0) }).reversed() {
            queuePut(.history, history, item.id)
        }
        for item in favourites.syncItems.reversed() {
            queuePut(.favourite, favourites, item.id)
        }
        saveState()
    }
    
    private func isFromExpiringApp(_ item: SyncListItem) -> Bool {
        return item.sourceBundleId.map(isExpiringSource) ?? false
    }
    
    private func resetState() {
        state = SyncState(spaceId: key?.spaceId)
    }
    
    private func saveState() {
        // Forget the ids of items that are gone
        let live = Set(history.syncItems.map({ $0.id }) + favourites.syncItems.map({ $0.id }))
        state.recordIds = state.recordIds.filter({ live.contains($0.key) })
        state.spaceId = key?.spaceId
        stateStore.save(state)
    }
}
