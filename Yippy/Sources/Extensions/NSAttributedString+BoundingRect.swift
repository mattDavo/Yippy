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
    
    /// Calculates the size of the text where there is a maximum width, but the width of the size returned could be less.
    ///
    /// Documentation: [https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html)
    func calculateSize(withMaxWidth width: CGFloat) -> CGSize {
        let textStorage = NSTextStorage(attributedString: self)
        let textContainer = NSTextContainer(containerSize: NSSize(width: width, height: CGFloat.infinity))
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        textContainer.lineFragmentPadding = 0
        layoutManager.glyphRange(for: textContainer)
        return layoutManager.usedRect(for: textContainer).size
    }
}
