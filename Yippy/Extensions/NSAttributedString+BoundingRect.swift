//
//  NSAttributedString+BoundingRect.swift
//  Yippy
//
//  Created by Matthew Davidson on 4/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

extension NSAttributedString {
    
    func getSingleLineSize() -> NSSize {
        // Determine the size of the text in one line
        return self.boundingRect(with: NSSize(width: Int.max, height: Int.max), options: NSString.DrawingOptions.usesLineFragmentOrigin.union(.usesFontLeading)).size
    }
    
}
