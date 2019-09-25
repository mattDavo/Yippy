//
//  KeyActionHandler.swift
//  Yippy
//
//  Created by Matthew Davidson on 22/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import HotKey

class KeyActionHandler: Equatable, Hashable, CustomStringConvertible {
    
    var action: KeyAction
    var key: Key
    var modifiers: NSEvent.ModifierFlags
    var isExclusive: Bool
    var handler: () -> Void
    
    var description: String {
        return "KeyActionHandler[action='\(action)', key='\(key)', modifiers='\(modifiers)']"
    }
    
    init(action: KeyAction, key: Key, modifiers: NSEvent.ModifierFlags, isExclusive: Bool, handler: @escaping () -> Void) {
        self.action = action
        self.key = key
        self.modifiers = modifiers
        self.isExclusive = isExclusive
        self.handler = handler
    }
    
    static func == (lhs: KeyActionHandler, rhs: KeyActionHandler) -> Bool {
        return
            lhs.action == rhs.action &&
                lhs.key == rhs.key &&
                lhs.modifiers.isSubset(of: rhs.modifiers) &&
                rhs.modifiers.isSubset(of: lhs.modifiers)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(action)
        hasher.combine(key)
        hasher.combine(modifiers.rawValue)
    }
}

