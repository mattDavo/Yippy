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
    
    /**
     Called when the pasteboard changes.
     
     - Parameter pasteboard: The pasteboard that changed.
     */
    func pasteboardDidChange(_ pasteboard: NSPasteboard, originBundleId: String?)
}
