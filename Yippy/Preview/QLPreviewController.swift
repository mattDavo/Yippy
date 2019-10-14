//
//  QLPreviewController.swift
//  Yippy
//
//  Created by Matthew Davidson on 10/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import RxSwift
import RxRelay
import QuickLook
import Quartz

class QLPreviewController: NSResponder, QLPreviewPanelDelegate, QLPreviewPanelDataSource {
    
    var previewHistoryItem: HistoryItem?
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return 1
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard let historyItem = previewHistoryItem else { return nil }
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
    
    func subscribeTo(previewHistoryItem: BehaviorRelay<HistoryItem?>) -> Disposable {
        return previewHistoryItem
            .subscribe(onNext: { historyItem in
                self.previewHistoryItem = historyItem
                if let historyItem = historyItem {
                    if historyItem.getFileUrl() != nil {
                        if !QLPreviewPanel.shared()!.isVisible {
                            let panel = QLPreviewPanel.shared()!
                            NSApp.nextResponder = self
                            panel.updateController()
                            panel.makeKeyAndOrderFront(nil)
                            panel.level = NSWindow.Level(NSWindow.Level.mainMenu.rawValue - 1)
                        }
                        QLPreviewPanel.shared()!.reloadData()
                    }
                    else if QLPreviewPanel.shared()!.isVisible {
                        QLPreviewPanel.shared()?.close()
                    }
                }
                else {
                    QLPreviewPanel.shared()?.close()
                }
            })
    }
}
