//
//  Helper.swift
//  Yippy
//
//  Created by Matthew Davidson on 25/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation

class Helper {
    
    // MARK: - Key Press
    
    static func press(keyCode: CGKeyCode, flags: CGEventFlags) {
        let sourceRef = CGEventSource(stateID: .combinedSessionState)
        
        if sourceRef == nil {
            NSLog("FakeKey: No event source")
            return
        }
        
        let keyDownEvent = CGEvent(keyboardEventSource: sourceRef,
                                   virtualKey: keyCode,
                                   keyDown: true)
        keyDownEvent?.flags = flags
        
        let keyUpEvent = CGEvent(keyboardEventSource: sourceRef,
                                 virtualKey: keyCode,
                                 keyDown: false)
        
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
    }
    
    static func pressCommandV() {
        Helper.press(keyCode: 9, flags: .maskCommand)
    }
    
    // MARK: - Access Control
    
    static var accessControlHelper = AccessControlHelper()
    
    static func isControlGranted() -> Bool {
        return Helper.accessControlHelper.isControlGranted()
    }
    
    static func isControlGranted(showPopup: Bool) -> Bool {
        return Helper.accessControlHelper.isControlGranted(showPopup: showPopup)
    }
}







