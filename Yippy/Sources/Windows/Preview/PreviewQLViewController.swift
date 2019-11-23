//
//  PreviewQLViewController.swift
//  Yippy
//
//  Created by Matthew Davidson on 19/11/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import QuickLook
import Quartz

/**
 Dummy view controller for controlling the shared QLPreviewPanel.
 */
class PreviewQLViewController: NSViewController, PreviewViewController {
    
    static let identifier = NSStoryboard.SceneIdentifier(stringLiteral: "PreviewQLViewController")
    
    var previewItem: HistoryItem?
    
    func configureView(forItem item: HistoryItem) -> NSRect {    
        previewItem = item
        
        if let panel = QLPreviewPanel.shared() {
            if !panel.isVisible {
                NSApp.nextResponder = self
                panel.updateController()
                panel.makeKeyAndOrderFront(nil)
                panel.level = NSWindow.Level(NSWindow.Level.mainMenu.rawValue - 1)
            }
            panel.reloadData()
        }
        else {
            let error = YippyError(localizedDescription: "Failed to show preview for item '\(item.fsId)' because shared QLPreviewPanel is nil.")
            error.log(with: ErrorLogger.general)
            error.show(with: Alerter.general)
        }
        
        return .zero
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        guard let panel = QLPreviewPanel.shared() else {
            let error = YippyError(localizedDescription: "Failed to close preview because shared QLPreviewPanel is nil.")
            error.log(with: ErrorLogger.general)
            error.show(with: Alerter.general)
            return
        }
        panel.close()
    }
}

extension PreviewQLViewController: QLPreviewPanelDelegate, QLPreviewPanelDataSource {

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return 1
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard let historyItem = previewItem else { return nil }
        return historyItem.getFileUrl() as QLPreviewItem?
    }
    
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.delegate = self
        panel.dataSource = self
    }
    
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }
    
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        
    }
}
