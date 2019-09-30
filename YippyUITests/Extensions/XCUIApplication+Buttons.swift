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
    
    var positionButton: XCUIElement {
        return self.menus.menuItems[Accessibility.identifiers.positionButton]
    }
    
    var positionLeftButton: XCUIElement {
        return positionButton.menus.menuItems[Accessibility.identifiers.positionLeftButton]
    }
    
    var positionRightButton: XCUIElement {
        return positionButton.menus.menuItems[Accessibility.identifiers.positionRightButton]
    }
    
    var positionTopButton: XCUIElement {
        return positionButton.menus.menuItems[Accessibility.identifiers.positionTopButton]
    }
    
    var positionBottomButton: XCUIElement {
        return positionButton.menus.menuItems[Accessibility.identifiers.positionBottomButton]
    }
}
