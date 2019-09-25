//
//  PasteboardMonitor.swift
//  Yippy
//
//  Created by Matthew Davidson on 17/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class PasteboardMonitor {
    
    let intervalInSeconds: TimeInterval = 0.05
    
    var pasteboard: NSPasteboard!
    var timer: Timer!
    var lastChangeCount: Int!
    var delegate: PasteboardMonitorDelegate!
    
    init(pasteboard: NSPasteboard, changeCount: Int = -1, delegate: PasteboardMonitorDelegate! = nil) {
        self.pasteboard = pasteboard
        self.delegate = delegate
        self.lastChangeCount = changeCount
        
        self.timer = Timer.scheduledTimer(withTimeInterval: intervalInSeconds, repeats: true) { (t) in
            if self.lastChangeCount != self.pasteboard.changeCount  {
                self.lastChangeCount = self.pasteboard.changeCount
                if let delegate = delegate {
                    delegate.pasteboardDidChange(pasteboard)
                }
            }
        }
    }
}
