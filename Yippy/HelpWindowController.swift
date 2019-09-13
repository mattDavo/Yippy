//
//  HelpWindowController.swift
//  Yippy
//
//  Created by Matthew Davidson on 13/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class HelpWindowController: NSWindowController {
    
    static func createHelpWindowController() -> HelpWindowController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier(stringLiteral: "HelpWindowController")
        guard let windowController = storyboard.instantiateController(withIdentifier: identifier) as? HelpWindowController else {
            fatalError("Failed to load HelpWindowController of type HelpWindowController from the Main storyboard.")
        }
        return windowController
    }
}
