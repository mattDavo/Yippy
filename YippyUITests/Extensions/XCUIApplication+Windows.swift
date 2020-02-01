//
//  XCUIApplication+Windows.swift
//  YippyUITests
//
//  Created by Matthew Davidson on 29/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest

extension XCUIApplication {
    
    var welcomeWindow: XCUIElement {
        return windows[Accessibility.identifiers.welcomeWindow]
    }
    
    var helpWindow: XCUIElement {
        return windows[Accessibility.identifiers.helpWindow]
    }
    
    var aboutWindow: XCUIElement {
        return windows[Accessibility.identifiers.aboutWindow]
    }
    
    var yippyWindow: XCUIElement {
        return windows[Accessibility.identifiers.yippyWindow]
    }
}
