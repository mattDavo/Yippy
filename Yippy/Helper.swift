//
//  Helper.swift
//  Yippy
//
//  Created by Matthew Davidson on 25/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation

class Helper {
    
    static func press(keyCode: CGKeyCode, useCommandFlag: Bool) {
        let sourceRef = CGEventSource(stateID: .combinedSessionState)
        
        if sourceRef == nil {
            NSLog("FakeKey: No event source")
            return
        }
        
        let keyDownEvent = CGEvent(keyboardEventSource: sourceRef,
                                   virtualKey: keyCode,
                                   keyDown: true)
        if useCommandFlag {
            keyDownEvent?.flags = .maskCommand
        }
        
        let keyUpEvent = CGEvent(keyboardEventSource: sourceRef,
                                 virtualKey: keyCode,
                                 keyDown: false)
        
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
    }
    
    static func pressCommandV() {
        Helper.press(keyCode: 9, useCommandFlag: true)
    }
    
    // https://stackoverflow.com/questions/40144259/modify-accessibility-settings-on-macos-with-swift
    static func isControlGranted(showPopup: Bool) -> Bool {
        // get the value for accesibility
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        // set the options: false means it wont ask
        // true means it will popup and ask
        let options = [checkOptPrompt: showPopup]
        // translate into boolean value
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary?)
        return accessEnabled
    }
}
