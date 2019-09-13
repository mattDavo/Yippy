//
//  HelpViewController.swift
//  Yippy
//
//  Created by Matthew Davidson on 11/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class HelpViewController: NSViewController {
    
    var timer: Timer!
    
    @IBOutlet var waitingView: NSView!
    @IBOutlet var instructionsView: NSView!
    
    var hasControl = false
    
    let waitingViewSize = NSSize(width: 457, height: 255)
    let instructionsViewSize = NSSize(width: 568, height: 435)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hasControl = isAccessEnabled(showPopup: false)
        waitingView.isHidden = hasControl
        instructionsView.isHidden = !hasControl
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { (t) in
            let new = isAccessEnabled(showPopup: false)
            if new != self.hasControl {
                self.hasControl = new
                self.waitingView.isHidden = self.hasControl
                self.instructionsView.isHidden = !self.hasControl
                
                self.updateSize()
            }
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        updateSize()
    }
    
    func updateSize() {
        self.view.window?.setContentSize(self.hasControl ? instructionsViewSize : waitingViewSize)
        self.view.window?.center()
    }
}
