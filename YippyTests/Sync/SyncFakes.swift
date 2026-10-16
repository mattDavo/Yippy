//
//  SyncFakes.swift
//  YippyTests
//
//  In-memory stand-ins for what sync talks to: the server, the histories and where state and keys are kept.
//

import Foundation
#if canImport(Yippy)
@testable import Yippy
#else
@testable import SyncCore
#endif

/// The sync server's behaviour in memory (sync-server/PROTOCOL.md): one space whose records keep their latest change.
/// Several devices can share it.
@available(macOS 10.15, *)
final class FakeSyncServer {
    
    private(set) var records = [String: (seq: Int64, data: Data?)]()
    private var lastSeq: Int64 = 0
    var isReachable = true
    var maxRecordBytes = Int.max
    
    var liveKeys: [String] {
        return records.filter({ $0.value.data != nil }).sorted(by: { $0.value.seq < $1.value.seq }).map({ $0.key })
    }
    
    /// Drops a record without a deletion, as the server does to history when it runs out of space.
    func evict(_ key: String) {
        records[key] = nil
    }
    
    func connect(_ connection: SyncConnection) -> SyncServer {
        return Connection(server: self)
    }
    
    fileprivate func write(_ key: String, _ data: Data?) throws {
        try check()
        lastSeq += 1
        records[key] = (lastSeq, data)
    }
    
    fileprivate func check() throws {
        if !isReachable {
            throw SyncServerError(kind: .unreachable, message: "Can't reach the sync server.")
        }
    }
    
    private final class Connection: SyncServer {
        let server: FakeSyncServer
        
        init(server: FakeSyncServer) {
            self.server = server
        }
        
        func put(_ key: SyncRecordKey, data: Data) async throws {
            if data.count > server.maxRecordBytes {
                throw SyncServerError(kind: .rejected, message: "Too large.")
            }
            try server.write(key.description, data)
        }
        
        func delete(_ key: SyncRecordKey) async throws {
            try server.write(key.description, nil)
        }
        
        func clear(_ kind: SyncRecordKind) async throws {
            for key in server.liveKeys where key.hasPrefix(kind.rawValue + "/") {
                try server.write(key, nil)
            }
        }
        
        func changes(since: Int64, wait: TimeInterval) async throws -> SyncChangePage {
            try server.check()
            let changes = server.records
                .filter({ $0.value.seq > since })
                .sorted(by: { $0.value.seq < $1.value.seq })
                .map({ SyncChange(key: $0.key, seq: $0.value.seq, data: $0.value.data) })
            return SyncChangePage(changes: changes, cursor: server.lastSeq, more: false, reset: false)
        }
        
        func deleteSpace() async throws {
            try server.check()
            server.records = [:]
        }
    }
}

/// A history in memory, holding synced content directly.
final class FakeSyncList: SyncList {
    
    struct Item {
        var info: SyncListItem
        var content: SyncContent
    }
    
    var items = [Item]()
    var syncMaxItems = Int.max
    
    var texts: [String?] {
        return items.map({ $0.content.text })
    }
    
    var syncItems: [SyncListItem] {
        return items.map({ $0.info })
    }
    
    /// Adds an item the way the app does when something is copied.
    @discardableResult
    func add(_ text: String, copiedAt: Date, source: String? = nil, at index: Int = 0) -> UUID {
        let id = UUID()
        items.insert(Item(info: SyncListItem(id: id, copiedAt: copiedAt, title: nil, sourceBundleId: source),
                          content: SyncContent([SyncFormats.text: Data(text.utf8)])), at: index)
        return id
    }
    
    func syncContent(of id: UUID) -> SyncContent? {
        return items.first(where: { $0.info.id == id })?.content
    }
    
    func insertSynced(_ content: SyncContent, copiedAt: Date, title: String?, at index: Int) -> UUID? {
        guard !content.isEmpty else {
            return nil
        }
        let id = UUID()
        items.insert(Item(info: SyncListItem(id: id, copiedAt: copiedAt, title: title, sourceBundleId: nil), content: content), at: index)
        return id
    }
    
    func deleteSynced(_ id: UUID) {
        items.removeAll(where: { $0.info.id == id })
    }
    
    func moveSynced(_ id: UUID, to index: Int) {
        guard let from = items.firstIndex(where: { $0.info.id == id }) else {
            return
        }
        let item = items.remove(at: from)
        items.insert(item, at: index)
    }
    
    func setSyncedCopiedAt(_ date: Date, of id: UUID) {
        if let i = items.firstIndex(where: { $0.info.id == id }) {
            items[i].info.copiedAt = date
        }
    }
    
    func setSyncedTitle(_ title: String?, of id: UUID) {
        if let i = items.firstIndex(where: { $0.info.id == id }) {
            items[i].info.title = title
        }
    }
}

final class InMemorySyncStateStore: SyncStateStore {
    var state = SyncState()
    
    func load() -> SyncState {
        return state
    }
    
    func save(_ state: SyncState) {
        self.state = state
    }
}

@available(macOS 10.15, *)
final class InMemorySyncKeyStore: SyncKeyStore {
    var key: SyncKey?
    
    init(_ key: SyncKey?) {
        self.key = key
    }
    
    func load() -> SyncKey? {
        return key
    }
    
    func save(_ key: SyncKey?) {
        self.key = key
    }
}

/// A device with sync turned on, sharing a server and sync key with the other devices of a test.
@available(macOS 10.15, *)
@MainActor
final class SyncDevice {
    
    let history = FakeSyncList()
    let favourites = FakeSyncList()
    let keys: InMemorySyncKeyStore
    let state: InMemorySyncStateStore
    let engine: SyncEngine
    var now = Date(timeIntervalSince1970: 1_760_000_000)
    
    init(server: FakeSyncServer, key: SyncKey, state: InMemorySyncStateStore = InMemorySyncStateStore()) {
        keys = InMemorySyncKeyStore(key)
        self.state = state
        weak var device: SyncDevice?
        engine = SyncEngine(history: history, favourites: favourites, keyStore: keys, stateStore: state,
                            makeServer: server.connect, now: { device?.now ?? Date() }, log: { _ in })
        device = self
        engine.configure(server: URL(string: "https://sync.example.com")!, accessKey: nil)
    }
    
    /// Copies text, as the app's capture would: adds it (or moves it to the top) and tells sync.
    func copy(_ text: String, source: String? = nil) {
        if let i = history.items.firstIndex(where: { $0.content.text == text }) {
            let item = history.items.remove(at: i)
            history.items.insert(item, at: 0)
            history.items[0].info.copiedAt = now
        }
        else {
            history.add(text, copiedAt: now, source: source)
        }
        engine.copied(history.items[0].info.id)
    }
    
    func delete(_ text: String) {
        let id = history.items.first(where: { $0.content.text == text })!.info.id
        engine.willDelete([id], fromFavourites: false)
        history.deleteSynced(id)
    }
    
    func favourite(_ text: String) {
        let content = history.items.first(where: { $0.content.text == text })!.content
        let id = favourites.insertSynced(content, copiedAt: now, title: nil, at: 0)!
        engine.favouriteChanged(id)
    }
    
    func sync() async throws {
        try await engine.syncOnce(wait: 0)
    }
}
