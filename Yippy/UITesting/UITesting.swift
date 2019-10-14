//
//  UITesting.swift
//  Yippy
//
//  Created by Matthew Davidson on 28/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation

struct UITesting {
    
    static var oldUserDefaults = [String: Any]()
    
    static let cKeyCode = CGKeyCode(9)
    static let enterEventFlags = CGEventFlags.maskCommand
    
    struct testHistory {
        static let a = [
            stringItem("Should be below whatever is on the pasteboard."),
            stringItem(
                """
                func testYippyToggle() {
                    // Launch app
                    app.launch()
                    
                    // Check window isn't displayed
                    XCTAssertFalse(app.yippyWindow.isDisplayed)
                    
                    // Toggle window
                    app.statusItemButton.click()
                    app.toggleYippyWindowButton.click()
                    
                    // Check window is displayed
                    XCTAssertTrue(app.yippyWindow.isDisplayed)
                    
                    // Toggle window
                    app.statusItemButton.click()
                    app.toggleYippyWindowButton.click()
                    
                    // Check window isn't displayed
                    XCTAssertFalse(app.yippyWindow.isDisplayed)
                }
                """),
            stringItem("https://stackoverflow.com/questions/41966151/how-to-access-the-detailtextlabel-in-a-tableviewcell-at-uitests"),
            stringItem("Hello world")
        ]
    }
    
    static func stringItem(_ str: String) -> HistoryItem {
        return HistoryItem(data: [
            .string: str.data(using: .utf8)!
        ])
    }
}
