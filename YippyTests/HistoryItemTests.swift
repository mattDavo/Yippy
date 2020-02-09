//
//  HistoryItemTests.swift
//  YippyTests
//
//  Created by Matthew Davidson on 21/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest
@testable import Yippy

class HistoryItemTests: XCTestCase {

    var savedItem: HistoryItem!
    var unsavedItem: HistoryItem!
    
    var unsavedData: [NSPasteboard.PasteboardType: Data]!
    
    var cache: HistoryCacheMock!
    
    override func setUp() {
        
        unsavedData = [.string: "Test".data(using: .utf8)!]
        
        cache = HistoryCacheMock()
        
        savedItem = HistoryItem(
            fsId: UUID(),
            types: [.string],
            cache: cache
        )
        
        unsavedItem = HistoryItem(
            unsavedData: unsavedData,
            cache: cache
        )
    }
    
    // MARK: - data()
    func testDataForMissingType() {
        // 1. For an item without a type
        XCTAssertFalse(savedItem.types.contains(.color))
        
        // 2. Get the data for that type
        let res = savedItem.data(forType: .color)
        
        // 3. The data should be nil
        XCTAssertNil(res)
    }
    
    func testDataForTypeInUnsavedData() {
        // 1. For an item with a type
        XCTAssertTrue(savedItem.types.contains(.string))
        
        // 2. Get the data for that type
        let res = unsavedItem.data(forType: .string)
        
        // 3. Should be the unsaved data
        XCTAssertEqual(res, unsavedData[.string])
    }
    
    func testDataForNoUnsavedData() {
        // 1. Set up the mock
        let data = Data(repeating: 1, count: 1)
        cache.data = data
        
        // 2. Get the data for that type
        let res = savedItem.data(forType: .string)
        
        // 3. Should be the data from the cache
        XCTAssertEqual(res, data)
        XCTAssertEqual(cache.dataCallCount, 1)
    }
    
    // MARK: - startCaching()
    func testStartCaching() {
        // 1. Start not caching with unsaved data
        XCTAssertFalse(unsavedItem.isCached)
        XCTAssertNotNil(unsavedItem.unsavedData)
        
        // 2. Start caching
        unsavedItem.startCaching()
        
        // 3. Unsaved data should be nil and should be caching
        self.expectation(for: NSPredicate(block: { (_, _) -> Bool in
            return self.unsavedItem.isCached && self.unsavedItem.unsavedData == nil
        }), evaluatedWith: nil, handler: nil)
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    // MARK: - stopCaching()
    func testStopCaching() {
        // 1. Need to make sure caching has started.
        self.expectation(for: NSPredicate(block: { (_, _) -> Bool in
            return self.savedItem.isCached
        }), evaluatedWith: nil, handler: { () -> Bool in
            // 2. Start caching
            self.savedItem.stopCaching()
            return true
        })
        
        // 3. Unsaved data should be nil and should not be caching
        self.expectation(for: NSPredicate(block: { (_, _) -> Bool in
            return !self.savedItem.isCached && self.savedItem.unsavedData == nil
        }), evaluatedWith: nil, handler: nil)
        
        waitForExpectations(timeout: 2, handler: nil)
    }
}
