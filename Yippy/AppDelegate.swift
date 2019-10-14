//
//  AppDelegate.swift
//  Yippy
//
//  Created by Matthew Davidson on 26/7/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Cocoa
import HotKey
import RxSwift
import RxRelay
import RxCocoa

let deleteKeyEquivalent = NSString(format: "%c", NSDeleteCharacter) as String
let leftArrowKeyEquivalent = NSString(format: "%C", 0x001c) as String
let rightArrowKeyEquivalent = NSString(format: "%C", 0x001d) as String
let downArrowKeyEquivalent = NSString(format: "%C", 0x001f) as String
let upArrowKeyEquivalent = NSString(format: "%C", 0x001e) as String

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let disposeBag = DisposeBag()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        checkBuildFlags()
        checkLaunchArgs()
        loadState(fromSettings: Settings.main)
        
        showWelcomeIfNeeded()

        setupHotKey()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        checkTerminationArgs()
    }
    
    func checkLaunchArgs() {
        if CommandLine.arguments.contains("--uitesting") {
            // Mock the access control and key pressing
            Helper.accessControlHelper = AccessControlHelperMock()
            Helper.keyPressHelper = KeyPressHelperMock()
            
            // Remove the settings
            UITesting.oldUserDefaults = UserDefaults.standard.blank()
        }
        if let test = CommandLine.arguments.filter({$0.contains("--Settings.testData=")}).first {
            Settings.main = Settings.testData.from(test)
        }
    }
    
    func checkTerminationArgs() {
        if CommandLine.arguments.contains("--uitesting") {
            // Restore the settings
            UserDefaults.standard.restore(from: UITesting.oldUserDefaults)
        }
    }
    
    func checkBuildFlags() {
        #if BETA
        YippyHotKeys.toggle.hotKey = HotKey(key: .b, modifiers: NSEvent.ModifierFlags(arrayLiteral: .command, .shift))
        YippyStatusItem.statusItemButtonImage = NSImage(named: NSImage.Name("YippyBetaStatusBarIcon"))
        #endif
    }
    
    func showWelcomeIfNeeded() {
        // If the user has enabled access we don't need to do anything
        if Helper.isControlGranted(showPopup: false) {
            return
        }
        
        // Otherwise we should show a popup detailing why access is required.
        State.main.welcomeWindowController?.showWindow(nil)
    }
    
    func setupHotKey() {
        YippyHotKeys.toggle.onDown {
            self.togglePopover()
        }
    }
    
    func createMenu(withSettings settings: Settings) -> NSMenu {
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
            .with(menuItem: NSMenuItem(title: "Delete Selected", action: #selector(deleteSelectedClicked), keyEquivalent: deleteKeyEquivalent)
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
        
        State.main.panelPosition
            .subscribe(onNext: {
                [] in
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.left.rawValue)?.state = $0 == .left ? .on : .off
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.right.rawValue)?.state = $0 == .right ? .on : .off
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.top.rawValue)?.state = $0 == .top ? .on : .off
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.bottom.rawValue)?.state = $0 == .bottom ? .on : .off
            })
            .disposed(by: disposeBag)
        
        
        State.main.isHistoryPanelShown
            .subscribe(onNext: {
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.left.rawValue)?.keyEquivalent = $0 ? leftArrowKeyEquivalent : ""
                
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.right.rawValue)?.keyEquivalent = $0 ? rightArrowKeyEquivalent : ""
                
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.top.rawValue)?.keyEquivalent = $0 ? upArrowKeyEquivalent : ""
                
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.bottom.rawValue)?.keyEquivalent = $0 ? downArrowKeyEquivalent : ""
                
                menu.item(withTitle: "Delete Selected")?.isEnabled = $0
            })
            .disposed(by: disposeBag)
        
        return menu
    }
    
    func createYippyWindowController() -> YippyWindowController {
        let controller = YippyWindowController.createYippyWindowController()
        controller
            .subscribeTo(toggle: State.main.isHistoryPanelShown)
            .disposed(by: disposeBag)
        controller
            .subscribePositionTo(position: State.main.panelPosition)
            .disposed(by: disposeBag)
        return controller
    }
    
    func createPreviewWindowController() -> PreviewWindowController {
        let controller = PreviewWindowController.createPreviewWindowController()
        controller
            .subscribeTo(previewHistoryItem: State.main.previewHistoryItem)
            .disposed(by: disposeBag)
        return controller
    }
    
    func createQLPreviewController() -> QLPreviewController {
        let controller = QLPreviewController()
        controller
            .subscribeTo(previewHistoryItem: State.main.previewHistoryItem)
            .disposed(by: disposeBag)
        return controller
    }
    
    @objc func panelPositionSelected(_ sender: NSMenuItem) {
        if let position = PanelPosition(rawValue: sender.tag) {
            State.main.panelPosition.accept(position)
        }
        else {
            print("TODO: WARNING INVALID PANEL POSITION")
        }
    }

    @objc func togglePopover() {
        State.main.isHistoryPanelShown.accept(!State.main.isHistoryPanelShown.value)
    }
    
    @objc func deleteSelectedClicked() {
        YippyHotKeys.cmdDelete.simulateOnDown()
    }
    
    @objc func clearHistoryClicked() {
        State.main.history.accept([])
        State.main.selected.accept(nil)
    }
    
    func loadState(fromSettings settings: Settings) {
        // TODO: Should this be loaded?
//        State.main.isHistoryPanelShown.accept()
        // Load stored settings
        State.main.panelPosition.accept(settings.panelPosition)
        State.main.pasteboardChangeCount.accept(settings.pasteboardChangeCount)
        State.main.history.accept(settings.history)
        
        // Map settings to state
        settings.bindPanelPositionTo(state: State.main.panelPosition).disposed(by: disposeBag)
        settings.bindPasteboardChangeCountTo(state: State.main.pasteboardChangeCount).disposed(by: disposeBag)
        settings.bindHistoryTo(state: State.main.history).disposed(by: disposeBag)
        
        // Setup status item
        State.main.statusItem = YippyStatusItem.create()
        State.main.statusItem.menu = createMenu(withSettings: Settings.main)
        
        // Setup pasteboard monitor
        State.main.pasteboardMonitor = PasteboardMonitor(pasteboard: NSPasteboard.general, changeCount: Settings.main.pasteboardChangeCount, delegate: self)
        
        // Create yippy window controller
        State.main.yippyWindowController = createYippyWindowController()
        
        // Create preview window controller
        State.main.previewWindowController = createPreviewWindowController()
        State.main.previewController = createQLPreviewController()
    }
    
    @objc func showHelpWindow() {
        // If the window isn't visible, show it
        if !(State.main.helpWindowController?.window!.isVisible)! {
            State.main.helpWindowController?.showWindow(nil)
        }
        
        // Bring the window to front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showAboutWindow() {
        // If the window isn't visible, show it
        if !(State.main.aboutWindowController?.window!.isVisible)! {
            State.main.aboutWindowController?.showWindow(nil)
        }
        
        // Bring the window to front
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate: PasteboardMonitorDelegate {
    
    func pasteboardDidChange(_ pasteboard: NSPasteboard) {
//        guard let items = pasteboard.pasteboardItems else { return }
//        guard let item = items.first else { return } // TODO: handle multiple types and items
//        guard let str = item.string(forType: .string) else { return }
        // TODO: I think we can't handle tiff data until we store it differently
        
        // Only do anything if the pasteboard change includes having data
        if let types = pasteboard.types, !types.isEmpty {
            var historyItem = HistoryItem()
            for type in types {
                historyItem.data[type] = pasteboard.data(forType: type)
            }
            
            State.main.history.accept(State.main.history.value.with(element: historyItem, insertedAt: 0))
            State.main.pasteboardChangeCount.accept(pasteboard.changeCount)
            let selected = (State.main.selected.value ?? -1) + 1
            State.main.selected.accept(selected)
        }
    }
}
