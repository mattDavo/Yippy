//
//  NSEdgeInset+Convenience.swift
//  Yippy
//
//  Created by Matthew Davidson on 4/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import SwiftUI

extension NSEdgeInsets {
    
    var yTotal: CGFloat {
        return top + bottom
    }
    
    var xTotal: CGFloat {
        return left + right
    }
}

extension EdgeInsets {
    var yTotal: CGFloat {
        return top + bottom
    }
    
    var xTotal: CGFloat {
        return leading + trailing
    }
}
