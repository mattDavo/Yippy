//
//  SettingsTabViewController.swift
//  Yippy
//
//  Created by Matthew Davidson on 12/4/20.
//  Copyright © 2020 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class SettingsTabViewController: NSTabViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabViewItems[0].image = NSImage(imageLiteralResourceName: "gear")
        tabViewItems[1].image = NSImage(imageLiteralResourceName: "command")
        
        let ignoredApps = NSTabViewItem(viewController: IgnoredAppsSettingsViewController())
        ignoredApps.label = "Ignored Apps"
        if #available(macOS 11.0, *) {
            ignoredApps.image = NSImage(systemSymbolName: "nosign", accessibilityDescription: "Ignored Apps")
        }
        else {
            ignoredApps.image = NSImage(named: NSImage.stopProgressTemplateName)
        }
        addTabViewItem(ignoredApps)

        let history = NSTabViewItem(viewController: HistorySettingsViewController())
        history.label = "History"
        if #available(macOS 11.0, *) {
            history.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "History")
        }
        else {
            history.image = NSImage(named: NSImage.refreshTemplateName)
        }
        addTabViewItem(history)
        
        if #available(macOS 10.15, *), let coordinator = SyncCoordinator.main {
            let sync = NSTabViewItem(viewController: SyncSettingsViewController(sync: coordinator))
            sync.label = "Sync"
            if #available(macOS 11.0, *) {
                sync.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Sync")
            }
            else {
                sync.image = NSImage(named: NSImage.refreshTemplateName)
            }
            addTabViewItem(sync)
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        tabView.selectTabViewItem(at: 0)
        tabView(tabView, didSelect: tabView.tabViewItem(at: 0))
    }
    
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        if let window = tabView.window, let tabViewItem = tabViewItem {
            window.title = tabViewItem.label
        }
    }
}
