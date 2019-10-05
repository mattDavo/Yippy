//
//  NSView+ConstraintWithIdentifier.swift
//  Yippy
//
//  Created by Matthew Davidson on 5/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

extension NSView {
    
    // https://stackoverflow.com/a/39111696
    
    func constraint(withIdentifier identifier: String) -> NSLayoutConstraint? {
        return self.constraints.filter{ $0.identifier == identifier }.first
    }
}

