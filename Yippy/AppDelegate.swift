//
//  AppDelegate.swift
//  Yippy
//
//  Created by Matthew Davidson on 26/7/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Cocoa
import HotKey

var history = [String]()

var downHotKey: HotKey!
var upHotKey: HotKey!
var downLongHotKey: LongHotKey!

var selected = 0

let maxHeight: CGFloat = 200

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    
    var window: NSWindow!
    
    let menuWidth: CGFloat = 400
    
    private var toggleHotKey: HotKey!
    private var enterHotKey: HotKey!
    private var escHotKey: HotKey!
    
    var timer: Timer!
    let pasteboard: NSPasteboard = .general
    var lastChangeCount: Int = 0
    var pasteboardPaused = false
    var pasteboardWasPaused = false
    
    var pasteEventMonitor: EventMonitor!
    
    var panel: NSPanel!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let window = NSApplication.shared.windows.first else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("StatusBarButtonImage"))
        }
        
        statusItem.menu = NSMenu()
            .with(menuItem: NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        
        pasteEventMonitor = EventMonitor(mask: [.keyDown]) { [weak self] event in
            if let self = self {
                self.pasteEventMonitor.stop()
                self.pasteboardPaused = false
            }
        }
        
        toggleHotKey = HotKey(keyCombo: KeyCombo(key: .v, modifiers: [.command, .shift]))
        toggleHotKey.keyDownHandler = { [weak self] in
            if let strongSelf = self {
                strongSelf.togglePopover()
            }
        }
        
        enterHotKey = HotKey(keyCombo: KeyCombo(key: .return, modifiers: []))
        enterHotKey.keyDownHandler = { [weak self] in
            if let self = self {
                self.pasteboardPaused = true
                if selected != 0 {
                    let pasteboard = NSPasteboard.general
                    pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
                    pasteboard.setString(history[selected], forType: NSPasteboard.PasteboardType.string)
                    history.remove(at: selected)
                }
                self.pasteEventMonitor.start()
                send(9, useCommandFlag: true)
                self.closePopover()
            }
            
        }
        enterHotKey.isPaused = true
        
        escHotKey = HotKey(keyCombo: KeyCombo(key: .escape, modifiers: []))
        escHotKey.keyDownHandler = { [weak self] in
            if let self = self {
                self.closePopover()
            }
        }
        escHotKey.isPaused = true
        
        
        if let h = UserDefaults.standard.stringArray(forKey: "history") {
            history = h
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { (t) in
            if !self.pasteboardPaused && self.lastChangeCount != self.pasteboard.changeCount  {
                self.lastChangeCount = self.pasteboard.changeCount
                NotificationCenter.default.post(name: .NSPasteboardDidChange, object: self.pasteboard)
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(onPasteboardChanged), name: .NSPasteboardDidChange, object: nil)
        
        panel = NSPanel(contentRect: NSRect.zero, styleMask: .borderless, backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.contentViewController = QuotesViewController.freshController()
        panel.backgroundColor = NSColor(calibratedHue: 0, saturation: 1.0, brightness: 0, alpha: 0.7)
        panel.setFrame(NSMakeRect(NSScreen.main!.visibleFrame.maxX - menuWidth, 0, menuWidth, NSScreen.main!.visibleFrame.maxY), display: true)
        panel.hasShadow = true
        panel.backgroundColor = .clear
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        
    }
    
    @objc
    func onPasteboardChanged(_ notification: Notification) {
        guard let pb = notification.object as? NSPasteboard else { return }
        guard let items = pb.pasteboardItems else { return }
        guard let item = items.first else { return } // TODO: handle multiple types and items
        guard let str = item.string(forType: .string) else { return }
        
        if history.count == 0 || str != history[0] {
            history.insert(str, at: 0)
        }
        UserDefaults.standard.set(history, forKey: "history")
        
    }

    @objc func togglePopover() {
        if panel.isVisible {
            closePopover()
        } else {
            showPopover()
        }
    }
    
    func showPopover() {
        panel.makeKeyAndOrderFront(true)
        
        enterHotKey.isPaused = false
        downHotKey.isPaused = false
        upHotKey.isPaused = false
        escHotKey.isPaused = false
        downLongHotKey.isPaused = false
    }
    
    func closePopover() {
        panel.close()
        
        enterHotKey.isPaused = true
        downHotKey.isPaused = true
        upHotKey.isPaused = true
        escHotKey.isPaused = true
        downLongHotKey.isPaused = true
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


extension NSMenuItem {
    
    func with(submenu: NSMenu) -> NSMenuItem {
        self.submenu = submenu
        return self
    }
}


extension NSMenu {
    
    func with(menuItem: NSMenuItem) -> NSMenu {
        self.addItem(menuItem)
        return self
    }
}
