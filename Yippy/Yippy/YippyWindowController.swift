//
//  YippyWindowController.swift
//  Yippy
//
//  Created by Matthew Davidson on 25/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import RxSwift
import RxRelay

class YippyWindowController: NSWindowController {
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.level = .floating
        window?.setAccessibilityIdentifier(Accessibility.identifiers.yippyWindow)
    }
    
    static func createYippyWindowController() -> YippyWindowController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier(stringLiteral: "YippyWindowController")
        guard let windowController = storyboard.instantiateController(withIdentifier: identifier) as? YippyWindowController else {
            fatalError("Failed to load YippyWindowController of type YippyWindowController from the Main storyboard.")
        }
        
        return windowController
    }
    
    func subscribeTo(toggle: BehaviorRelay<Bool>) -> Disposable {
        return toggle
            .subscribe(onNext: {
                [] in
                if !$0 {
                    self.close()
                }
                else {
                    self.showWindow(nil)
                }
            })
    }
    
    func subscribePositionTo(position: BehaviorRelay<PanelPosition>) -> Disposable {
        return position
            .subscribe(onNext: {
                [] in
                guard let hvc = self.window?.contentViewController as? YippyViewController else {
                    print("TODO: Unexpected panel contentViewController")
                    return
                }
                hvc.frameWillChange()
                self.window?.setFrame($0.frame, display: true)
                hvc.frameDidChange()
            })
    }
}
