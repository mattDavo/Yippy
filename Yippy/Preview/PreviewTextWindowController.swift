//
//  PreviewTextWindowController.swift
//  Yippy
//
//  Created by Matthew Davidson on 10/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import RxRelay
import RxSwift
import QuickLook
import Quartz

class PreviewTextWindowController: NSWindowController {
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.level = NSWindow.Level(NSWindow.Level.mainMenu.rawValue - 1)
        window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window?.isOpaque = false
        window?.backgroundColor = .clear
    }
    
    static func createPreviewTextWindowController() -> PreviewTextWindowController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier(stringLiteral: "PreviewTextWindowController")
        guard let windowController = storyboard.instantiateController(withIdentifier: identifier) as? PreviewTextWindowController else {
            fatalError("Failed to load PreviewTextWindowController of type PreviewTextWindowController from the Main storyboard.")
        }
        return windowController
    }
    
    func subscribeTo(previewHistoryItem: BehaviorRelay<HistoryItem?>) -> Disposable {
        return previewHistoryItem
            .subscribe(onNext: { historyItem in
                if let historyItem = historyItem {
                    if historyItem.getFileUrl() == nil && !historyItem.types.contains(.tiff) {
                        guard let controller = self.window?.contentViewController as? PreviewTextViewController else { return }
                        self.window?.setFrame(controller.sizeTo(historyItem: historyItem), display: true)
                        self.showWindow(nil)
                    }
                    else {
                        self.close()
                    }
                }
                else {
                    self.close()
                }
            })
    }
}
