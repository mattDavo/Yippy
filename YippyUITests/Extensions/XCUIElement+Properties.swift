//
//  XCUIElement+Properties.swift
//  YippyUITests
//
//  Created by Matthew Davidson on 29/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest

extension XCUIElement {
    
    var isDisplayed: Bool {
        return exists && isHittable
    }
}
