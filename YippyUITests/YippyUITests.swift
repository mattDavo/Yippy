//
//  YippyUITests.swift
//  YippyUITests
//
//  Created by Matthew Davidson on 26/7/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest
import HotKey

class YippyUITests: XCTestCase {

    var app: XCUIApplication!
    
    override func setUp() {
        // We want to continue after failure because we want a clean exit, so that we can restore the state of the application when quitting. For example, the user defaults.
        continueAfterFailure = true
        
        // Set full access control
        AccessControlMock.setControlGranted(true)
        
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
    }
    
    override func tearDown() {
        // Quit cleanly
        app.quit()
    }
    
    func testYippyToggle() {
        // Launch app
        app.launch()
        
        // Check window isn't displayed
        XCTAssertFalse(app.yippyWindow.isDisplayed)
        
        // Toggle window
        app.statusItemButton.click()
        app.toggleYippyWindowButton.click()
        
        // Check window is displayed
        XCTAssertTrue(app.yippyWindow.isDisplayed)
        
        // Toggle window
        app.statusItemButton.click()
        app.toggleYippyWindowButton.click()
        
        // Check window isn't displayed
        XCTAssertFalse(app.yippyWindow.isDisplayed)
    }
    
    func testHotKeyToggle() {
        // Launch app
        app.launch()
        
        // Check window isn't displayed
        XCTAssertFalse(app.yippyWindow.isDisplayed)
        
        // HotKey toggle
        app.pressHotKey()
        
        // Check window is displayed
        XCTAssertTrue(app.yippyWindow.isDisplayed)
        
        // HotKey toggle
        app.pressHotKey()
        
        // Check window isn't displayed
        XCTAssertFalse(app.yippyWindow.isDisplayed)
        
        // HotKey toggle
        app.pressHotKey()
        
        // Check window is displayed
        XCTAssertTrue(app.yippyWindow.isDisplayed)
        
        // Type escape
        app.typeKey(XCUIKeyboardKey.escape)
        
        // Check window isn't displayed
        XCTAssertFalse(app.yippyWindow.isDisplayed)
    }
    
    func testYippyWindowPositions() {
        // Launch app
        app.launch()
        
        // Check window isn't displayed
        XCTAssertFalse(app.yippyWindow.isDisplayed)
        
        // HotKey toggle
        app.pressHotKey()
        
        // Check window is displayed
        XCTAssertTrue(app.yippyWindow.isDisplayed)
        
        // Check window location is .right
        XCTAssertEqual(app.yippyWindow.frame.midX, PanelPosition.right.frame.midX)
        
        // Change to position left
        app.statusItemButton.click()
        app.positionButton.click()
        app.positionLeftButton.click()
        
        // Check window location is .left
        XCTAssertEqual(app.yippyWindow.frame.midX, PanelPosition.left.frame.midX)
        
        // Change to position bottom
        app.statusItemButton.click()
        app.positionButton.click()
        app.positionBottomButton.click()
        
        // Check window location is .bottom
        let statusBarHeight = NSScreen.main!.frame.height - NSScreen.main!.visibleFrame.height
        XCTAssertEqual(app.yippyWindow.frame.midY, NSScreen.main!.visibleFrame.height + statusBarHeight - Constants.panel.menuHeight/2)
        
        // Change to position top
        app.statusItemButton.click()
        app.positionButton.click()
        app.positionTopButton.click()
        
        // Check window location is .top
        XCTAssertEqual(app.yippyWindow.frame.midY, Constants.panel.menuHeight/2)
        
        // Change back to position right
        app.statusItemButton.click()
        app.positionButton.click()
        app.positionRightButton.click()
        
        // Check window location is .right
        XCTAssertEqual(app.yippyWindow.frame.midX, PanelPosition.right.frame.midX)
    }
    
    func testEmptyYippyHistory() {
        // Test no contents on pasteboard
        NSPasteboard.general.clearContents()
        
        // Launch app
        app.launch()
        
        // Open Yippy window
        app.pressHotKey()
        
        // Check Yippy window displayed with no cells
        XCTAssertTrue(app.yippyCollectionView.isDisplayed)
        XCTAssertEqual(app.yippyCollectionViewItems.count, 0)
        
        // Close Yippy window
        app.pressHotKey()
        
        // Copy something
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString("My first test!", forType: .string)
        
        // Show the Yippy window
        app.pressHotKey()
        
        // Check Yippy window displayed with 1 cell
        XCTAssertTrue(app.yippyCollectionView.isDisplayed)
        XCTAssertEqual(app.yippyCollectionViewItems.count, 1)
        XCTAssertEqual(app.getYippyCollectionViewString(at: 0), "My first test!")
    }
    
    func testLoadFromDefinedSettings() {
        // Copy something
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString("My latest copy", forType: .string)
        
        // Set settings environment
        app.launchArguments.append("--Settings.testData=a")
        
        // Launch app
        app.launch()
        
        // Open Yippy window
        app.pressHotKey()
        
        // Check Yippy window displayed with correct number of cells
        XCTAssertTrue(app.yippyCollectionView.isDisplayed)
        XCTAssertEqual(app.yippyCollectionViewItems.count, 5)
    }
    
    func testEnterToPaste() {
        // Copy something
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString("My latest copy", forType: .string)
        
        // Set settings environment
        app.launchArguments.append("--Settings.testData=a")
        
        // Launch app
        app.launch()
        
        // Open Yippy window
        app.pressHotKey()
        app.typeKey(.return)
        
        // Handle the key press
        let keyPress = KeyPressMock.handleKeyPress()
        // Assert there was a key press
        XCTAssertNotNil(keyPress)
        // Assert it was a c + cmd key press
        let (keyCode, flags) = keyPress!
        XCTAssertEqual(keyCode, UITesting.cKeyCode)
        XCTAssertEqual(flags, UITesting.enterEventFlags)
        // Assert there was just a single key press
        XCTAssertNil(KeyPressMock.handleKeyPress())
        
        // Assert the Yippy window is closed
        XCTAssertFalse(app.yippyWindow.isDisplayed)
    }
    
    func testPasteFromHistory() {
        // Copy something
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString("My latest copy", forType: .string)
        
        // Set settings environment
        app.launchArguments.append("--Settings.testData=a")
        
        // Launch app
        app.launch()
        
        // Open Yippy window
        app.pressHotKey()
        // Select index 2
        app.getYippyCollectionViewCell(at: 2).click()
        app.typeKey(.return)
        
        // Assert there was a single key press
        XCTAssertNotNil(KeyPressMock.handleKeyPress())
        XCTAssertNil(KeyPressMock.handleKeyPress())
        
        // Assert the Yippy window is closed
        XCTAssertFalse(app.yippyWindow.isDisplayed)
        
        // Assert the pasteboard now contains the index 2 text (index 1 in history)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), UITesting.testHistory.a[1])
        
        // Open Yippy window
        app.pressHotKey()
        
        // Check that the items have been shuffled
        XCTAssertEqual(app.getYippyCollectionViewString(at: 0), UITesting.testHistory.a[1])
        XCTAssertEqual(app.getYippyCollectionViewString(at: 1), "My latest copy")
        XCTAssertEqual(app.getYippyCollectionViewString(at: 2), UITesting.testHistory.a[0])
    }
}
