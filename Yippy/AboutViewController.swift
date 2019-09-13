//
//  AboutViewController.swift
//  Yippy
//
//  Created by Matthew Davidson on 13/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class AboutViewController: NSViewController {
    
    @IBOutlet var versionLabel: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //First get the nsObject by defining as an optional anyObject
        let version = (Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String?)!
        let build = (Bundle.main.infoDictionary!["CFBundleVersion"] as! String?)!
        
        versionLabel.stringValue = "Version \(version) (\(build))"
    }
}
