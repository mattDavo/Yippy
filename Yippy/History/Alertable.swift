//
//  Alertable.swift
//  Yippy
//
//  Created by Matthew Davidson on 17/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

protocol Alertable {
    
    func createAlert() -> NSAlert
    
    func show(with alerter: Alerter)
}

extension Alertable {
    
    func show(with alerter: Alerter) {
        alerter.show(self)
    }
}
