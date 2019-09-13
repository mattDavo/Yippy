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

var selected = 0

var pasteEventMonitor: EventMonitor!

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var statusItem: NSStatusItem!
    
    var window: NSWindow!
    
    private var toggleHotKey: HotKey!
    
    var timer: Timer!
    let pasteboard: NSPasteboard = .general
    var lastChangeCount: Int = 0
    
    var historyPanelController: HistoryPanelController!
    
    let disposeBag = DisposeBag()
    
    var welcomeWindow: NSWindow?
    var helpWindowController: NSWindowController?
    var aboutWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        welcomeWindow = getWelcomeWindow()
        loadSettings()
        loadState(fromSettings: Settings.main)
        
        statusItem = createStatusItem()
        statusItem.menu = createMenu(withSettings: Settings.main)
        
        toggleHotKey = HotKey(keyCombo: KeyCombo(key: .v, modifiers: [.command, .shift]))
        toggleHotKey.keyDownHandler = { [] in
            State.main.isHistoryPanelShown.accept(!State.main.isHistoryPanelShown.value)
        }
        
        pasteEventMonitor = EventMonitor(mask: [.keyDown]) { [] event in
            pasteEventMonitor.stop()
            State.main.isPasteboardPaused.accept(false)
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { (t) in
            if !State.main.isPasteboardPaused.value && self.lastChangeCount != self.pasteboard.changeCount  {
                self.lastChangeCount = self.pasteboard.changeCount
                NotificationCenter.default.post(name: .NSPasteboardDidChange, object: self.pasteboard)
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(onPasteboardChanged), name: .NSPasteboardDidChange, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification, object: nil)
        
        historyPanelController = createHistoryPanelController()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
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
    
    func createHistoryPanelController() -> HistoryPanelController {
        let historyPanelController = HistoryPanelController()
        historyPanelController
            .subscribeTo(toggle: State.main.isHistoryPanelShown)
            .disposed(by: disposeBag)
        historyPanelController
            .subscribePositionTo(position: State.main.panelPosition)
            .disposed(by: disposeBag)
        return historyPanelController
    }
    
    @objc func panelPositionSelected(_ sender: NSMenuItem) {
        if let position = PanelPosition(rawValue: sender.tag) {
            Settings.main.panelPosition = position
            State.main.panelPosition.accept(position)
        }
        else {
            print("TODO: WARNING")
        }
    }
    
    @objc func onPasteboardChanged(_ notification: Notification) {
        guard let pb = notification.object as? NSPasteboard else { return }
        guard let items = pb.pasteboardItems else { return }
        guard let item = items.first else { return } // TODO: handle multiple types and items
        guard let str = item.string(forType: .string) else { return }
        
        if State.main.history.count == 0 || str != State.main.history[0] {
            State.main.history.insert(str, at: 0)
        }
        UserDefaults.standard.set(State.main.history, forKey: "history")
        
    }

    @objc func togglePopover() {
        State.main.isHistoryPanelShown.accept(!State.main.isHistoryPanelShown.value)
    }
    
    func loadState(fromSettings settings: Settings) {
        // TODO: Should these be loaded?
//        State.main.isHistoryPanelShown.accept()
//        State.main.isPasteboardPaused.accept()
        State.main.panelPosition.accept(settings.panelPosition)
        
        if let h = UserDefaults.standard.stringArray(forKey: "history") {
            State.main.history = h
        }
    }
    
    func loadSettings() {
        if Settings.main == nil {
            Settings.main = Settings()
        }
    }
    
    @objc func windowWillClose(_ notification: Notification) {
        if (welcomeWindow != nil) && notification.object is NSWindow && (notification.object as! NSWindow) == welcomeWindow {
            if State.main.allowAccessTapped {
                showHelpWindow()
            }
            else {
                NSApplication.shared.terminate(self)
            }
        }
    }
    
    @objc func showHelpWindow() {
        // Create the help window controller if it hasn't been created yet
        if helpWindowController == nil {
            helpWindowController = HelpWindowController.createHelpWindowController()
        }
        
        // If the window isn't visible, show it
        if !(helpWindowController?.window!.isVisible)! {
            helpWindowController!.showWindow(nil)
        }
        
        // Bring the window to front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showAboutWindow() {
        // Create the help window controller if it hasn't been created yet
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController.createAboutWindowController()
        }
        
        // If the window isn't visible, show it
        if !(aboutWindowController?.window!.isVisible)! {
            aboutWindowController!.showWindow(nil)
        }
        
        // Bring the window to front
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension NSNotification.Name {
    public static let NSPasteboardDidChange: NSNotification.Name = .init(rawValue: "pasteboardDidChangeNotification")
}


func send(_ keyCode: CGKeyCode, useCommandFlag: Bool) {
    let sourceRef = CGEventSource(stateID: .combinedSessionState)
    
    if sourceRef == nil {
        NSLog("FakeKey: No event source")
        return
    }
    
    let keyDownEvent = CGEvent(keyboardEventSource: sourceRef,
                               virtualKey: keyCode,
                               keyDown: true)
    if useCommandFlag {
        keyDownEvent?.flags = .maskCommand
    }
    
    let keyUpEvent = CGEvent(keyboardEventSource: sourceRef,
                             virtualKey: keyCode,
                             keyDown: false)
    
    keyDownEvent?.post(tap: .cghidEventTap)
    keyUpEvent?.post(tap: .cghidEventTap)
}

func bindHotKeyToToggle(hotKey: HotKey, disposeBag: DisposeBag) {
    State.main.isHistoryPanelShown
        .distinctUntilChanged()
        .subscribe(onNext: { [] in
            hotKey.isPaused = !$0
        })
        .disposed(by: disposeBag)
}

func getWelcomeWindow() -> NSWindow? {
    // If the user has enabled access we don't need to do anything
    if isAccessEnabled(showPopup: false) {
        return nil
    }
    
    // Otherwise we should show a popup detailing why access is required.
    let windowController = WelcomeWindowController.createWelcomeWindowController()
    windowController.showWindow(nil)
    
    return windowController.window
}

// https://stackoverflow.com/questions/40144259/modify-accessibility-settings-on-macos-with-swift
func isAccessEnabled(showPopup: Bool) -> Bool {
    // get the value for accesibility
    let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
    // set the options: false means it wont ask
    // true means it will popup and ask
    let options = [checkOptPrompt: showPopup]
    // translate into boolean value
    let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary?)
    return accessEnabled
}
