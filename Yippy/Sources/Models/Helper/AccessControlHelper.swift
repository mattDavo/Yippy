//
//  AccessControlHelper.swift
//  Yippy
//
//  Created by Matthew Davidson on 28/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import ApplicationServices

class AccessControlHelper {
    
    // https://stackoverflow.com/questions/40144259/modify-accessibility-settings-on-macos-with-swift
    
    func isControlGranted() -> Bool {
        return AXIsProcessTrusted()
    }
    
    func isControlGranted(showPopup: Bool) -> Bool {
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
