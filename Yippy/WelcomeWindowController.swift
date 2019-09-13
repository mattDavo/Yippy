//
//  WelcomeWindowController.swift
//  Yippy
//
//  Created by Matthew Davidson on 13/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class WelcomeWindowController: NSWindowController {
    
    static func createWelcomeWindowController() -> WelcomeWindowController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier(stringLiteral: "WelcomeWindowController")
        guard let windowController = storyboard.instantiateController(withIdentifier: identifier) as? WelcomeWindowController else {
            fatalError("Failed to load WelcomeWindowController of type WelcomeWindowController from the Main storyboard.")
        }
        return windowController
    }
}
