//
//  NSMenu+Functional.swift
//  Yippy
//
//  Created by Matthew Davidson on 6/8/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Cocoa

extension NSMenu {
    
    func with(menuItem: NSMenuItem) -> NSMenu {
        self.addItem(menuItem)
        return self
    }
}
