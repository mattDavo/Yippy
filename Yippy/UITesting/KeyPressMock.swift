//
//  KeyPressMock.swift
//  Yippy
//
//  Created by Matthew Davidson on 30/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import HotKey

struct KeyPressMock {
    
    static let pasteboard = NSPasteboard(name: NSPasteboard.Name(rawValue: "Yippy.UITesting.KeyPress"))
    
    static func keyPress(keyCode: CGKeyCode, flags: CGEventFlags) {
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString("\(keyCode)|\(flags.rawValue)", forType: .string)
    }
    
    /**
     Mock for handling a key press.
     
     This method will only return the key press string posted to the pasteboard once. Every other time it will return nil.
     
     - Returns: If a key press has not been handled, it returns the keyCode and flags. Otherwise nil is returned.
     */
    static func handleKeyPress() -> (CGKeyCode, CGEventFlags)? {
        if let str = pasteboard.string(forType: .string) {
            pasteboard.clearContents()
            let vals = str.split(separator: "|")
            if vals.count != 2 {
                return nil
            }
            let k = Int(vals[0])!
            let f = Int(vals[1])!
            let keyCode = CGKeyCode(k)
            let flags = CGEventFlags(rawValue: UInt64(f))
            
            return (keyCode, flags)
        }
        return nil
    }
}
