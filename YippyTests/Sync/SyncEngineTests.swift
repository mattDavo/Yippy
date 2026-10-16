//
//  SyncEngineTests.swift
//  YippyTests
//
//  Two or three devices syncing through an in-memory server.
//

import XCTest
#if canImport(Yippy)
@testable import Yippy
#else
@testable import SyncCore
#endif

@available(macOS 10.15, *)
@MainActor
class SyncEngineTests: XCTestCase {
    
    private let server = FakeSyncServer()
    private let key = SyncKey.generate()
    
    private func device() -> SyncDevice {
        return SyncDevice(server: server, key: key)
    }
    
    /// Twice round, so every device sees what the others sent.
    private func syncAll(_ devices: SyncDevice...) async throws {
        for _ in 0..<2 {
            for device in devices {
                try await device.sync()
            }
        }
    }
    
    func testACopyShowsUpOnTheOtherDevice() async throws {
        let mac = device()
        let pc = device()
        
        mac.copy("hello")
        try await syncAll(mac, pc)
        
        XCTAssertEqual(pc.history.texts, ["hello"])
        XCTAssertEqual(mac.history.texts, ["hello"])
        XCTAssertEqual(pc.history.items[0].info.copiedAt, mac.now)
    }
    
    func testSyncedCopiesTakeTheirPlaceByWhenTheyWereCopied() async throws {
        let a = device()
        let b = device()
        
        a.copy("first")
        b.now = a.now.addingTimeInterval(60)
        b.copy("second")
        a.now = a.now.addingTimeInterval(120)
        a.copy("third")
        try await syncAll(a, b)
        
        XCTAssertEqual(a.history.texts, ["third", "second", "first"])
        XCTAssertEqual(b.history.texts, ["third", "second", "first"])
    }
    
    func testCopyingAgainMovesTheItemUpEverywhereWithoutDuplicates() async throws {
        let a = device()
        let b = device()
        a.copy("one")
        a.now = a.now.addingTimeInterval(60)
        a.copy("two")
        try await syncAll(a, b)
        
        b.now = a.now.addingTimeInterval(60)
        b.copy("one")
        try await syncAll(a, b)
        
        XCTAssertEqual(a.history.texts, ["one", "two"])
        XCTAssertEqual(b.history.texts, ["one", "two"])
        XCTAssertEqual(server.liveKeys.count, 2)
    }
    
    func testTheSameTextCopiedOnBothDevicesIsOneItem() async throws {
        let a = device()
        let b = device()
        
        a.copy("same")
        b.copy("same")
        try await syncAll(a, b)
        
        XCTAssertEqual(a.history.texts, ["same"])
        XCTAssertEqual(b.history.texts, ["same"])
        XCTAssertEqual(server.liveKeys.count, 1)
    }
    
    func testDeletingAnItemDeletesItEverywhere() async throws {
        let a = device()
        let b = device()
        a.copy("password123")
        a.copy("keep")
        try await syncAll(a, b)
        
        b.delete("password123")
        try await syncAll(a, b)
        
        XCTAssertEqual(a.history.texts, ["keep"])
        XCTAssertEqual(b.history.texts, ["keep"])
    }
    
    func testClearingTheHistoryClearsItEverywhereButKeepsFavourites() async throws {
        let a = device()
        let b = device()
        a.copy("one")
        a.copy("two")
        a.favourite("two")
        try await syncAll(a, b)
        
        a.engine.cleared(favourites: false)
        a.history.items = []
        try await syncAll(a, b)
        
        XCTAssertEqual(b.history.texts, [])
        XCTAssertEqual(b.favourites.texts, ["two"])
    }
    
    func testFavouritesAreAddedRenamedEditedAndRemovedEverywhere() async throws {
        let a = device()
        let b = device()
        a.copy("snippet")
        a.favourite("snippet")
        try await syncAll(a, b)
        XCTAssertEqual(b.favourites.texts, ["snippet"])
        
        a.favourites.setSyncedTitle("My snippet", of: a.favourites.items[0].info.id)
        a.engine.favouriteChanged(a.favourites.items[0].info.id)
        try await syncAll(a, b)
        XCTAssertEqual(b.favourites.items[0].info.title, "My snippet")
        
        // Editing replaces the favourite with a new item
        let old = b.favourites.items[0]
        b.favourites.items[0] = FakeSyncList.Item(info: SyncListItem(id: UUID(), copiedAt: old.info.copiedAt, title: old.info.title),
                                                  content: SyncContent([SyncFormats.text: Data("better snippet".utf8)]))
        b.engine.favouriteChanged(b.favourites.items[0].info.id, replacing: old.info.id, replacedContent: old.content)
        try await syncAll(a, b)
        XCTAssertEqual(a.favourites.texts, ["better snippet"])
        XCTAssertEqual(a.favourites.items[0].info.title, "My snippet")
        
        a.engine.willDelete([a.favourites.items[0].info.id], fromFavourites: true)
        a.favourites.items = []
        try await syncAll(a, b)
        XCTAssertEqual(b.favourites.texts, [])
        XCTAssertFalse(server.liveKeys.contains(where: { $0.hasPrefix("f/") }))
    }
    
    func testChangesMadeOfflineAreSentLater() async throws {
        let a = device()
        let b = device()
        server.isReachable = false
        
        a.copy("written on a plane")
        do {
            try await a.sync()
            XCTFail("The server can't be reached")
        }
        catch {
        }
        XCTAssertEqual(a.engine.pending.count, 1)
        
        server.isReachable = true
        try await syncAll(a, b)
        
        XCTAssertEqual(a.engine.pending, [])
        XCTAssertEqual(b.history.texts, ["written on a plane"])
    }
    
    func testWhatWasHereBeforeSyncIsSentOnce() async throws {
        let a = device()
        a.history.add("old copy", copiedAt: a.now)
        _ = a.favourites.insertSynced(SyncContent([SyncFormats.text: Data("old copy".utf8)]), copiedAt: a.now, title: nil, at: 0)
        let b = device()
        
        try await syncAll(a, b)
        try await syncAll(a, b)
        
        XCTAssertEqual(b.history.texts, ["old copy"])
        XCTAssertEqual(b.favourites.texts, ["old copy"])
        XCTAssertEqual(server.liveKeys.count, 2)
    }
    
    func testCopiesFromAppsWhoseItemsExpireAreNotSynced() async throws {
        let a = device()
        a.engine.isExpiringSource = { $0 == "com.agilebits.onepassword7" }
        let b = device()
        
        a.copy("secret", source: "com.agilebits.onepassword7")
        a.copy("public")
        try await syncAll(a, b)
        
        XCTAssertEqual(b.history.texts, ["public"])
    }
    
    func testNothingIsQueuedWhileSyncIsOff() async throws {
        let a = device()
        a.engine.turnOff()
        
        a.copy("local only")
        try await a.sync()
        
        XCTAssertFalse(a.engine.isEnabled)
        XCTAssertEqual(a.engine.pending, [])
        XCTAssertTrue(server.records.isEmpty)
    }
    
    func testADeviceWithAnotherKeyCantReadTheRecords() async throws {
        let a = device()
        let stranger = SyncDevice(server: server, key: SyncKey.generate())
        
        a.copy("private")
        try await syncAll(a, stranger)
        
        XCTAssertEqual(stranger.history.texts, [])
    }
    
    func testARecordTheServerRefusesIsDroppedAndTheRestStillSent() async throws {
        server.maxRecordBytes = 400
        let a = device()
        let b = device()
        
        a.copy(String(repeating: "x", count: 2000))
        a.copy("small")
        try await syncAll(a, b)
        
        XCTAssertEqual(a.engine.pending, [])
        XCTAssertEqual(b.history.texts, ["small"])
    }
    
    func testItemsOlderThanAFullHistoryKeepsAreSkipped() async throws {
        let a = device()
        let b = device()
        b.history.syncMaxItems = 1
        a.copy("old")
        b.now = a.now.addingTimeInterval(3600)
        b.copy("new")
        
        try await syncAll(a, b)
        
        XCTAssertEqual(b.history.texts, ["new"])
    }
    
    func testHistoryTheServerDroppedStaysOnTheDevices() async throws {
        let a = device()
        let b = device()
        a.copy("kept")
        try await syncAll(a, b)
        
        server.evict(server.liveKeys[0])
        try await syncAll(a, b)
        
        XCTAssertEqual(b.history.texts, ["kept"])
    }
    
    func testErasingTheServerDataForgetsTheKey() async throws {
        let a = device()
        a.copy("hello")
        try await a.sync()
        
        try await a.engine.eraseServerData()
        
        XCTAssertTrue(server.records.isEmpty)
        XCTAssertNil(a.keys.key)
        XCTAssertFalse(a.engine.isEnabled)
        XCTAssertEqual(a.history.texts, ["hello"])
    }
    
    func testPendingChangesSurviveARestart() async throws {
        let a = device()
        server.isReachable = false
        a.copy("unsent")
        try? await a.sync()
        
        // The app restarts with the same state file
        let restarted = SyncEngine(history: a.history, favourites: a.favourites, keyStore: a.keys, stateStore: a.state,
                                   makeServer: server.connect, log: { _ in })
        restarted.configure(server: URL(string: "https://sync.example.com")!, accessKey: nil)
        server.isReachable = true
        try await restarted.syncOnce(wait: 0)
        
        XCTAssertEqual(server.liveKeys.count, 1)
    }
}
