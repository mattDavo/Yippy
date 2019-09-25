//
//  NSEventModifierFlags+KeyPressMonitor.swift
//  Yippy
//
//  Created by Matthew Davidson on 22/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

extension NSEvent.ModifierFlags {
    func equals(_ modifierFlags: NSEvent.ModifierFlags) -> Bool {
        // Needs to be done like this because of this: https://stackoverflow.com/a/33159704
        // A dual subset comparison doesn't work
        if self.contains(.capsLock) != modifierFlags.contains(.capsLock) { return false }
        if self.contains(.command) != modifierFlags.contains(.command) { return false }
        if self.contains(.control) != modifierFlags.contains(.control) { return false }
        if self.contains(.deviceIndependentFlagsMask) != modifierFlags.contains(.deviceIndependentFlagsMask) { return false }
        if self.contains(.function) != modifierFlags.contains(.function) { return false }
        if self.contains(.help) != modifierFlags.contains(.help) { return false }
        if self.contains(.numericPad) != modifierFlags.contains(.numericPad) { return false }
        if self.contains(.option) != modifierFlags.contains(.option) { return false }
        if self.contains(.shift) != modifierFlags.contains(.shift) { return false }
        return true
    }
    
    func toDisjoinList() -> [NSEvent.ModifierFlags] {
        var list = [NSEvent.ModifierFlags]()
        if self.contains(.capsLock) { list.append(.capsLock) }
        if self.contains(.command) { list.append(.command) }
        if self.contains(.control) { list.append(.control) }
        if self.contains(.deviceIndependentFlagsMask) { list.append(.deviceIndependentFlagsMask) }
        if self.contains(.function) { list.append(.function) }
        if self.contains(.help) { list.append(.help) }
        if self.contains(.numericPad) { list.append(.numericPad) }
        if self.contains(.option) { list.append(.option) }
        if self.contains(.shift) { list.append(.shift) }
        return list
    }
    
    func stringifyFlags() -> [String] {
        var list = [String]()
        if self.contains(.capsLock) { list.append("capsLock") }
        if self.contains(.command) { list.append("command") }
        if self.contains(.control) { list.append("control") }
        if self.contains(.deviceIndependentFlagsMask) { list.append("deviceIndependentFlagsMask") }
        if self.contains(.function) { list.append("function") }
        if self.contains(.help) { list.append("help") }
        if self.contains(.numericPad) { list.append("numericPad") }
        if self.contains(.option) { list.append("option") }
        if self.contains(.shift) { list.append("shift") }
        return list
    }
    
    static var recommended: NSEvent.ModifierFlags = NSEvent.ModifierFlags(arrayLiteral: .command, .control, .option, .shift)
    static var all: NSEvent.ModifierFlags = NSEvent.ModifierFlags(arrayLiteral: .capsLock, .command, .control, .deviceIndependentFlagsMask, .function, .help, .numericPad, .option, .shift)
    static var none: NSEvent.ModifierFlags = .init()
}
