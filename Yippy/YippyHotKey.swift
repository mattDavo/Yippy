//
//  YippyHotKey.swift
//  Yippy
//
//  Created by Matthew Davidson on 22/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import HotKey

class YippyHotKey {
    
    // MARK: - Types
    
    typealias Handler = () -> Void
    
    // MARK: - Public attributes
    
    var isPaused: Bool {
        didSet {
            hotKey.isPaused = isPaused
        }
    }
    
    var longPressStartingInterval: TimeInterval = 0.4
    var longPressMinInterval: TimeInterval = 0.1
    var longPressAcceleration: TimeInterval = 2
    
    // MARK: - Private attributes
    
    var hotKey: HotKey {
        didSet {
            self.isPaused = hotKey.isPaused
            self.hotKey.keyDownHandler = {
                // Handle key down observers
                for obv in self.keyDownObservers {
                    obv()
                }
                
                // Handle long press observers
                self.setLongPressTimer(withInterval: self.longPressStartingInterval)
            }
            
            self.hotKey.keyUpHandler = {
                // Handle key up observers
                for obv in self.keyUpObservers {
                    obv()
                }
                
                // Terminate long press observers
                self.stopLongPressTimer()
            }
        }
    }
    
    private var keyDownObservers = [Handler]()
    
    private var keyUpObservers = [Handler]()
    
    private var longPressObservers = [Handler]()
    
    private var longPressTimer: Timer?
    
    // MARK: - Constructors
    
    init(hotKey: HotKey) {
        self.hotKey = hotKey
        self.isPaused = hotKey.isPaused
        self.hotKey.keyDownHandler = {
            // Handle key down observers
            for obv in self.keyDownObservers {
                obv()
            }
            
            // Handle long press observers
            self.setLongPressTimer(withInterval: self.longPressStartingInterval)
        }
        
        self.hotKey.keyUpHandler = {
            // Handle key up observers
            for obv in self.keyUpObservers {
                obv()
            }
            
            // Terminate long press observers
            self.stopLongPressTimer()
        }
    }
    
    convenience init(key: Key, modifiers: NSEvent.ModifierFlags) {
        self.init(hotKey: HotKey(key: key, modifiers: modifiers))
    }
    
    // MARK: - Public Methods
    
    /**
     Adds a handler for when the HotKey triggers a key down event.
     
     - Parameter obv: Handler to call on every firing of a key down event.
     */
    func onDown(_ obv: @escaping Handler) {
        keyDownObservers.append(obv)
    }
    
    /**
     Adds a handler for when the HotKey triggers a key up event.
     
     - Parameter obv: Handler to call on every firing of a key up event.
     */
    func onUp(_ obv: @escaping Handler) {
        keyUpObservers.append(obv)
    }
    
    /**
     Adds a handler for long presses.
     
     Fires during  long presses. First after `longPressStartingInterval` seconds then the interval decreases, accelerating by `longPressAcceleration` until it reaches `longPressMinInterval`.
     
     - Parameter obv: Handler to call on every firing of a long press.
     */
    func onLong(_ obv: @escaping Handler) {
        longPressObservers.append(obv)
    }
    
    func simulateOnDown() {
        for obv in self.keyDownObservers {
            obv()
        }
    }
    
    // MARK: - Private Methods
    
    private func stopLongPressTimer() {
        if let timer = longPressTimer {
            timer.invalidate()
            self.longPressTimer = nil
        }
    }
    
    private func setLongPressTimer(withInterval interval: TimeInterval) {
        self.longPressTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false, block: { (t) in
            for obv in self.longPressObservers {
                obv()
            }
            
            let nextInterval = max(self.longPressMinInterval, interval/self.longPressAcceleration)
            self.setLongPressTimer(withInterval: nextInterval)
        })
    }
}
