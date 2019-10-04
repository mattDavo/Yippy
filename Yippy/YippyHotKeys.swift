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
    static var cmdDelete = YippyHotKey(key: .delete, modifiers: [.command])
    
    static var cmd0 = YippyHotKey(key: .zero, modifiers: [.command])
    static var cmd1 = YippyHotKey(key: .one, modifiers: [.command])
    static var cmd2 = YippyHotKey(key: .two, modifiers: [.command])
    static var cmd3 = YippyHotKey(key: .three, modifiers: [.command])
    static var cmd4 = YippyHotKey(key: .four, modifiers: [.command])
    static var cmd5 = YippyHotKey(key: .five, modifiers: [.command])
    static var cmd6 = YippyHotKey(key: .six, modifiers: [.command])
    static var cmd7 = YippyHotKey(key: .seven, modifiers: [.command])
    static var cmd8 = YippyHotKey(key: .eight, modifiers: [.command])
    static var cmd9 = YippyHotKey(key: .nine, modifiers: [.command])
}
