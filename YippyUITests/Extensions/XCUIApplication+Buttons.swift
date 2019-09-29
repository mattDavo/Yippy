//
//  XCUIApplication+Buttons.swift
//  YippyUITests
//
//  Created by Matthew Davidson on 29/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest

extension XCUIApplication {
    
    var welcomeAllowAccessButton: XCUIElement {
        return welcomeWindow.buttons[Accessibility.identifiers.welcomeAllowAccessButton]
    }
    
    var statusItemButton: XCUIElement {
        return self.statusItems[Accessibility.identifiers.statusItemButton]
    }
    
    var toggleYippyWindowButton: XCUIElement {
        return self.menus.menuItems[Accessibility.identifiers.toggleYippyWindowButton]
    }
    
    var quitButton: XCUIElement {
        return self.menus.menuItems[Accessibility.identifiers.quitButton]
    }
    
    var helpButton: XCUIElement {
        return self.menus.menuItems[Accessibility.identifiers.helpButton]
    }
    
    var aboutButton: XCUIElement {
        return self.menus.menuItems[Accessibility.identifiers.aboutButton]
    }
}
