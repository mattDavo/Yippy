//
//  PreviewTiffWindowController.swift
//  Yippy
//
//  Created by Matthew Davidson on 17/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import RxSwift
import RxCocoa

class PreviewTiffWindowController: NSWindowController {
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.level = NSWindow.Level(NSWindow.Level.mainMenu.rawValue - 1)
        window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window?.isOpaque = false
        window?.backgroundColor = .clear
    }
    
    static func createPreviewTiffWindowController() -> PreviewTiffWindowController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier(stringLiteral: "PreviewTiffWindowController")
        guard let windowController = storyboard.instantiateController(withIdentifier: identifier) as? PreviewTiffWindowController else {
            fatalError("Failed to load PreviewTiffWindowController of type PreviewTiffWindowController from the Main storyboard.")
        }
        return windowController
    }
    
    func subscribeTo(previewHistoryItem: BehaviorRelay<HistoryItem?>) -> Disposable {
        return previewHistoryItem
            .subscribe(onNext: { historyItem in
                if let historyItem = historyItem {
                    if historyItem.types.contains(.tiff) {
                        guard let controller = self.window?.contentViewController as? PreviewTiffViewController else { return }
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
