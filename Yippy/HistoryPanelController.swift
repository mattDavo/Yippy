//
//  HistoryPanelController.swift
//  Yippy
//
//  Created by Matthew Davidson on 7/8/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import RxSwift
import RxRelay

class HistoryPanelController {
    
    var panel: NSPanel!
    var disposeBag: DisposeBag
    
    init() {
        self.disposeBag = DisposeBag()
        self.panel = createPanel()
    }
    
    func createPanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect.zero, styleMask: .borderless, backing: .buffered, defer: false)
        panel.contentViewController = HistoryViewController.freshController()
        panel.setFrame(PanelPosition.right.frame, display: true)
        panel.level = .floating
        panel.isOpaque = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = NSColor(calibratedHue: 0, saturation: 1.0, brightness: 0, alpha: 0.7)
        panel.hasShadow = true
        panel.backgroundColor = .clear
        
        return panel
    }
    
    func subscribeTo(toggle: BehaviorRelay<Bool>) -> Disposable {
        return toggle
            .subscribe(onNext: {
                [] in
                if !$0 {
                    self.panel.close()
                }
                else {
                    self.panel.makeKeyAndOrderFront(true)
                }
            })
    }
    
    func subscribePositionTo(position: BehaviorRelay<PanelPosition>) -> Disposable {
        return position
            .subscribe(onNext: {
                [] in
                guard let hvc = self.panel.contentViewController as? HistoryViewController else {
                    print("TODO: Unexpected panel contentViewController")
                    return
                }
                hvc.frameWillChange()
                self.panel.setFrame($0.frame, display: true)
                hvc.frameDidChange()
            })
    }
}


