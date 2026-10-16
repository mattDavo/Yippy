//
//  SyncServer.swift
//  Yippy
//
//  The sync server's API (sync-server/PROTOCOL.md), and a client for it over HTTP.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Where and how to sync: the server's address, its access key if it has one, and the user's sync key.
@available(macOS 10.15, *)
struct SyncConnection: Equatable {
    var server: URL
    var accessKey: String?
    var key: SyncKey
}

/// The latest change of one record; `data` is nil if it was deleted.
struct SyncChange: Equatable {
    var key: String
    var seq: Int64
    var data: Data?
}

struct SyncChangePage: Equatable {
    var changes: [SyncChange]
    /// Where to ask from next.
    var cursor: Int64
    /// More changes are waiting; ask again straight away.
    var more: Bool
    /// The server can't answer from the given cursor; ask again from 0.
    var reset: Bool
}

struct SyncServerError: Error, Equatable {
    
    enum Kind: Equatable {
        /// The server can't be reached or had a problem. Worth retrying.
        case unreachable
        /// The server needs an access key, or a different one.
        case accessKeyRefused
        /// Another sync key owns the space.
        case keyRefused
        /// The server refused the request, e.g. a record over its size limit. Retrying won't help.
        case rejected
    }
    
    var kind: Kind
    var message: String
}

/// A space on the sync server. Throws `SyncServerError`.
@available(macOS 10.15, *)
protocol SyncServer: AnyObject {
    func put(_ key: SyncRecordKey, data: Data) async throws
    func delete(_ key: SyncRecordKey) async throws
    /// Deletes every record of the kind.
    func clear(_ kind: SyncRecordKind) async throws
    /// The changes after `since`, waiting up to `wait` seconds for one if there are none.
    func changes(since: Int64, wait: TimeInterval) async throws -> SyncChangePage
    /// Deletes everything the space holds.
    func deleteSpace() async throws
}

/// Talks to the sync server over HTTP.
@available(macOS 10.15, *)
final class HTTPSyncServer: SyncServer {
    
    private let connection: SyncConnection
    private let session: URLSession
    
    init(connection: SyncConnection, session: URLSession? = nil) {
        self.connection = connection
        if let session = session {
            self.session = session
        }
        else {
            let configuration = URLSessionConfiguration.ephemeral
            // Requests for changes wait on the server for up to a minute
            configuration.timeoutIntervalForRequest = 100
            self.session = URLSession(configuration: configuration)
        }
    }
    
    deinit {
        session.invalidateAndCancel()
    }
    
    func put(_ key: SyncRecordKey, data: Data) async throws {
        _ = try await send("PUT", "records/\(key)", body: data)
    }
    
    func delete(_ key: SyncRecordKey) async throws {
        _ = try await send("DELETE", "records/\(key)")
    }
    
    func clear(_ kind: SyncRecordKind) async throws {
        _ = try await send("POST", "clear/\(kind.rawValue)")
    }
    
    func deleteSpace() async throws {
        _ = try await send("DELETE", "")
    }
    
    func changes(since: Int64, wait: TimeInterval) async throws -> SyncChangePage {
        let data = try await send("GET", "changes?since=\(since)&wait=\(Int(wait))")
        guard let page = try? JSONDecoder().decode(PageJSON.self, from: data) else {
            throw SyncServerError(kind: .unreachable, message: "The sync server sent something unexpected. Is the address right?")
        }
        let changes = page.changes.map({
            SyncChange(key: $0.key, seq: $0.seq, data: $0.deleted ? nil : ($0.data.flatMap({ Data(base64Encoded: $0) }) ?? Data()))
        })
        return SyncChangePage(changes: changes, cursor: page.cursor, more: page.more, reset: page.reset)
    }
    
    private func send(_ method: String, _ path: String, body: Data? = nil) async throws -> Data {
        var base = connection.server.absoluteString
        if !base.hasSuffix("/") {
            base += "/"
        }
        let suffix = path.isEmpty ? "" : "/\(path)"
        guard let url = URL(string: "\(base)v1/spaces/\(connection.key.spaceId)\(suffix)") else {
            throw SyncServerError(kind: .rejected, message: "The server address isn't valid.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(connection.key.authToken)", forHTTPHeaderField: "Authorization")
        if body != nil {
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        }
        if let accessKey = connection.accessKey {
            request.setValue(accessKey, forHTTPHeaderField: "X-Access-Key")
        }
        let (data, response) = try await load(request)
        let status = response.statusCode
        if (200..<300).contains(status) {
            return data
        }
        let message = (try? JSONDecoder().decode(ErrorJSON.self, from: data))?.error
        switch status {
        case 401:
            throw SyncServerError(kind: .keyRefused, message: "The server has this space under another sync key.")
        case 403:
            throw SyncServerError(kind: .accessKeyRefused, message: "The server refused the access key.")
        case 404:
            throw SyncServerError(kind: .unreachable, message: "There's no sync server at that address.")
        case 500...:
            throw SyncServerError(kind: .unreachable, message: "The sync server had a problem (\(status)).")
        default:
            throw SyncServerError(kind: .rejected, message: message ?? "The sync server refused the request (\(status)).")
        }
    }
    
    /// `URLSession.data(for:)` needs macOS 12, so wrap the callback API. Cancelling the calling task cancels the request.
    private func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let box = TaskBox()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>) in
                let task = session.dataTask(with: request) { data, response, error in
                    if let response = response as? HTTPURLResponse, error == nil {
                        continuation.resume(returning: (data ?? Data(), response))
                    }
                    else if let error = error as? URLError, error.code == .cancelled {
                        continuation.resume(throwing: CancellationError())
                    }
                    else {
                        continuation.resume(throwing: SyncServerError(kind: .unreachable, message: "Can't reach the sync server."))
                    }
                }
                box.set(task)
                task.resume()
            })
        }, onCancel: {
            box.cancel()
        })
    }
    
    /// Holds the request so cancelling can reach it, whichever comes first.
    private final class TaskBox: @unchecked Sendable {
        private let lock = NSLock()
        private var task: URLSessionDataTask?
        private var isCancelled = false
        
        func set(_ task: URLSessionDataTask) {
            lock.lock()
            self.task = task
            let cancelled = isCancelled
            lock.unlock()
            if cancelled {
                task.cancel()
            }
        }
        
        func cancel() {
            lock.lock()
            isCancelled = true
            let task = self.task
            lock.unlock()
            task?.cancel()
        }
    }
    
    private struct ChangeJSON: Decodable {
        var key: String
        var seq: Int64
        var deleted: Bool
        var data: String?
    }
    
    private struct PageJSON: Decodable {
        var changes: [ChangeJSON]
        var cursor: Int64
        var more: Bool
        var reset: Bool
    }
    
    private struct ErrorJSON: Decodable {
        var error: String?
    }
}

/// Checks the sync server address the user types.
enum SyncServerAddress {
    
    /// Accepts https addresses, and http ones only on this computer or the local network (e.g. a test server in Docker),
    /// since the auth token would otherwise cross the internet unencrypted. Records are encrypted either way.
    ///
    /// - Returns: The address, or why it isn't accepted.
    static func parse(_ text: String) -> Result<URL, SyncServerError> {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !trimmed.contains("://") {
            trimmed = "https://" + trimmed
        }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host, !host.isEmpty else {
            return .failure(SyncServerError(kind: .rejected, message: "Enter the server's address, e.g. https://sync.example.com."))
        }
        if scheme == "http" && !isLocal(host) {
            return .failure(SyncServerError(kind: .rejected, message: "Use https for a server on the internet."))
        }
        return .success(url)
    }
    
    private static func isLocal(_ host: String) -> Bool {
        let host = host.lowercased()
        if host == "localhost" || host == "::1" || host.hasSuffix(".local") || host.hasPrefix("127.") {
            return true
        }
        let parts = host.split(separator: ".").compactMap({ Int($0) })
        guard parts.count == 4 else {
            return false
        }
        return parts[0] == 10 || (parts[0] == 172 && (16...31).contains(parts[1])) || (parts[0] == 192 && parts[1] == 168)
    }
}
