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
        checkBuildFlags()
        checkLaunchArgs()
        Controller.main = Controller(state: State.main, settings: Settings.main)
        
        showWelcomeIfNeeded()

        setupHotKey()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        
    }
    
    func checkLaunchArgs() {
        if CommandLine.arguments.contains("--uitesting") {
            do {
                try UITesting.setupUITestEnvironment(launchArgs: CommandLine.arguments, environment: ProcessInfo.processInfo.environment)
            }
            catch {
                NSAlert(error: error).runModal()
            }
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
        Controller.main.welcomeWindowController.showWindow(nil)
        
        // Bring the window to front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func setupHotKey() {
        YippyHotKeys.toggle.onDown {
            Controller.main.togglePopover()
        }
    }
}
