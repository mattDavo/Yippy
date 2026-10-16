//
//  SyncCoordinator.swift
//  Yippy
//
//  Connects sync to the rest of the app.
//

import Cocoa
import RxRelay

/// Connects the `SyncEngine` to the app (Facade): hears what the user does to the clipboard history and favourites, keeps
/// the sync settings, and gives the Sync settings tab what it shows and does.
///
/// Everything runs on the main thread, where `History` is changed (the pasteboard monitor's timer and the panel).
@available(macOS 10.15, *)
@MainActor
final class SyncCoordinator {

    /// Created at launch, except in test builds.
    private(set) static var main: SyncCoordinator?

    private let engine: SyncEngine
    private let history: History
    private let favourites: History

    /// What sync is doing, for the Sync settings tab.
    let status: BehaviorRelay<SyncStatus>

    var isOn: Bool {
        return engine.isEnabled
    }

    /// The sync key as shown to the user, if there is one.
    var keyText: String? {
        return engine.key?.text
    }

    var serverAddress: String {
        return Settings.main.syncServer
    }

    var accessKey: String {
        return Settings.main.syncAccessKey
    }

    static func start(state: State) {
        main = SyncCoordinator(history: state.history, favourites: state.favourites, expiringAppBundleIds: state.expiringAppBundleIds)
    }

    init(history: History, favourites: History, expiringAppBundleIds: BehaviorRelay<[String]>, stateURL: URL = Constants.urls.syncState) {
        self.history = history
        self.favourites = favourites
        engine = SyncEngine(
            history: HistorySyncList(history),
            favourites: HistorySyncList(favourites),
            keyStore: KeychainSyncKeyStore(log: Self.log),
            stateStore: FileSyncStateStore(url: stateURL),
            makeServer: { HTTPSyncServer(connection: $0) },
            log: Self.log
        )
        status = BehaviorRelay(value: engine.status)
        engine.onStatusChange = { [weak self] in
            self?.status.accept($0)
        }
        engine.isExpiringSource = { [weak expiringAppBundleIds] bundleId in
            return expiringAppBundleIds?.value.contains(bundleId) ?? false
        }
        history.activity = self
        favourites.activity = self

        let settings = Settings.main!
        if settings.syncEnabled, case .success(let address) = SyncServerAddress.parse(settings.syncServer) {
            engine.configure(server: address, accessKey: settings.syncAccessKey.isEmpty ? nil : settings.syncAccessKey)
            engine.start()
        }
    }

    // MARK: - Settings tab

    /// Turns sync on, or saves changed settings. An empty `keyText` makes a new sync key.
    ///
    /// - Returns: Why the settings can't be used, or nil once sync is on.
    func turnOn(serverAddress: String, accessKey: String, keyText: String) -> String? {
        let address: URL
        switch SyncServerAddress.parse(serverAddress) {
        case .success(let url):
            address = url
        case .failure(let error):
            return error.message
        }
        let trimmedKey = keyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedKey: SyncKey? = trimmedKey.isEmpty ? SyncKey.generate() : SyncKey(text: trimmedKey)
        guard let key = parsedKey else {
            return "That sync key isn't complete. Copy it again from the other device."
        }
        let accessKey = accessKey.trimmingCharacters(in: .whitespacesAndNewlines)
        engine.turnOn(server: address, accessKey: accessKey, key: key)
        Settings.main.syncEnabled = true
        Settings.main.syncServer = address.absoluteString
        Settings.main.syncAccessKey = accessKey
        return nil
    }

    func turnOff() {
        engine.turnOff()
        Settings.main.syncEnabled = false
    }

    /// Deletes everything this sync key stored on the server, then turns sync off and forgets the key.
    ///
    /// - Parameter completion: Called with why it failed, or nil.
    func eraseServerData(completion: @escaping (String?) -> Void) {
        Task {
            do {
                try await self.engine.eraseServerData()
                Settings.main.syncEnabled = false
                completion(nil)
            }
            catch let error as SyncServerError {
                completion(error.message)
            }
            catch {
                completion(error.localizedDescription)
            }
        }
    }

    /// Puts the text on the clipboard without it going into the history, e.g. the sync key to paste on another device.
    func copyWithoutSaving(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        history.recordPasteboardChange(withCount: pasteboard.changeCount)
    }

    nonisolated private static func log(_ message: String) {
        WarningLogger.general.log(SyncLogEntry(message: message))
    }
}

// MARK: - What the user did

@available(macOS 10.15, *)
extension SyncCoordinator: HistoryActivity {

    // `History` calls these on the main thread

    nonisolated func history(_ history: History, didCopy item: HistoryItem) {
        let id = item.fsId
        MainActor.assumeIsolated {
            if history === self.history {
                engine.copied(id)
            }
        }
    }

    nonisolated func history(_ history: History, willDelete items: [HistoryItem]) {
        let ids = items.map({ $0.fsId })
        MainActor.assumeIsolated {
            engine.willDelete(ids, fromFavourites: history === favourites)
        }
    }

    nonisolated func historyDidClear(_ history: History) {
        MainActor.assumeIsolated {
            engine.cleared(favourites: history === favourites)
        }
    }

    nonisolated func history(_ history: History, didChangeFavourite item: HistoryItem) {
        let id = item.fsId
        MainActor.assumeIsolated {
            if history === favourites {
                engine.favouriteChanged(id)
            }
        }
    }
}

/// A line in the warning log about sync.
private struct SyncLogEntry: Loggable {
    let message: String

    var localizedDescription: String {
        return message
    }

    var consoleDescription: String {
        return "Sync: \(message)"
    }

    var logFileDescription: String {
        return "Sync: \(message)"
    }

    var domain: String {
        return "Sync"
    }
}
