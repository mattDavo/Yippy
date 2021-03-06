//
//  WelcomeUITests.swift
//  YippyUITests
//
//  Created by Matthew Davidson on 27/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest

class WelcomeUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        // Nothing to clean up after a failure
        continueAfterFailure = false
        
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
    }
    
    func testWelcomeDisplayedWhenNoAccess() {
        // Set no access control
        AccessControlMock.setControlGranted(false)
        
        // Launch app
        app.launch()
        
        // Make sure we're displaying welcome window
        XCTAssertTrue(app.welcomeWindow.isDisplayed)
    }

    func testWelcomeNotDisplayedWhenAccess() {
        // Set full access control
        AccessControlMock.setControlGranted(true)
        
        // Launch app
        app.launch()
        
        // Make sure we're not displaying welcome window
        XCTAssertFalse(app.welcomeWindow.isDisplayed)
    }
    
    func testWelcomeAllowAccessButtonPromptsWindows() {
        // Set no access control
        AccessControlMock.setControlGranted(false)
        
        // Launch app
        app.launch()
        
        // Make sure we're displaying welcome window
        XCTAssertTrue(app.welcomeWindow.isDisplayed)
        
        // Click allow access
        app.welcomeAllowAccessButton.click()
        
        // Make sure we're displaying the help window
        XCTAssertTrue(app.helpWindow.isDisplayed)
    }
}
