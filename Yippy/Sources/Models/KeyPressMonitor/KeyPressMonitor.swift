//
//  KeyPressMonitor.swift
//  Yippy
//
//  Created by Matthew Davidson on 22/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import HotKey

class KeyPressMonitor {
    
    var keyUpMonitor: EventMonitor!
    var keyDownMonitor: EventMonitor!
    var specialKeyMonitor: SpecialKeyChangedEventMonitor!
    
    var allowedModifierFlags: NSEvent.ModifierFlags
    
    var keysDown = Set<Key>()
    var modifiers: NSEvent.ModifierFlags = .init()
    
    var keyActionHandlers = Set<KeyActionHandler>()
    
    typealias KeyDownHandler = ([Key], NSEvent.ModifierFlags) -> Void
    
    var keyDownHandlers = [KeyDownHandler]()
    
    init(allowedModifierFlags: NSEvent.ModifierFlags = NSEvent.ModifierFlags.recommended) {
        self.allowedModifierFlags = allowedModifierFlags
        self.keyUpMonitor = KeyUpEventMonitor(handler: onKeyUp)
        self.keyDownMonitor = KeyDownEventMonitor(handler: onKeyDown)
        self.specialKeyMonitor = SpecialKeyChangedEventMonitor(handler: onSpecialKeyChange)
    }
    
    func handleAction(_ action: KeyAction, forKey key: Key, withModifiers modifiers: NSEvent.ModifierFlags, isExclusive: Bool = false, handler: @escaping () -> Void) {
        // TODO
        if !modifiers.isSubset(of: allowedModifierFlags) {
            print("Warning: Action handler [action=\(action), key='\(key)'] contains not allowed modifier flags. They will be automatically removed.")
        }
        
        let keyActionHandler = KeyActionHandler(action: action, key: key, modifiers: modifiers.intersection(allowedModifierFlags), isExclusive: isExclusive, handler: handler)
        
        if keyActionHandlers.remove(keyActionHandler) != nil {
            print("Already contained a handler for that key action. Removed and replaced")
        }
        keyActionHandlers.insert(keyActionHandler)
    }
    
    func subscribeToKeyDown(_ handler: @escaping KeyDownHandler) {
        keyDownHandlers.append(handler)
    }
    
    private func checkKeyUpHandlers(forKey key: Key) {
        if let handler = keyActionHandlers.filter({ $0.key == key && $0.action == .up && $0.modifiers.equals(modifiers) }).first {
            handler.handler()
        }
    }
    
    private func checkKeyDownHandlers(forKey key: Key) {
        if let handler = keyActionHandlers.filter({ $0.key == key && $0.action == .down && $0.modifiers.equals(modifiers) }).first {
            handler.handler()
        }
    }
    
    private func checkHandlers(forKey key: Key, withAction action: KeyAction) {
        // Key Up
        if action == .up {
            checkKeyUpHandlers(forKey: key)
        }
        
        // Key down
        if action == .down {
            checkKeyDownHandlers(forKey: key)
        }
    }
    
    private func keyUp(_ key: Key) {
        print("Key '\(key)' up")
        if keysDown.remove(key) != nil {
            print("Key '\(key)' removed from down set")
        }
        else {
            print("Key '\(key)' not found in down set")
        }
        checkHandlers(forKey: key, withAction: .up)
    }
    
    private func keyDown(_ key: Key) {
        print("Key '\(key)' down")
        keysDown.insert(key)
        print("Key '\(key)' added to down set")
        checkHandlers(forKey: key, withAction: .down)
        keyDownHandlers.forEach { $0(self.keysDown.map{$0}, self.modifiers) }
    }
    
    private func onSpecialKeyChange(_ event: NSEvent) {
        // TODO
        /*
         if let key = Key(carbonKeyCode: UInt32(event.keyCode)) {
         let modifier = NSEvent.ModifierFlags(carbonFlags: UInt32(event.keyCode))
         
         //            NSEvent.ModifierFlags.init(rawValue: 0).
         if !event.modifierFlags.contains(modifier) {
         print("\(modifier) up")
         } else {
         print("\(modifier) down")
         }
         }
         */
    }
    
    private func onKeyUp(_ event: NSEvent) {
        modifiers = event.modifierFlags.intersection(allowedModifierFlags)
        if let key = Key(carbonKeyCode: UInt32(event.keyCode)) {
            keyUp(key)
        }
        else {
            print("Could not create Key enum with keyCode: \(event.keyCode)")
        }
    }
    
    private func onKeyDown(_ event: NSEvent) {
        modifiers = event.modifierFlags.intersection(allowedModifierFlags)
        if let key = Key(carbonKeyCode: UInt32(event.keyCode)) {
            keyDown(key)
        }
        else {
            print("Could not create Key enum with keyCode: \(event.keyCode)")
        }
    }
}
