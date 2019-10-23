//
//  Alerter.swift
//  Yippy
//
//  Created by Matthew Davidson on 20/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class Alerter {
    
    static var general = Alerter()
    
    func show(_ alertable: Alertable) {
        DispatchQueue.main.async {
            alertable.createAlert().runModal()
        }
    }
}
