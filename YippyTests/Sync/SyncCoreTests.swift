//
//  SyncCoreTests.swift
//  YippyTests
//
//  The sync key, record ids and encryption, checked against sync-server/test-vectors.json so the Mac and Windows apps
//  read each other's records.
//

import XCTest
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
#if canImport(Yippy)
@testable import Yippy
#else
@testable import SyncCore
#endif

@available(macOS 10.15, *)
class SyncCoreTests: XCTestCase {
    
    private struct Vectors: Decodable {
        struct Record: Decodable {
            var formats: [String: String]
            var canonicalBytes: String
            var recordKey: String
            var copiedAt: Int64
            var title: String?
            var nonce: String
            var plaintext: String
            var sealed: String
        }
        var keyBytes: String
        var key: String
        var spaceId: String
        var authToken: String
        var records: [Record]
    }
    
    private func loadVectors() throws -> Vectors {
        if let path = ProcessInfo.processInfo.environment["SYNC_TEST_VECTORS"] {
            return try JSONDecoder().decode(Vectors.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        }
        // YippyTests/Sync/SyncCoreTests.swift -> sync-server/test-vectors.json
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("sync-server/test-vectors.json")
        return try JSONDecoder().decode(Vectors.self, from: Data(contentsOf: url))
    }
    
    private static func hex(_ text: String) -> Data {
        var data = Data()
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(index, offsetBy: 2)
            data.append(UInt8(text[index..<next], radix: 16)!)
            index = next
        }
        return data
    }
    
    func testTheKeyMatchesTheTestVectors() throws {
        let vectors = try loadVectors()
        let key = SyncKey(bytes: Self.hex(vectors.keyBytes))!
        
        XCTAssertEqual(key.text, vectors.key)
        XCTAssertEqual(SyncKey(text: vectors.key), key)
        XCTAssertEqual(key.spaceId, vectors.spaceId)
        XCTAssertEqual(key.authToken, vectors.authToken)
    }
    
    func testRecordsMatchTheTestVectors() throws {
        let vectors = try loadVectors()
        let key = SyncKey(bytes: Self.hex(vectors.keyBytes))!
        
        for record in vectors.records {
            let content = SyncContent(record.formats.mapValues({ Data($0.utf8) }))
            let recordKey = SyncRecordKey(record.recordKey)!
            XCTAssertEqual(content.canonicalBytes, Self.hex(record.canonicalBytes))
            XCTAssertEqual(SyncRecordKey.id(for: content, key: key), recordKey.id)
            
            // Sealing the same plaintext with the same nonce gives the same bytes
            let sealed = try SyncRecordCodec.seal(plaintext: Data(record.plaintext.utf8), as: recordKey, with: key,
                                                  nonce: try AES.GCM.Nonce(data: Self.hex(record.nonce)))
            XCTAssertEqual(sealed.base64EncodedString(), record.sealed)
            
            // And the other app's record opens here
            let payload = SyncRecordCodec.open(Data(base64Encoded: record.sealed)!, as: recordKey, with: key)
            XCTAssertEqual(payload?.content, content)
            XCTAssertEqual(payload?.copiedAt.millisecondsSince1970, record.copiedAt)
            XCTAssertEqual(payload?.title, record.title)
        }
    }
    
    func testAKeyReadsBackFromItsText() {
        let key = SyncKey.generate()
        
        XCTAssertEqual(key.text.count, 64)
        XCTAssertEqual(SyncKey(text: key.text), key)
        XCTAssertEqual(SyncKey(text: " " + key.text.lowercased().replacingOccurrences(of: "-", with: " ") + "\n"), key)
        XCTAssertEqual(SyncKey(text: key.text.replacingOccurrences(of: "0", with: "O").replacingOccurrences(of: "1", with: "l")), key)
    }
    
    func testMalformedKeysAreRefused() {
        XCTAssertNil(SyncKey(text: ""))
        XCTAssertNil(SyncKey(text: "not a key"))
        XCTAssertNil(SyncKey(text: "0000-0000"))
        XCTAssertNil(SyncKey(text: String(repeating: "0", count: 51) + "U"))
        XCTAssertNil(SyncKey(text: String(repeating: "0", count: 51) + "1"))
    }
    
    func testASealedRecordOpensOnlyWithItsKeyAndUnderItsRecordKey() throws {
        let key = SyncKey.generate()
        let content = SyncContent([SyncFormats.text: Data("hi".utf8)])
        let recordKey = SyncRecordKey(kind: .favourite, id: SyncRecordKey.id(for: content, key: key))
        let payload = SyncPayload(content: content, copiedAt: Date(millisecondsSince1970: 1_760_600_000_000), title: "Greeting")
        
        var data = try SyncRecordCodec.seal(payload, as: recordKey, with: key)
        
        XCTAssertEqual(SyncRecordCodec.open(data, as: recordKey, with: key), payload)
        XCTAssertNil(SyncRecordCodec.open(data, as: recordKey, with: SyncKey.generate()))
        XCTAssertNil(SyncRecordCodec.open(data, as: SyncRecordKey(kind: .history, id: recordKey.id), with: key))
        data[data.count - 1] ^= 1
        XCTAssertNil(SyncRecordCodec.open(data, as: recordKey, with: key))
    }
    
    func testPayloadsIgnoreFormatsTheyDontKnow() {
        let payload = SyncRecordCodec.deserialize(Data(#"{"v":1,"copiedAt":5,"formats":{"text":"aGk=","future":"AAAA"}}"#.utf8))
        
        XCTAssertEqual(payload?.content.formats.keys.sorted(), [SyncFormats.text])
        XCTAssertNil(SyncRecordCodec.deserialize(Data(#"{"v":2,"copiedAt":5,"formats":{}}"#.utf8)))
        XCTAssertNil(SyncRecordCodec.deserialize(Data("not json".utf8)))
    }
    
    func testServerAddresses() {
        XCTAssertEqual(try SyncServerAddress.parse("sync.example.com").get().absoluteString, "https://sync.example.com")
        XCTAssertEqual(try SyncServerAddress.parse("http://localhost:8080").get().absoluteString, "http://localhost:8080")
        XCTAssertEqual(try SyncServerAddress.parse("http://192.168.1.20:8080").get().absoluteString, "http://192.168.1.20:8080")
        XCTAssertThrowsError(try SyncServerAddress.parse("").get())
        XCTAssertThrowsError(try SyncServerAddress.parse("ftp://sync.example.com").get())
        XCTAssertThrowsError(try SyncServerAddress.parse("http://sync.example.com").get())
        XCTAssertThrowsError(try SyncServerAddress.parse("http://8.8.8.8").get())
    }
}
