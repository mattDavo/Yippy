//
//  SyncRecord.swift
//  Yippy
//
//  What the sync server stores: encrypted records of history items and favourites (see sync-server/PROTOCOL.md).
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// The formats an item is synced in, the same on every platform.
enum SyncFormats {
    /// UTF-8 text.
    static let text = "text"
    static let rtf = "rtf"
    /// UTF-8 HTML.
    static let html = "html"
    static let png = "png"
    
    static let all: Set<String> = [text, rtf, html, png]
}

/// An item's content in the `SyncFormats`.
struct SyncContent: Equatable {
    
    let formats: [String: Data]
    
    init(_ formats: [String: Data]) {
        self.formats = formats.filter({ SyncFormats.all.contains($0.key) })
    }
    
    var isEmpty: Bool {
        return formats.isEmpty
    }
    
    var text: String? {
        return formats[SyncFormats.text].flatMap({ String(data: $0, encoding: .utf8) })
    }
    
    /// The content as hashed for its record id: each format in order of its name's bytes, as the name's UTF-8 length
    /// (64-bit little-endian), the name, the data's length (64-bit little-endian) and the data.
    var canonicalBytes: Data {
        var output = Data()
        for name in formats.keys.sorted(by: { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }) {
            let nameBytes = Data(name.utf8)
            let data = formats[name]!
            output += Self.littleEndian(nameBytes.count) + nameBytes + Self.littleEndian(data.count) + data
        }
        return output
    }
    
    private static func littleEndian(_ value: Int) -> Data {
        var little = Int64(value).littleEndian
        return Data(bytes: &little, count: 8)
    }
}

enum SyncRecordKind: String, Codable {
    case history = "h"
    case favourite = "f"
}

/// A record's key: `h/<id>` or `f/<id>`.
struct SyncRecordKey: Equatable, Hashable, CustomStringConvertible {
    let kind: SyncRecordKind
    let id: String
    
    /// The key's id for this content: the first 16 bytes of HMAC-SHA256 under the sync key's id key, base64url.
    @available(macOS 10.15, *)
    static func id(for content: SyncContent, key: SyncKey) -> String {
        let mac = Data(HMAC<SHA256>.authenticationCode(for: content.canonicalBytes, using: key.idKey))
        return mac.prefix(16).base64URLEncoded()
    }
    
    init(kind: SyncRecordKind, id: String) {
        self.kind = kind
        self.id = id
    }
    
    init?(_ text: String) {
        guard let slash = text.firstIndex(of: "/"), let kind = SyncRecordKind(rawValue: String(text[..<slash])) else {
            return nil
        }
        let id = String(text[text.index(after: slash)...])
        guard !id.isEmpty else {
            return nil
        }
        self.init(kind: kind, id: id)
    }
    
    var description: String {
        return "\(kind.rawValue)/\(id)"
    }
}

/// What one record says: the item's content, when it was copied and, for favourites, its name.
struct SyncPayload: Equatable {
    var content: SyncContent
    var copiedAt: Date
    var title: String?
}

/// Turns payloads into the encrypted data the server stores and back: JSON, then AES-256-GCM with the record key as
/// additional data.
@available(macOS 10.15, *)
enum SyncRecordCodec {
    
    private static let version: UInt8 = 1
    
    static func seal(_ payload: SyncPayload, as recordKey: SyncRecordKey, with key: SyncKey) throws -> Data {
        return try seal(plaintext: serialize(payload), as: recordKey, with: key, nonce: AES.GCM.Nonce())
    }
    
    /// Like `seal(_:as:with:)` with a chosen nonce, for test vectors.
    static func seal(plaintext: Data, as recordKey: SyncRecordKey, with key: SyncKey, nonce: AES.GCM.Nonce) throws -> Data {
        let box = try AES.GCM.seal(plaintext, using: key.encryptionKey, nonce: nonce, authenticating: Data(recordKey.description.utf8))
        return Data([version]) + box.combined!
    }
    
    /// - Returns: The payload, or nil if the data is damaged, from another key or not a version this app reads.
    static func open(_ data: Data, as recordKey: SyncRecordKey, with key: SyncKey) -> SyncPayload? {
        guard data.count > 1 + 12 + 16, data.first == version,
              let box = try? AES.GCM.SealedBox(combined: data.dropFirst()),
              let plaintext = try? AES.GCM.open(box, using: key.encryptionKey, authenticating: Data(recordKey.description.utf8)) else {
            return nil
        }
        return deserialize(plaintext)
    }
    
    static func serialize(_ payload: SyncPayload) -> Data {
        let json = PayloadJSON(
            v: 1,
            copiedAt: payload.copiedAt.millisecondsSince1970,
            title: payload.title,
            formats: payload.content.formats.mapValues({ $0.base64EncodedString() }))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try! encoder.encode(json)
    }
    
    static func deserialize(_ data: Data) -> SyncPayload? {
        guard let json = try? JSONDecoder().decode(PayloadJSON.self, from: data), json.v == 1 else {
            return nil
        }
        var formats = [String: Data]()
        for (name, value) in json.formats where SyncFormats.all.contains(name) {
            guard let bytes = Data(base64Encoded: value) else {
                return nil
            }
            formats[name] = bytes
        }
        return SyncPayload(content: SyncContent(formats), copiedAt: Date(millisecondsSince1970: json.copiedAt), title: json.title)
    }
    
    private struct PayloadJSON: Codable {
        var v: Int
        var copiedAt: Int64
        var title: String?
        var formats: [String: String]
    }
}

extension Date {
    
    var millisecondsSince1970: Int64 {
        return Int64((timeIntervalSince1970 * 1000).rounded())
    }
    
    init(millisecondsSince1970 milliseconds: Int64) {
        self.init(timeIntervalSince1970: Double(milliseconds) / 1000)
    }
}
