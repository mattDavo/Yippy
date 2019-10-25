//
//  XCUIApplication+Yippy.swift
//  YippyUITests
//
//  Created by Matthew Davidson on 30/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest

extension XCUIApplication {
    
    var yippyTableView: XCUIElement {
        return yippyWindow.tables[Accessibility.identifiers.yippyTableView]
    }
    
    var yippyTableViewItems: XCUIElementQuery {
        return yippyTableView.cells
    }
    
    func getYippyTableViewCell(at i: Int) -> XCUIElement {
        return yippyTableViewItems.element(boundBy: i)
    }
    
    func getYippyTableViewCellTextView(at i: Int) -> XCUIElement {
        return getYippyTableViewCell(at: i).children(matching: .textView).matching(identifier: Accessibility.identifiers.yippyItemTextView).element
    }
    
    func getYippyTableViewItemString(at i: Int) -> String? {
        return getYippyTableViewCellTextView(at: i).value as? String
    }
    
    func getYippyTableViewCellType(at i: Int) -> String {
        return getYippyTableViewCell(at: i).label
    }
}
