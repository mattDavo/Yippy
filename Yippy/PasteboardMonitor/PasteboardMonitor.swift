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
    
    private var timer: Timer!
    private var lastChangeCount: Int!
    
    var pasteboard: NSPasteboard!
    var delegate: PasteboardMonitorDelegate!
    
    init(pasteboard: NSPasteboard, changeCount: Int = -1, delegate: PasteboardMonitorDelegate) {
        self.pasteboard = pasteboard
        self.delegate = delegate
        self.lastChangeCount = changeCount
        
        self.timer = Timer.scheduledTimer(withTimeInterval: intervalInSeconds, repeats: true) { (t) in
            self.checkIfPasteboardChanged()
        }
    }
    
    private func checkIfPasteboardChanged() {
        if lastChangeCount != pasteboard.changeCount  {
            lastChangeCount = self.pasteboard.changeCount
            delegate.pasteboardDidChange(pasteboard)
        }
    }
}
