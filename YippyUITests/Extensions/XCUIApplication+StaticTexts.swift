//
//  XCUIApplication+StaticTexts.swift
//  YippyUITests
//
//  Created by Matthew Davidson on 29/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest

extension XCUIApplication {
    
    var waitingForControlLabel: XCUIElement {
        return helpWindow.staticTexts[Accessibility.identifiers.waitingForControlLabel]
    }
    
    var howToUseLabel: XCUIElement {
        return helpWindow.staticTexts[Accessibility.identifiers.howToUseLabel]
    }
}
