//
//  KeyPressHelperMock.swift
//  Yippy
//
//  Created by Matthew Davidson on 30/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import CoreGraphics

class KeyPressHelperMock: KeyPressHelper {
    
    override func press(keyCode: CGKeyCode, flags: CGEventFlags) {
        KeyPressMock.keyPress(keyCode: keyCode, flags: flags)
    }
}
