//
//  AboutUITests.swift
//  YippyUITests
//
//  Created by Matthew Davidson on 29/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest

class ABoutUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        // We want to continue after failure because we want a clean exit, so that we can restore the state of the application when quitting. For example, the user defaults.
        continueAfterFailure = true
        
        // Set full access control
        AccessControlMock.setControlGranted(true)
        
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        
        // Launch app
        app.launch()
    }
    
    override func tearDown() {
        // Quit cleanly
        app.quit()
    }
    
    func testAboutButton() {
        // Click on about button
        app.statusItemButton.click()
        app.aboutButton.click()
        
        // Check that the about window is showing
        XCTAssertTrue(app.aboutWindow.isDisplayed)
    }
}
