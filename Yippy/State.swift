//
//  State.swift
//  Yippy
//
//  Created by Matthew Davidson on 7/8/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import RxRelay

struct State {
    
    // MARK: - Singleton
    static var main = State()
    
    // Enforce singleton
    private init() {}
    
    
    // MARK: - RxSwift
    var isHistoryPanelShown = BehaviorRelay<Bool>(value: false)
    
    var panelPosition = BehaviorRelay<PanelPosition>(value: .right)
    
    var pasteboardChangeCount = BehaviorRelay<Int>(value: -1)
    
    var history = BehaviorRelay<[String]>(value: [])
    
    
    // MARK: - Status Item
    // Must exist for the duration of the application so that the status bar does not disappear.
    var statusItem: NSStatusItem!
    
    
    // MARK: - Pasteboard Monitor
    // Monitors the pasteboard, here it can be controlled in the future if needed.
    var pasteboardMonitor: PasteboardMonitor!
    
    
    // MARK: - Window Controllers
    
    // Private NSWindowControllers
    private var _welcomeWC: WelcomeWindowController? = nil
    private var _helpWC: HelpWindowController? = nil
    private var _aboutWC: AboutWindowController? = nil
    
    // Public NSWindowControllers
    var yippyWindowController: YippyWindowController!
    
    var welcomeWindowController: WelcomeWindowController? {
        mutating get {
            if let welcomeWC = _welcomeWC {
                return welcomeWC
            }
            _welcomeWC = WelcomeWindowController.createWelcomeWindowController()
            return _welcomeWC
        }
        set (welcomeVC) {
            self._welcomeWC = welcomeVC
        }
    }
    
    var helpWindowController: HelpWindowController? {
        mutating get {
            if let helpWC = _helpWC {
                return helpWC
            }
            _helpWC = HelpWindowController.createHelpWindowController()
            return _helpWC
        }
        set (helpVC) {
            self._helpWC = helpVC
        }
    }
    
    var aboutWindowController: AboutWindowController? {
        mutating get {
            if let aboutWC = _aboutWC {
                return aboutWC
            }
            _aboutWC = AboutWindowController.createAboutWindowController()
            return _aboutWC
        }
        set (aboutWC) {
            self._aboutWC = aboutWC
        }
    }
}
