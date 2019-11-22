//
//  YippyStatusItem.swift
//  Yippy
//
//  Created by Matthew Davidson on 9/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class YippyStatusItem {
    
    static var statusItemButtonImage = NSImage(named: NSImage.Name("YippyStatusBarIcon"))
    
    static func create() -> NSStatusItem {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = statusItemButtonImage
            button.setAccessibilityIdentifier(Accessibility.identifiers.statusItemButton)
        }
        
        return statusItem
    }
}
