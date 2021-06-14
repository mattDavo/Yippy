//
//  YippyItemContentView.swift
//  Yippy
//
//  Created by Matthew Davidson on 13/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

/// A basic `NSView` subclass that handles updates of the system appearance (e.g. dark/light modes) and updates its `layer`'s background and border colors.
class YippyItemContentView: NSView {
    
    var usesDynamicBackgroundColor = true
    
    override func updateLayer() {
        super.updateLayer()
        
        if usesDynamicBackgroundColor {
            layer?.backgroundColor = NSColor(named: NSColor.Name("TextBackgroundColor"))?.cgColor
        }
        
        if #available(OSX 10.14, *) {
            layer?.borderColor = NSColor.controlAccentColor.cgColor
        } else {
            layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.7).cgColor
        }
    }
}
