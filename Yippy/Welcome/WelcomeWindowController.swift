//
//  WelcomeWindowController.swift
//  Yippy
//
//  Created by Matthew Davidson on 13/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class WelcomeWindowController: NSWindowController, NSWindowDelegate {
    
    var closeButton: NSButton!
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.delegate = self
        window?.setAccessibilityIdentifier(Accessibility.identifiers.welcomeWindow)
        closeButton = window?.standardWindowButton(.closeButton)
        closeButton.target = self
        closeButton.action = #selector(closeButtonClicked)
    }
    
    static func createWelcomeWindowController() -> WelcomeWindowController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier(stringLiteral: "WelcomeWindowController")
        guard let windowController = storyboard.instantiateController(withIdentifier: identifier) as? WelcomeWindowController else {
            fatalError("Failed to load WelcomeWindowController of type WelcomeWindowController from the Main storyboard.")
        }
        
        return windowController
    }
    
    @objc func closeButtonClicked() {
        NSApplication.shared.terminate(self)
    }
}
