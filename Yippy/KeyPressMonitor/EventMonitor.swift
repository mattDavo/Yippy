//
//  EventMonitor.swift
//  Yippy
//
//  Created by Matthew Davidson on 22/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class EventMonitor {
    
    private var monitor: Any?
    
    var eventTypeMask: NSEvent.EventTypeMask
    var handler: (NSEvent) -> Void
    
    var isActive: Bool {
        didSet {
            if isActive {
                start()
            }
            else {
                stop()
            }
        }
    }
    
    init(eventTypeMask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        self.eventTypeMask = eventTypeMask
        self.handler = handler
        
        self.isActive = true
        start()
    }
    
    private func onEvent(_ event: NSEvent) -> NSEvent? {
        handler(event)
        return nil
    }
    
    deinit {
        stop()
    }
    
    func start() {
        if monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: eventTypeMask, handler: onEvent)
        }
    }
    
    func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }
}
