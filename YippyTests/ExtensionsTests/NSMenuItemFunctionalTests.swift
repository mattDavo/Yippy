//
//  NSMenuItemFunctionalTests.swift
//  YippyTests
//
//  Created by Matthew Davidson on 27/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest
@testable import Yippy

class NSMenuItemFunctionalTests: XCTestCase {

    var menuItem: NSMenuItem!
    
    override func setUp() {
        menuItem = NSMenuItem(title: "Test Menu Item", action: nil, keyEquivalent: "")
        menuItem.tag = 0
        menuItem.state = .off
    }
    
    func testWithSubmenu() {
        // 1. Given a menu item without a submenu and submenu
        XCTAssertNil(menuItem.submenu)
        let submenu = NSMenu(title: "")
        
        // 2. Then add a submenu
        menuItem = menuItem.with(submenu: submenu)
        
        // 3. The menu item should have the submenu
        XCTAssertEqual(menuItem.submenu, submenu)
    }
    
    func testWithTag() {
        // 1. Given a menu item with a tag
        let tag = 42
        XCTAssertNotEqual(menuItem.tag, tag)
        
        // 2. Set a new tag
        menuItem = menuItem.with(tag: tag)
        
        // 3. The menu item should have the new tag
        XCTAssertEqual(menuItem.tag, tag)
    }
    
    func testWithState() {
        // 1. Given a menu item with an off state
        XCTAssertEqual(menuItem.state, .off)
        
        // 2. Set an on state
        menuItem = menuItem.with(state: .on)
        
        // 3. The menu item should have an on state
        XCTAssertEqual(menuItem.state, .on)
    }
}
