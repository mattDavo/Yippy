//
//  PreviewWindowController.swift
//  Yippy
//
//  Created by Matthew Davidson on 19/11/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import RxSwift
import RxRelay

class PreviewWindowController: NSWindowController {
    
    var previewTextViewController: PreviewTextViewController!
    var previewImageViewController: PreviewImageViewController!
    var previewQLViewController: PreviewQLViewController!
    
    private static func createPreviewViewController<T>() -> T where T: PreviewViewController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        guard let controller = storyboard.instantiateController(withIdentifier: T.identifier) as? T else {
            fatalError("Failed to load \(T.identifier) of type \(T.self) from the Main storyboard.")
        }
        return controller
    }
    
    static func create() -> PreviewWindowController {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        window.level = NSWindow.Level(NSWindow.Level.mainMenu.rawValue - 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        let previewWC = PreviewWindowController(window: window)
        
        previewWC.previewTextViewController = createPreviewViewController()
        previewWC.previewImageViewController = createPreviewViewController()
        previewWC.previewQLViewController = createPreviewViewController()
        
        return previewWC
    }
    
    func subscribeTo(previewItem: BehaviorRelay<HistoryItem?>) -> Disposable {
        return previewItem
            .subscribe(onNext: {
                if let item = $0 {
                    self.showWindow(nil)
                    self.updateController(forItem: item)
                }
                else {
                    self.close()
                }
            })
    }
    
    func updateController(forItem item: HistoryItem) {
        let controller = self.getViewController(forItem: item)
        self.contentViewController = controller
        window?.setFrame(controller.configureView(forItem: item), display: true)
    }
    
    func getViewController(forItem item: HistoryItem) -> PreviewViewController {
        if item.getFileUrl() != nil {
            return previewQLViewController
        }
        else if item.types.contains(.tiff) {
            return previewImageViewController
        }
        else {
            return previewTextViewController
        }
    }
}
