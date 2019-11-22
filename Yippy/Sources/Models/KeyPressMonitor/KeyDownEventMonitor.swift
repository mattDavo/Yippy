//
//  KeyDownEventMonitor.swift
//  Yippy
//
//  Created by Matthew Davidson on 22/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class KeyDownEventMonitor: EventMonitor {
    
    init(handler: @escaping (NSEvent) -> Void) {
        super.init(eventTypeMask: .keyDown, handler: handler)
    }
}
