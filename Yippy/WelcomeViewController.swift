//
//  WelcomeViewController.swift
//  Yippy
//
//  Created by Matthew Davidson on 11/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class WelcomeViewController: NSViewController {
    
    
    @IBAction func allowAccessTapped(_ sender: Any) {
        State.main.allowAccessTapped = true
        self.view.window?.close()
        _ = isAccessEnabled(showPopup: true)
    }
}
