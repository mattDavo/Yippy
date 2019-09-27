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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let disposeBag = DisposeBag()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        loadState(fromSettings: Settings.main)
        
        showWelcomeIfNeeded()

        setupHotKey()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
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
            State.main.isHistoryPanelShown.accept(!State.main.isHistoryPanelShown.value)
        }
    }
    
    func createStatusItem() -> NSStatusItem {
        let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name("YippyStatusBarIcon"))
        }
        
        return statusItem
    }
    
    func createMenu(withSettings settings: Settings) -> NSMenu {
        let menu = NSMenu()
            .with(menuItem: NSMenuItem(title: "About Yippy", action: #selector(showAboutWindow), keyEquivalent: ""))
            .with(menuItem: NSMenuItem(title: "Yippy Help", action: #selector(showHelpWindow), keyEquivalent: ""))
            .with(menuItem: NSMenuItem.separator())
            .with(menuItem: NSMenuItem(title: "Toggle Window", action: #selector(togglePopover), keyEquivalent: "V"))
            .with(menuItem: NSMenuItem(title: "TODO: Clear history", action: nil, keyEquivalent: ""))
            .with(menuItem: NSMenuItem(title: "Position", action: nil, keyEquivalent: "")
                .with(submenu: NSMenu(title: "")
                    .with(menuItem: NSMenuItem(title: "Left", action: #selector(panelPositionSelected(_:)), keyEquivalent: "")
                        .with(state: settings.panelPosition == .left ? .on : .off)
                        .with(tag: PanelPosition.left.rawValue)
                    )
                    .with(menuItem: NSMenuItem(title: "Right", action: #selector(panelPositionSelected(_:)), keyEquivalent: "")
                        .with(state: settings.panelPosition == .right ? .on : .off)
                        .with(tag: PanelPosition.right.rawValue)
                    )
                    .with(menuItem: NSMenuItem(title: "Top", action: #selector(panelPositionSelected(_:)), keyEquivalent: "")
                        .with(state: settings.panelPosition == .top ? .on : .off)
                        .with(tag: PanelPosition.top.rawValue)
                    )
                    .with(menuItem: NSMenuItem(title: "Bottom", action: #selector(panelPositionSelected(_:)), keyEquivalent: "")
                        .with(state: settings.panelPosition == .bottom ? .on : .off)
                        .with(tag: PanelPosition.bottom.rawValue)
                    )
            ))
            .with(menuItem: NSMenuItem.separator())
            .with(menuItem: NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        
        State.main.panelPosition
            .subscribe(onNext: {
                [] in
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.left.rawValue)?.state = $0 == .left ? .on : .off
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.right.rawValue)?.state = $0 == .right ? .on : .off
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.top.rawValue)?.state = $0 == .top ? .on : .off
                menu.item(withTitle: "Position")?.submenu?.item(withTag: PanelPosition.bottom.rawValue)?.state = $0 == .bottom ? .on : .off
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
        State.main.statusItem = createStatusItem()
        State.main.statusItem.menu = createMenu(withSettings: Settings.main)
        
        // Setup pasteboard monitor
        State.main.pasteboardMonitor = PasteboardMonitor(pasteboard: NSPasteboard.general, changeCount: Settings.main.pasteboardChangeCount, delegate: self)
        
        // Create yippy window controller
        State.main.yippyWindowController = createYippyWindowController()
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
        guard let items = pasteboard.pasteboardItems else { return }
        guard let item = items.first else { return } // TODO: handle multiple types and items
        guard let str = item.string(forType: .string) else { return }
        
        State.main.history.accept(State.main.history.value.with(element: str, insertedAt: 0))
        State.main.pasteboardChangeCount.accept(pasteboard.changeCount)
    }
}
