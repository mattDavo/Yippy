//
//  YippyHotKeys.swift
//  Yippy
//
//  Created by Matthew Davidson on 22/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation

struct YippyHotKeys {
    
    static var toggle = YippyHotKey(key: .v, modifiers: [.command, .shift])
    static var `return` = YippyHotKey(key: .return, modifiers: [])
    static var escape = YippyHotKey(key: .escape, modifiers: [])
    static var downArrow = YippyHotKey(key: .downArrow, modifiers: [])
    static var upArrow = YippyHotKey(key: .upArrow, modifiers: [])
}
