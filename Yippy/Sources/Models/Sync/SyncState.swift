//
//  SyncState.swift
//  Yippy
//
//  What a device remembers about syncing between runs, and where it's kept.
//

import Foundation

enum SyncOperation: String, Codable {
    case put
    case delete
    case clear
}

/// A change waiting to be sent: a record to write or delete, or a kind of record to clear.
struct PendingSyncChange: Codable, Equatable {
    var operation: SyncOperation
    var kind: SyncRecordKind
    var recordId: String?
    /// For `put`: the item whose current content is sent.
    var itemId: UUID?
}

struct SyncState: Codable, Equatable {
    /// The space the rest belongs to; a new sync key starts again.
    var spaceId: String?
    /// The server's sequence number this device has caught up to.
    var cursor: Int64 = 0
    /// Whether the favourites and recent history that were here before sync was turned on have been sent.
    var sentExistingItems = false
    /// The record id of each local item, so an item keeps its id however its content is converted.
    var recordIds = [UUID: String]()
    var pending = [PendingSyncChange]()
}

protocol SyncStateStore {
    func load() -> SyncState
    func save(_ state: SyncState)
}

/// Keeps the sync state in a JSON file. An unreadable file starts sync again from the beginning.
final class FileSyncStateStore: SyncStateStore {
    
    private let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    func load() -> SyncState {
        guard let data = try? Data(contentsOf: url), let state = try? JSONDecoder().decode(SyncState.self, from: data) else {
            return SyncState()
        }
        return state
    }
    
    func save(_ state: SyncState) {
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

/// Keeps the sync key, protected for the current user where the platform can.
@available(macOS 10.15, *)
protocol SyncKeyStore {
    func load() -> SyncKey?
    /// `nil` forgets the key.
    func save(_ key: SyncKey?)
}
