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
    static var pageDown = YippyHotKey(key: .pageDown, modifiers: [])
    static var pageUp = YippyHotKey(key: .pageUp, modifiers: [])
    static var cmdLeftArrow = YippyHotKey(key: .leftArrow, modifiers: [.command])
    static var cmdRightArrow = YippyHotKey(key: .rightArrow, modifiers: [.command])
    static var cmdDownArrow = YippyHotKey(key: .downArrow, modifiers: [.command])
    static var cmdUpArrow = YippyHotKey(key: .upArrow, modifiers: [.command])
}
