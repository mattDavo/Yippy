//
//  SyncKey.swift
//  Yippy
//
//  The secret shared by a user's devices to sync (see sync-server/PROTOCOL.md).
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// The secret every device of one user shares to sync. Shown as Crockford base32 in groups of four; everything sent to the
/// server and the encryption keys are derived from it.
@available(macOS 10.15, *)
struct SyncKey: Equatable {
    
    static let length = 32
    
    private static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
    
    let bytes: Data
    
    /// Which space on the server holds this key's records.
    let spaceId: String
    
    /// Proves to the server that a device may use the space.
    let authToken: String
    
    /// The AES-256-GCM key. Never leaves the device.
    let encryptionKey: SymmetricKey
    
    /// The HMAC key for record ids. Never leaves the device.
    let idKey: SymmetricKey
    
    init?(bytes: Data) {
        guard bytes.count == Self.length else {
            return nil
        }
        self.bytes = bytes
        spaceId = Self.derive(bytes, "space", 16).map({ String(format: "%02x", $0) }).joined()
        authToken = Self.derive(bytes, "auth", 32).base64URLEncoded()
        encryptionKey = SymmetricKey(data: Self.derive(bytes, "encrypt", 32))
        idKey = SymmetricKey(data: Self.derive(bytes, "id", 32))
    }
    
    static func generate() -> SyncKey {
        // Secure on every platform: arc4random on Apple's, getrandom on Linux
        var generator = SystemRandomNumberGenerator()
        return SyncKey(bytes: Data((0..<length).map({ _ in UInt8.random(in: .min ... .max, using: &generator) })))!
    }
    
    /// Reads a key as `description` writes it, ignoring case, spaces and dashes, and reading O as 0 and I or L as 1.
    init?(text: String) {
        var bits = 0
        var value = 0
        var output = Data()
        for raw in text.uppercased() {
            if raw == "-" || raw.isWhitespace {
                continue
            }
            let c: Character = raw == "O" ? "0" : (raw == "I" || raw == "L") ? "1" : raw
            guard let digit = Self.alphabet.firstIndex(of: c) else {
                return nil
            }
            value = (value << 5) | digit
            bits += 5
            if bits >= 8 {
                bits -= 8
                output.append(UInt8(value >> bits))
                value &= (1 << bits) - 1
            }
        }
        // 52 characters hold 260 bits: 256 for the key, and 4 that must be zero
        guard output.count == Self.length, value == 0 else {
            return nil
        }
        self.init(bytes: output)
    }
    
    /// 52 characters of Crockford base32, in groups of four separated by dashes.
    var text: String {
        var characters = [Character]()
        var bits = 0
        var value = 0
        for byte in bytes {
            value = (value << 8) | Int(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                characters.append(Self.alphabet[(value >> bits) & 31])
            }
            value &= (1 << bits) - 1
        }
        if bits > 0 {
            characters.append(Self.alphabet[(value << (5 - bits)) & 31])
        }
        return stride(from: 0, to: characters.count, by: 4)
            .map({ String(characters[$0..<min($0 + 4, characters.count)]) })
            .joined(separator: "-")
    }
    
    static func == (lhs: SyncKey, rhs: SyncKey) -> Bool {
        return lhs.bytes == rhs.bytes
    }
    
    /// HKDF-SHA256 (RFC 5869) with an empty salt, written out because CryptoKit's HKDF needs macOS 11.
    private static func derive(_ secret: Data, _ purpose: String, _ length: Int) -> Data {
        let prk = Data(HMAC<SHA256>.authenticationCode(for: secret, using: SymmetricKey(data: Data(count: 32))))
        let info = Data("clipsync-v1 \(purpose)".utf8)
        var output = Data()
        var block = Data()
        var counter: UInt8 = 1
        while output.count < length {
            block = Data(HMAC<SHA256>.authenticationCode(for: block + info + Data([counter]), using: SymmetricKey(data: prk)))
            output += block
            counter += 1
        }
        return output.prefix(length)
    }
}

extension Data {
    
    /// Base64url without padding (RFC 4648 §5).
    func base64URLEncoded() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }
}
