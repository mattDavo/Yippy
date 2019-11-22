//
//  NSEdgeInset+Convenience.swift
//  Yippy
//
//  Created by Matthew Davidson on 4/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

extension NSEdgeInsets {
    
    var yTotal: CGFloat {
        return top + bottom
    }
    
    var xTotal: CGFloat {
        return left + right
    }
}
