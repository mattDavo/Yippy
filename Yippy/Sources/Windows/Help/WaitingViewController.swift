//
//  WaitingViewController.swift
//  Yippy
//
//  Created by Matthew Davidson on 12/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class WaitingViewController: NSViewController {
    
    @IBAction func allowAccessClicked(_ sender: Any) {
        _ = Helper.isControlGranted(showPopup: true)
    }
}
