//
//  XCUIApplication+Actions.swift
//  YippyUITests
//
//  Created by Matthew Davidson on 29/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest

extension XCUIApplication {
    
    func quit() {
        statusItemButton.click()
        quitButton.click()
    }
}
