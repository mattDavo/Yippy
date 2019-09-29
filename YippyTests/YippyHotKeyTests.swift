//
//  YippyHotKeyTests.swift
//  YippyTests
//
//  Created by Matthew Davidson on 27/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest
@testable import Yippy
@testable import HotKey

class YippyHotKeyTests: XCTestCase {
    
    var hotKey: HotKey!
    var yippyHotKey: YippyHotKey!

    override func setUp() {
        hotKey = HotKey(key: .a, modifiers: .none)
        yippyHotKey = YippyHotKey(hotKey: hotKey)
    }
    
    func testKeyUp() {
        // 1. Given a handler registered to the hot key
        let keyUpHandlerCalled = expectation(description: "keyUpHandlerCalled")
        let handler = {
            keyUpHandlerCalled.fulfill()
        }
        yippyHotKey.onUp(handler)
        
        // 2. When we have a key up event
        hotKey.simulateKeyUp()
        
        // 3. Then the handler should be called
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testKeyDown() {
        // 1. Given a handler registered to the hot key
        let keyDownHandlerCalled = expectation(description: "keyDownHandlerCalled")
        let handler = {
            keyDownHandlerCalled.fulfill()
        }
        yippyHotKey.onDown(handler)
        
        // 2. When we have a key down event
        hotKey.simulateKeyDown()
        
        // 3. Then the handler should be called
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testIsPaused() {
        // 1. Given a handler registered to the hot key
        let keyDownHandlerCalled = expectation(description: "keyDownHandlerCalled")
        keyDownHandlerCalled.isInverted = true
        let handler = {
            keyDownHandlerCalled.fulfill()
        }
        yippyHotKey.isPaused = true
        yippyHotKey.onDown(handler)
        
        // 2. When we have a key down event
        hotKey.simulateKeyDown()
        
        // 3. Then the handler should be called
        waitForExpectations(timeout: 0.5, handler: nil)
    }
    
    func testLongPress() {
        // 1. Given a handler registered to the hot key and the following long press settings
        let keyDownHandlerCalled = expectation(description: "keyDownHandlerCalled")
        keyDownHandlerCalled.expectedFulfillmentCount = 4
        let handler = {
            keyDownHandlerCalled.fulfill()
        }
        yippyHotKey.onLong(handler)
        yippyHotKey.longPressStartingInterval = 0.5
        yippyHotKey.longPressAcceleration = 2
        yippyHotKey.longPressMinInterval = 0.1
        
        // 2. When we have a long press event
        // 0.5 + 0.25 + 0.125 + 0.1 = 0.975 => 4
        // ROund to 0.98 to be safe
        hotKey.simulateKeyPress(for: 0.98)
        
        // 3. Then the handler should be called multiple times
        waitForExpectations(timeout: 1.1, handler: nil)
    }
}

// MARK: - Partial Hot Key Mock
// On partial mock is possible because the HotKey class is final.

extension HotKey {
    
    func simulateKeyDown() {
        if !isPaused {
            if let handler = keyDownHandler {
                handler()
            }
        }
    }
    
    func simulateKeyUp() {
        if !isPaused {
            if let handler = keyUpHandler {
                handler()
            }
        }
    }
    
    func simulateKeyPress() {
        simulateKeyDown()
        simulateKeyUp()
    }
    
    func simulateKeyPress(for interval: TimeInterval) {
        simulateKeyDown()
        Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            self.simulateKeyUp()
        }
    }
}
