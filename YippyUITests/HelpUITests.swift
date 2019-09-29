//
//  HelpUITests.swift
//  YippyUITests
//
//  Created by Matthew Davidson on 29/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest

class HelpUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        // We want to continue after failure because we want a clean exit, so that we can restore the state of the application when quitting. For example, the user defaults.
        continueAfterFailure = true
        
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
    }

    override func tearDown() {
        // Quit cleanly
        app.quit()
    }

    func testSetupThroughHelp() {
        // Set no access control
        AccessControlMock.setControlGranted(false)
        
        // Launch app
        app.launch()
        
        // Click on allow access
        app.welcomeAllowAccessButton.click()
        
        // Check help is showing
        XCTAssertTrue(app.helpWindow.isDisplayed)
        
        // Check that we're waiting for control
        XCTAssertTrue(app.waitingForControlLabel.isDisplayed)
        XCTAssertFalse(app.howToUseLabel.isDisplayed)
        
        // Provide control
        AccessControlMock.setControlGranted(true)
        
        // Check that now the instructions are shown
        XCTAssertTrue(app.howToUseLabel.waitForExistence(timeout: 1))
        XCTAssertTrue(app.howToUseLabel.isDisplayed)
        XCTAssertFalse(app.waitingForControlLabel.isDisplayed)
    }
    
    func testHelpButton() {
        // Set access granted
        AccessControlMock.setControlGranted(true)
        
        // Launch app
        app.launch()
        
        // Click on help button
        app.statusItemButton.click()
        app.helpButton.click()
        
        // Check that the help window is showing
        XCTAssertTrue(app.helpWindow.isDisplayed)
    }
}
