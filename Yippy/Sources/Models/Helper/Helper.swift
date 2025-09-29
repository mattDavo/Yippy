//
//  Helper.swift
//  Yippy
//
//  Created by Matthew Davidson on 25/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import CoreGraphics

class Helper {
    
    // MARK: - Key Press
    
    static var keyPressHelper = KeyPressHelper()
    
    static func press(keyCode: CGKeyCode, flags: CGEventFlags) {
        keyPressHelper.press(keyCode: keyCode, flags: flags)
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







