//
//  Controller.swift
//  Yippy
//
//  Created by Matthew Davidson on 26/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import RxSwift
import RxRelay
import LoginServiceKit

class Controller {
    
    // MARK: - Singleton
    
    static var main: Controller!
    
    
    // MARK: - Attributes
    
    var state: State
    
    /// Must exist for the duration of the application so that the status bar does not disappear.
    var statusItem: NSStatusItem!
    
    // Window Controllers
    var yippyWindowController: YippyWindowController!
    var previewWindowController: PreviewWindowController!
    
    lazy var welcomeWindowController: WelcomeWindowController = {
        return WelcomeWindowController.createWelcomeWindowController()
    }()
    
    lazy var helpWindowController: HelpWindowController = {
        return HelpWindowController.createHelpWindowController()
    }()
    
    lazy var aboutWindowController: AboutWindowController = {
        return AboutWindowController.createAboutWindowController()
    }()
    
    lazy var settingsWindowController: SettingsWindowController = {
        return SettingsWindowController.createSettingsWindowController()
    }()
    
    
    // MARK: - Constructor
    
    init(state: State, settings: Settings) {
        self.state = state
        // Setup status item
        self.statusItem = YippyStatusItem.create()
        self.statusItem.menu = Self.createMenu(settings: settings, state: state, target: self)
        
        // Create yippy window controller
        self.yippyWindowController = Self.createYippyWindowController(state: state, disposeBag: state.disposeBag)
       
        // Create preview window controllers
        self.previewWindowController = Self.createPreviewWindowController(previewItem: state.previewHistoryItem, disposeBag: state.disposeBag)
    }
    
    
    // MARK: - Constructor Helpers
    
    static func createMenu(settings: Settings, state: State, target: AnyObject?) -> NSMenu {
        let menu = NSMenu()
            .with(menuItem: NSMenuItem(title: "About Yippy", action: #selector(showAboutWindow), keyEquivalent: "")
                .with(accessibilityIdentifier: Accessibility.identifiers.aboutButton)
            )
            .with(menuItem: NSMenuItem(title: "Yippy Help", action: #selector(showHelpWindow), keyEquivalent: "")
                .with(accessibilityIdentifier: Accessibility.identifiers.helpButton)
            )
            .with(menuItem: NSMenuItem.separator())
            .with(menuItem: NSMenuItem(title: "Preferences...", action: #selector(showSettings), keyEquivalent: "")
                .with(accessibilityIdentifier: "")
            )
            .with(menuItem: NSMenuItem.separator())
            .with(menuItem: NSMenuItem(title: "Toggle Window", action: #selector(togglePopover), keyEquivalent: "V")
                .with(accessibilityIdentifier: Accessibility.identifiers.toggleYippyWindowButton)
            )
            .with(menuItem: NSMenuItem(title: "Launch at Login", action: #selector(launchAtLogin), keyEquivalent: "")
                .with(accessibilityIdentifier: Accessibility.identifiers.launchAtLoginButton)
            )
            .with(menuItem: NSMenuItem(title: "Delete Selected", action: #selector(deleteSelectedClicked), keyEquivalent: Constants.statusItemMenu.deleteKeyEquivalent)
                .with(state: .off)
            )
            .with(menuItem: NSMenuItem(title: "Clear history", action: #selector(clearHistoryClicked), keyEquivalent: ""))
            .with(menuItem: NSMenuItem(title: "Position", action: nil, keyEquivalent: "")
                .with(accessibilityIdentifier: Accessibility.identifiers.positionButton)
                .with(submenu: createWindowPositionSubmenu(settings: settings))
            )
            .with(menuItem: NSMenuItem.separator())
            .with(menuItem: NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "")
                .with(accessibilityIdentifier: Accessibility.identifiers.quitButton)
        )
        menu.autoenablesItems = false
        
        Self.setMenuItemsTarget(target: target, menu: menu)
        
        state.launchAtLogin
            .subscribe (onNext: {
                menu.item(withTitle: "Launch at Login")?.state = $0 ? .on : .off
            })
            .disposed(by: state.disposeBag)
        
        state.panelPosition
            .subscribe(onNext: { next in
                PanelPosition.allCases.forEach { pos in
                    menu.item(withTitle: "Position")?.submenu?.item(withTag: pos.rawValue)?.state = next == pos ? .on : .off
                }
            })
            .disposed(by: state.disposeBag)
        
        
        state.isHistoryPanelShown
            .subscribe(onNext: {
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.left.rawValue)?.keyEquivalent = $0 ? Constants.statusItemMenu.leftArrowKeyEquivalent : ""
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.left.rawValue)?.keyEquivalentModifierMask = NSEvent.ModifierFlags(arrayLiteral: .control, .option, .command)
                
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.right.rawValue)?.keyEquivalent = $0 ? Constants.statusItemMenu.rightArrowKeyEquivalent : ""
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.right.rawValue)?.keyEquivalentModifierMask = NSEvent.ModifierFlags(arrayLiteral: .control, .option, .command)
                
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.top.rawValue)?.keyEquivalent = $0 ? Constants.statusItemMenu.upArrowKeyEquivalent : ""
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.top.rawValue)?.keyEquivalentModifierMask = NSEvent.ModifierFlags(arrayLiteral: .control, .option, .command)
                
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.bottom.rawValue)?.keyEquivalent = $0 ? Constants.statusItemMenu.downArrowKeyEquivalent : ""
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.bottom.rawValue)?.keyEquivalentModifierMask = NSEvent.ModifierFlags(arrayLiteral: .control, .option, .command)
                
                menu.item(withTitle: "Delete Selected")?.isEnabled = $0
                menu.item(withTitle: "Delete Selected")?.keyEquivalentModifierMask = .control
            })
            .disposed(by: state.disposeBag)
        
        return menu
    }
    
    static func createWindowPositionSubmenu(settings: Settings) -> NSMenu {
        let menu = NSMenu(title: "")
        menu.items = PanelPosition.allCases.map({pos in
            return NSMenuItem(title: pos.title, action: #selector(panelPositionSelected(_:)), keyEquivalent: "")
                .with(accessibilityIdentifier: pos.identifier)
                .with(state: settings.panelPosition == pos ? .on : .off)
                .with(tag: pos.rawValue)
        })
        return menu
    }
    
    static func setMenuItemsTarget(target: AnyObject?, menu: NSMenu) {
        for item in menu.items {
            item.target = target
            if let subMenu = item.submenu {
                setMenuItemsTarget(target: target, menu: subMenu)
            }
        }
    }
    
    static func createYippyWindowController(state: State, disposeBag: DisposeBag) -> YippyWindowController {
        let controller = YippyWindowController.createYippyWindowController()
        controller
            .subscribeTo(toggle: state.isHistoryPanelShown)
            .disposed(by: disposeBag)
        controller
            .subscribeFrameTo(position: state.panelPosition.asObservable(), screen: state.currentScreen.asObservable())
            .disposed(by: disposeBag)
        return controller
    }
    
    static func createPreviewWindowController(previewItem: BehaviorRelay<HistoryItem?>, disposeBag: DisposeBag) -> PreviewWindowController {
        let controller = PreviewWindowController.create()
        controller
            .subscribeTo(previewItem: previewItem)
            .disposed(by: disposeBag)
        return controller
    }
    
    
    // MARK: - Methods
    @objc func panelPositionSelected(_ sender: NSMenuItem) {
        if let position = PanelPosition(rawValue: sender.tag) {
            state.panelPosition.accept(position)
        }
        else {
            YippyError(localizedDescription: "Received invalid panel position from \(sender)").log(with: ErrorLogger.general)
        }
    }

    @objc func togglePopover() {
        state.isHistoryPanelShown.accept(!state.isHistoryPanelShown.value)
    }
    
    @objc func deleteSelectedClicked() {
        YippyHotKeys.ctrlDelete.simulateOnDown()
    }
    
    @objc func clearHistoryClicked() {
        state.history.clear()
    }
    
    @objc func showHelpWindow() {
        // If the window isn't visible, show it
        if !self.helpWindowController.window!.isVisible {
            self.helpWindowController.showWindow(nil)
            self.helpWindowController.window?.center()
        }
        
        // Bring the window to front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showAboutWindow() {
        // If the window isn't visible, show it
        if !self.aboutWindowController.window!.isVisible {
            self.aboutWindowController.showWindow(nil)
            self.aboutWindowController.window?.center()
        }
        
        // Bring the window to front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showSettings() {
        // If the window isn't visible, show it
        if !self.settingsWindowController.window!.isVisible {
            self.settingsWindowController.showWindow(nil)
            self.settingsWindowController.window?.center()
        }
        
        // Bring the window to front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(self)
    }
    
    @objc func launchAtLogin() {
        let launchAtLogin = !state.launchAtLogin.value
        state.launchAtLogin.accept(launchAtLogin)
        if launchAtLogin {
            LoginServiceKit.addLoginItems()
        }
        else {
            LoginServiceKit.removeLoginItems()
        }
    }
}
