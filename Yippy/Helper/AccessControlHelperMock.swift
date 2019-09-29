//
//  AccessControlHelperMock.swift
//  Yippy
//
//  Created by Matthew Davidson on 28/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class AccessControlHelperMock: AccessControlHelper {
    
    override func isControlGranted() -> Bool {
        return AccessControlMock.isControlGranted()
    }
    
    override func isControlGranted(showPopup: Bool) -> Bool {
        return AccessControlMock.isControlGranted()
    }
}
