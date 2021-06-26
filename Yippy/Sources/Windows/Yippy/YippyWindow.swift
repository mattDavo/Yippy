//
//  YippyWindow.swift
//  Yippy
//
//  Created by Matthew Davidson on 7/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class YippyWindow: NSPanel {
    
    /**
     Override to allow us to use setFrame to set the window frame such that it extends outside of the visible frame (under the menu bar if it is visible).
     
     It seems that the original function will allow us to set the frame under the menu bar if it's height is the full width of the screen but otherwise it will modify the frame.
     
     We simply just return the frame, allowing any frame.
     See: https://stackoverflow.com/a/6303578
     */
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
    
    override var canBecomeKey: Bool {
        return true
    }
}
