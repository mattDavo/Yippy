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

class Controller {
    
    // MARK: - Singleton
    
    static var main: Controller!
    
    
    // MARK: - Attributes
    
    var state: State
    
    /// Must exist for the duration of the application so that the status bar does not disappear.
    var statusItem: NSStatusItem!
    
    // Window Controllers
    var yippyWindowController: YippyWindowController!
    var previewTextWindowController: PreviewTextWindowController!
    var previewTiffWindowController: PreviewTiffWindowController!
    var previewController: QLPreviewController!
    
    lazy var welcomeWindowController: WelcomeWindowController = {
        return WelcomeWindowController.createWelcomeWindowController()
    }()
    
    lazy var helpWindowController: HelpWindowController = {
        return HelpWindowController.createHelpWindowController()
    }()
    
    lazy var aboutWindowController: AboutWindowController = {
        return AboutWindowController.createAboutWindowController()
    }()
    
    
    // MARK: - Constructor
    
    init(state: State, settings: Settings) {
        self.state = state
        // Setup status item
        self.statusItem = YippyStatusItem.create()
        self.statusItem.menu = Self.createMenu(settings: settings, state: state, target: self)
        
        // Create yippy window controller
        self.yippyWindowController = Self.createYippyWindowController(isHistoryPanelShown: state.isHistoryPanelShown, panelPosition: state.panelPosition, disposeBag: state.disposeBag)
       
       // Create preview window controllers
       self.previewTextWindowController = Self.createPreviewTextWindowController(previewHistoryItem: state.previewHistoryItem, disposeBag: state.disposeBag)
        self.previewTiffWindowController = Self.createPreviewTiffWindowController(previewHistoryItem: state.previewHistoryItem, disposeBag: state.disposeBag)
       self.previewController = Self.createQLPreviewController(previewHistoryItem: state.previewHistoryItem, disposeBag: state.disposeBag)
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
            .with(menuItem: NSMenuItem(title: "Toggle Window", action: #selector(togglePopover), keyEquivalent: "V")
                .with(accessibilityIdentifier: Accessibility.identifiers.toggleYippyWindowButton)
            )
            .with(menuItem: NSMenuItem(title: "Delete Selected", action: #selector(deleteSelectedClicked), keyEquivalent: Constants.statusItemMenu.deleteKeyEquivalent)
                .with(state: .off)
            )
            .with(menuItem: NSMenuItem(title: "Clear history", action: #selector(clearHistoryClicked), keyEquivalent: ""))
            .with(menuItem: NSMenuItem(title: "Position", action: nil, keyEquivalent: "")
                .with(accessibilityIdentifier: Accessibility.identifiers.positionButton)
                .with(submenu: NSMenu(title: "")
                    .with(menuItem: NSMenuItem(title: "Left", action: #selector(panelPositionSelected(_:)), keyEquivalent: "")
                        .with(accessibilityIdentifier: Accessibility.identifiers.positionLeftButton)
                        .with(state: settings.panelPosition == .left ? .on : .off)
                        .with(tag: PanelPosition.left.rawValue)
                    )
                    .with(menuItem: NSMenuItem(title: "Right", action: #selector(panelPositionSelected(_:)), keyEquivalent: "")
                        .with(accessibilityIdentifier: Accessibility.identifiers.positionRightButton)
                        .with(state: settings.panelPosition == .right ? .on : .off)
                        .with(tag: PanelPosition.right.rawValue)
                    )
                    .with(menuItem: NSMenuItem(title: "Top", action: #selector(panelPositionSelected(_:)), keyEquivalent: "")
                        .with(accessibilityIdentifier: Accessibility.identifiers.positionTopButton)
                        .with(state: settings.panelPosition == .top ? .on : .off)
                        .with(tag: PanelPosition.top.rawValue)
                    )
                    .with(menuItem: NSMenuItem(title: "Bottom", action: #selector(panelPositionSelected(_:)), keyEquivalent: "")
                        .with(accessibilityIdentifier: Accessibility.identifiers.positionBottomButton)
                        .with(state: settings.panelPosition == .bottom ? .on : .off)
                        .with(tag: PanelPosition.bottom.rawValue)
                    )
            ))
            .with(menuItem: NSMenuItem.separator())
            .with(menuItem: NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
                .with(accessibilityIdentifier: Accessibility.identifiers.quitButton)
        )
        menu.autoenablesItems = false
        
        Self.setMenuItemsTarget(target: target, menu: menu)
        
        state.panelPosition
            .subscribe(onNext: {
                [] in
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.left.rawValue)?.state = $0 == .left ? .on : .off
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.right.rawValue)?.state = $0 == .right ? .on : .off
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.top.rawValue)?.state = $0 == .top ? .on : .off
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.bottom.rawValue)?.state = $0 == .bottom ? .on : .off
            })
            .disposed(by: state.disposeBag)
        
        
        state.isHistoryPanelShown
            .subscribe(onNext: {
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.left.rawValue)?.keyEquivalent = $0 ? Constants.statusItemMenu.leftArrowKeyEquivalent : ""
                
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.right.rawValue)?.keyEquivalent = $0 ? Constants.statusItemMenu.rightArrowKeyEquivalent : ""
                
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.top.rawValue)?.keyEquivalent = $0 ? Constants.statusItemMenu.upArrowKeyEquivalent : ""
                
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.bottom.rawValue)?.keyEquivalent = $0 ? Constants.statusItemMenu.downArrowKeyEquivalent : ""
                
                menu.item(withTitle: "Delete Selected")?.isEnabled = $0
            })
            .disposed(by: state.disposeBag)
        
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
    
    static func createYippyWindowController(isHistoryPanelShown: BehaviorRelay<Bool>, panelPosition: BehaviorRelay<PanelPosition>, disposeBag: DisposeBag) -> YippyWindowController {
        let controller = YippyWindowController.createYippyWindowController()
        controller
            .subscribeTo(toggle: isHistoryPanelShown)
            .disposed(by: disposeBag)
        controller
            .subscribePositionTo(position: panelPosition)
            .disposed(by: disposeBag)
        return controller
    }
    
    static func createPreviewTextWindowController(previewHistoryItem: BehaviorRelay<HistoryItem?>, disposeBag: DisposeBag) -> PreviewTextWindowController {
        let controller = PreviewTextWindowController.createPreviewTextWindowController()
        controller
            .subscribeTo(previewHistoryItem: previewHistoryItem)
            .disposed(by: disposeBag)
        return controller
    }
    
    static func createPreviewTiffWindowController(previewHistoryItem: BehaviorRelay<HistoryItem?>, disposeBag: DisposeBag) -> PreviewTiffWindowController {
        let controller = PreviewTiffWindowController.createPreviewTiffWindowController()
        controller
            .subscribeTo(previewHistoryItem: previewHistoryItem)
            .disposed(by: disposeBag)
        return controller
    }
    
    static func createQLPreviewController(previewHistoryItem: BehaviorRelay<HistoryItem?>, disposeBag: DisposeBag) -> QLPreviewController {
        let controller = QLPreviewController()
        controller
            .subscribeTo(previewHistoryItem: previewHistoryItem)
            .disposed(by: disposeBag)
        return controller
    }
    
    
    // MARK: - Methods
    @objc func panelPositionSelected(_ sender: NSMenuItem) {
        if let position = PanelPosition(rawValue: sender.tag) {
            state.panelPosition.accept(position)
        }
        else {
            print("TODO: WARNING INVALID PANEL POSITION")
        }
    }

    @objc func togglePopover() {
        state.isHistoryPanelShown.accept(!state.isHistoryPanelShown.value)
    }
    
    @objc func deleteSelectedClicked() {
        YippyHotKeys.cmdDelete.simulateOnDown()
    }
    
    @objc func clearHistoryClicked() {
        state.history.setSelected(nil)
        state.history.clear()
    }
    
    @objc func showHelpWindow() {
        // If the window isn't visible, show it
        if !self.helpWindowController.window!.isVisible {
            self.helpWindowController.showWindow(nil)
        }
        
        // Bring the window to front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showAboutWindow() {
        // If the window isn't visible, show it
        if !self.aboutWindowController.window!.isVisible {
            self.aboutWindowController.showWindow(nil)
        }
        
        // Bring the window to front
        NSApp.activate(ignoringOtherApps: true)
    }
}
