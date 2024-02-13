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
    var safariPreviewController: SafariPreviewController!
    
    var disposeBag = DisposeBag()
    
    var previewItem: HistoryItem?
    
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
        previewWC.safariPreviewController = createPreviewViewController()
        
        State.main.showsRichText.distinctUntilChanged().subscribe(onNext: previewWC.onShowsRichText).disposed(by: previewWC.disposeBag)
        
        return previewWC
    }
    
    func subscribeTo(previewItem: BehaviorRelay<HistoryItem?>) -> Disposable {
        return previewItem
            .subscribe(onNext: {
                self.previewItem = $0
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
        else if item.getUrl() != nil {
            return safariPreviewController
        }
        else if item.types.contains(.tiff) || item.types.contains(.png) {
            return previewImageViewController
        }
        else {
            return previewTextViewController
        }
    }
    
    func onShowsRichText(_ showsRichText: Bool) {
        if let item = previewItem {
            previewTextViewController.isRichText = showsRichText
            if getViewController(forItem: item) is PreviewTextViewController {
                updateController(forItem: item)
            }
        }
    }
}
