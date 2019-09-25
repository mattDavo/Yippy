//
//  PasteboardMonitorDelegate.swift
//  Yippy
//
//  Created by Matthew Davidson on 17/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

protocol PasteboardMonitorDelegate {
    
    func pasteboardDidChange(_ pasteboard: NSPasteboard)
}
