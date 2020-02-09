//
//  HistoryCacheTests.swift
//  YippyTests
//
//  Created by Matthew Davidson on 20/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest
@testable import Yippy

class HistoryCacheTests: XCTestCase {

    var cache: HistoryCache!
    
    // Mocked out dependencies
    var historyFM: HistoryFileManagerMock!
    var errorLogger: ErrorLoggerMock!
    var warningLogger: WarningLoggerMock!
    let maxCacheSize = 100
    
    override func setUp() {
        historyFM = HistoryFileManagerMock()
        errorLogger = ErrorLoggerMock()
        warningLogger = WarningLoggerMock()
        
        cache = HistoryCache(
            historyFM: historyFM,
            maxCacheSize: maxCacheSize,
            errorLogger: errorLogger,
            warningLogger: warningLogger
        )
    }

    
    // MARK: - data()
    func testDataWhenFMReturnsNil() {
        // 1. Set up mock to return nil, nothing is required
        
        // 2. Call
        let res = cache.data(withId: UUID(), forType: .string)
        
        // 3. Assert the result returns nil
        XCTAssertNil(res)
    }
    
    func testDataWhenItemUnregistered() {
        // 1. Set up mock to return data
        let data = Data(repeating: 0, count: 4)
        let id = UUID()
        let type = NSPasteboard.PasteboardType.string
        historyFM.data[id] = [type: data]
        XCTAssertGreaterThan(data.count, 0)
        XCTAssertEqual(cache.currentCacheSize, 0)
        
        // 2. Call
        let res = cache.data(withId: id, forType: type)
        
        // 3. Assert the result is what we expect, and the cache hasn't grown
        XCTAssertEqual(res, data)
        XCTAssertEqual(cache.currentCacheSize, 0)
    }
    
    func testDataWhenDataGreaterThanCacheSize() {
        // 1. Set up mock to return data
        let data = Data(repeating: 0, count: 101)
        let id = UUID()
        let type = NSPasteboard.PasteboardType.string
        historyFM.data[id] = [type: data]
        XCTAssertGreaterThan(data.count, cache.maxCacheSize)
        XCTAssertEqual(cache.currentCacheSize, 0)
        
        // 2. Call
        let res = cache.data(withId: id, forType: type)
        
        // 3. Assert the result is what we expect, and the cache hasn't grown
        XCTAssertEqual(res, data)
        XCTAssertEqual(cache.currentCacheSize, 0)
    }
    
    func testDataWhenDataIsCached() {
        // 1. Set up mock to return data
        let data = Data(repeating: 0, count: 1)
        let id = UUID()
        let type = NSPasteboard.PasteboardType.string
        historyFM.data[id] = [type: data]
        XCTAssertEqual(cache.currentCacheSize, 0)
        
        // 2. Register id, load data from storage, load from cache
        cache.registerItem(withId: id)
        let res = cache.data(withId: id, forType: type)
        let res1 = cache.data(withId: id, forType: type)
        
        // 3. Assert the result is what we expect, the cache has grown, and the file manager is only called once.
        XCTAssertEqual(res, data)
        XCTAssertEqual(res1, data)
        XCTAssertEqual(cache.currentCacheSize, data.count)
        XCTAssertEqual(historyFM.dataCallCount, 1)
    }
    
    func testDataWhenCacheIsFull() {
        // 1. Set up mock to return data
        let data1 = Data(repeating: 0, count: 75)
        let data2 = Data(repeating: 1, count: 25)
        let data3 = Data(repeating: 2, count: 50)
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()
        let type = NSPasteboard.PasteboardType.string
        historyFM.data[id1] = [type: data1]
        historyFM.data[id2] = [type: data2]
        historyFM.data[id3] = [type: data3]
        XCTAssertEqual(cache.currentCacheSize, 0)
        
        // 2. Register, load data from storage
        cache.registerItem(withId: id1)
        cache.registerItem(withId: id2)
        cache.registerItem(withId: id3)
        let res1 = cache.data(withId: id1, forType: type)
        let res2 = cache.data(withId: id2, forType: type)
        let res3 = cache.data(withId: id3, forType: type)
        
        // 3. Assert the result is what we expect, the cache grows then evicts the first, and the file manager is called 3 times.
        XCTAssertEqual(res1, data1)
        XCTAssertEqual(res2, data2)
        XCTAssertEqual(res3, data3)
        XCTAssertEqual(cache.currentCacheSize, data2.count + data3.count)
        XCTAssertEqual(historyFM.dataCallCount, 3)
    }
    
    
    // MARK: - registerItem()
    func testRegisterItem() {
        // 1. Set up mock to return data
        let data = Data(repeating: 0, count: 1)
        let id = UUID()
        let type = NSPasteboard.PasteboardType.string
        historyFM.data[id] = [type: data]
        XCTAssertEqual(cache.currentCacheSize, 0)
        
        // 2. Register id, load data from storage, load from cache
        let res = cache.data(withId: id, forType: type)
        let cacheSizeBefore = cache.currentCacheSize
        cache.registerItem(withId: id)
        let res1 = cache.data(withId: id, forType: type)
        let cacheSizeAfter = cache.currentCacheSize
        
        // 3. Assert the result is what we expect, the cache size only grows after registering the item, and that the file manager is called twice
        XCTAssertEqual(res, data)
        XCTAssertEqual(res1, data)
        XCTAssertEqual(cacheSizeBefore, 0)
        XCTAssertEqual(cacheSizeAfter, data.count)
        XCTAssertEqual(historyFM.dataCallCount, 2)
    }
    
    
    // MARK: - unregisterItem()
    func testUnregisterItem() {
        // 1. Set up mock to return data
        let data = Data(repeating: 0, count: 1)
        let id = UUID()
        let type = NSPasteboard.PasteboardType.string
        historyFM.data[id] = [type: data]
        XCTAssertEqual(cache.currentCacheSize, 0)
        
        // 2. Register id
        cache.registerItem(withId: id)
        // Load data once
        let res = cache.data(withId: id, forType: type)
        // Get the cache size
        let cacheSizeBefore = cache.currentCacheSize
        // Unregister the id
        cache.unregisterItem(withId: id)
        // Cache size should now be 0
        
        // Load the data again
        let res1 = cache.data(withId: id, forType: type)
        
        // Cache size should still be 0
        
        // 3. Assert the result is what we expect, the cache reduces after unregsitering the item, and that the file manager is called twice
        self.expectation(for: NSPredicate(block: { (_, _) -> Bool in
            return self.cache.currentCacheSize == 0
        }), evaluatedWith: nil, handler: nil)
        
        XCTAssertEqual(res, data)
        XCTAssertEqual(res1, data)
        XCTAssertEqual(cacheSizeBefore, data.count)
        waitForExpectations(timeout: 2)
        XCTAssertEqual(historyFM.dataCallCount, 2)
    }
    
    
    // MARK: - isItemRegistered()
    func testIsItemRegsitered() {
        // 1. Create an id, should initially be unregisted
        let id = UUID()
        XCTAssertFalse(cache.isItemRegistered(id))
        
        // 2. Register the id
        cache.registerItem(withId: id)
        
        // Wait for confirmation it is registered. Then unregister the item
        self.expectation(for: NSPredicate(block: { (_,_) -> Bool in
            return self.cache.isItemRegistered(id)
        }), evaluatedWith: nil) { () -> Bool in
            self.cache.unregisterItem(withId: id)
            return true
        }
        
        // Wait for confirmation the item is unregistered.
        self.expectation(for: NSPredicate(block: { (_,_) -> Bool in
            return !self.cache.isItemRegistered(id)
        }), evaluatedWith: nil, handler: nil)
        
        waitForExpectations(timeout: 2, handler: nil)
    }
}
