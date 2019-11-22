//
//  NSMenuItem+Functional.swift
//  Yippy
//
//  Created by Matthew Davidson on 6/8/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Cocoa

extension NSMenuItem {
    
    func with(submenu: NSMenu) -> NSMenuItem {
        self.submenu = submenu
        return self
    }
    
    func with(state: NSControl.StateValue) -> NSMenuItem {
        self.state = state
        return self
    }
    
    func with(tag: Int) -> NSMenuItem {
        self.tag = tag
        return self
    }
    
    func with(accessibilityIdentifier: String) -> NSMenuItem {
        self.setAccessibilityIdentifier(accessibilityIdentifier)
        return self
    }
    
    func with(isEnabled: Bool) -> NSMenuItem {
        self.isEnabled = isEnabled
        return self
    }
}
