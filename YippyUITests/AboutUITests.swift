//
//  AboutUITests.swift
//  YippyUITests
//
//  Created by Matthew Davidson on 29/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest

class AboutUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        // Nothing to clean up after a failure
        continueAfterFailure = false
        
        // Set full access control
        AccessControlMock.setControlGranted(true)
        
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launchArguments.append("--test-dir=Empty")
        app.launchEnvironment["SRCROOT"] = ProcessInfo.processInfo.environment["SRCROOT"]
        
        // Launch app
        app.launch()
    }
    
    func testAboutButton() {
        // Click on about button
        app.statusItemButton.click()
        app.aboutButton.click()
        
        // Check that the about window is showing
        XCTAssertTrue(app.aboutWindow.isDisplayed)
    }
}
