//
//  HistorySyncTests.swift
//  YippyTests
//
//  The AppKit side of sync: converting pasteboard data, the `History` adapter, and the user actions `History` reports.
//

import XCTest
@testable import Yippy

class SyncPasteboardMapperTests: XCTestCase {

    private func content(_ data: [NSPasteboard.PasteboardType: Data]) -> SyncContent? {
        return SyncPasteboardMapper.syncContent(types: Array(data.keys), read: { data[$0] })
    }

    func testTextFormatsMapDirectly() {
        let synced = content([
            .string: Data("a".utf8),
            .rtf: Data("{\\rtf1 a}".utf8),
            .html: Data("<b>a</b>".utf8),
            NSPasteboard.PasteboardType("com.example.private"): Data("x".utf8),
        ])

        XCTAssertEqual(synced, SyncContent([
            SyncFormats.text: Data("a".utf8),
            SyncFormats.rtf: Data("{\\rtf1 a}".utf8),
            SyncFormats.html: Data("<b>a</b>".utf8),
        ]))
    }

    func testCopiedFilesAreNotSynced() {
        let synced = content([
            .fileURL: Data("file:///Users/me/a.txt".utf8),
            .string: Data("a.txt".utf8),
        ])

        XCTAssertEqual(synced, SyncContent([:]))
    }

    func testUnreadableDataGivesNil() {
        let synced = SyncPasteboardMapper.syncContent(types: [.string], read: { _ in nil })

        XCTAssertNil(synced)
    }

    func testTiffIsSyncedAsPng() throws {
        let tiff = try XCTUnwrap(Self.image().tiffRepresentation)

        let synced = try XCTUnwrap(content([.tiff: tiff]))

        let png = try XCTUnwrap(synced.formats[SyncFormats.png])
        XCTAssertEqual(Array(png.prefix(4)), [0x89, 0x50, 0x4E, 0x47])
    }

    func testSyncedImageIsSavedAsPngAndTiff() throws {
        let png = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(Self.image().tiffRepresentation))?.representation(using: .png, properties: [:]))

        let data = SyncPasteboardMapper.pasteboardData(for: SyncContent([SyncFormats.png: png, SyncFormats.text: Data("a".utf8)]))

        XCTAssertEqual(Set(data.keys), [.png, .tiff, .string])
        // Reading it back gives the same content, so it keeps its record id
        XCTAssertEqual(content(data), SyncContent([SyncFormats.png: png, SyncFormats.text: Data("a".utf8)]))
    }

    static func image() -> NSImage {
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()
        return image
    }
}

class HistorySyncListTests: XCTestCase {

    var history: History!
    var list: HistorySyncList!

    override func setUp() {
        history = History(historyFM: HistoryFileManagerMock(), cache: HistoryCache(), items: [], maxItems: 3)
        list = HistorySyncList(history)
    }

    private func strings() -> [String?] {
        return history.items.map({ $0.getPlainString() })
    }

    func testInsertKeepsCopyDateAndTitle() throws {
        let date = Date(timeIntervalSince1970: 1_000)

        let id = try XCTUnwrap(list.insertSynced(SyncContent([SyncFormats.text: Data("a".utf8)]), copiedAt: date, title: "Name", at: 0))

        XCTAssertEqual(list.syncItems, [SyncListItem(id: id, copiedAt: date, title: "Name")])
        XCTAssertEqual(list.syncContent(of: id), SyncContent([SyncFormats.text: Data("a".utf8)]))
    }

    func testInsertWithNothingToSaveAddsNothing() {
        XCTAssertNil(list.insertSynced(SyncContent([:]), copiedAt: Date(), title: nil, at: 0))
        XCTAssertTrue(history.items.isEmpty)
    }

    func testDeleteAndMove() throws {
        let a = try XCTUnwrap(list.insertSynced(SyncContent([SyncFormats.text: Data("a".utf8)]), copiedAt: Date(), title: nil, at: 0))
        _ = list.insertSynced(SyncContent([SyncFormats.text: Data("b".utf8)]), copiedAt: Date(), title: nil, at: 1)
        _ = list.insertSynced(SyncContent([SyncFormats.text: Data("c".utf8)]), copiedAt: Date(), title: nil, at: 2)

        list.moveSynced(a, to: 2)
        XCTAssertEqual(strings(), ["b", "c", "a"])

        list.deleteSynced(a)
        XCTAssertEqual(strings(), ["b", "c"])
        XCTAssertEqual(list.syncMaxItems, 3)
    }
}

class HistoryActivityTests: XCTestCase {

    /// Records what `History` reports.
    class Recorder: HistoryActivity {
        var events = [String]()

        func history(_ history: History, didCopy item: HistoryItem) {
            events.append("copy \(item.getPlainString() ?? "")")
        }

        func history(_ history: History, willDelete items: [HistoryItem]) {
            // The content can still be read
            events.append("delete " + items.map({ $0.getPlainString() ?? "" }).joined(separator: ","))
        }

        func historyDidClear(_ history: History) {
            events.append("clear")
        }

        func history(_ history: History, didChangeFavourite item: HistoryItem) {
            events.append("favourite \(item.getPlainString() ?? "") \(item.metadata.title ?? "")")
        }
    }

    var history: History!
    var favourites: History!
    var recorder: Recorder!
    var pasteboard: NSPasteboard!

    override func setUp() {
        history = History(historyFM: HistoryFileManagerMock(), cache: HistoryCache(), items: [], maxItems: 2)
        favourites = History(historyFM: HistoryFileManagerMock(), cache: HistoryCache(), items: [])
        recorder = Recorder()
        history.activity = recorder
        favourites.activity = recorder
        pasteboard = NSPasteboard(name: NSPasteboard.Name(rawValue: "HistoryActivityTests"))
    }

    override func tearDown() {
        pasteboard.releaseGlobally()
    }

    private func copy(_ str: String) {
        pasteboard.clearContents()
        pasteboard.setString(str, forType: .string)
        history.pasteboardDidChange(pasteboard, originBundleId: nil)
    }

    func testCopiesAreReported() {
        copy("a")
        copy("b")
        copy("a")

        XCTAssertEqual(recorder.events, ["copy a", "copy b", "copy a"])
    }

    func testTrimmingToTheLimitIsNotReported() {
        copy("a")
        copy("b")
        copy("c")

        XCTAssertEqual(recorder.events, ["copy a", "copy b", "copy c"])
    }

    func testUserDeletesAndClearsAreReported() {
        copy("a")
        copy("b")
        recorder.events = []

        history.deleteItemByUser(at: 1)
        history.deleteItem(at: 0)
        history.clearByUser()
        history.clear()

        XCTAssertEqual(recorder.events, ["delete a", "clear"])
    }

    func testFavouriteChangesAreReported() throws {
        let item = HistoryItem(unsavedData: [.string: Data("a".utf8)], cache: HistoryCache())
        favourites.toggleFavourite(item)
        let id = try XCTUnwrap(favourites.items.first?.fsId)

        favourites.renameFavourite(withId: id, to: " Name ")
        favourites.editFavourite(withId: id, text: "b")
        favourites.toggleFavourite(try XCTUnwrap(favourites.items.first))

        XCTAssertEqual(recorder.events, ["favourite a ", "favourite a Name", "delete a", "favourite b Name", "delete b"])
        XCTAssertTrue(favourites.items.isEmpty)
    }
}
