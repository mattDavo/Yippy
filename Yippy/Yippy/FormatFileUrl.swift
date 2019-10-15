//
//  FormatFileUrl.swift
//  Yippy
//
//  Created by Matthew Davidson on 15/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

func formatFileUrl(_ url: URL) -> NSAttributedString {
    let str = NSMutableAttributedString(string: url.path)
    
    let lastComponentAttributes: [NSAttributedString.Key: Any] = [
        .font: Constants.fonts.yippyFileNameText,
        .foregroundColor: NSColor.textColor
    ]
    
    let pathAttributes: [NSAttributedString.Key: Any] = [
        .font: Constants.fonts.yippyFileNameText,
        .foregroundColor: NSColor.secondaryLabelColor
    ]
    
    let startOfLast = url.path.count - url.lastPathComponent.count
    
    str.addAttributes(pathAttributes, range: NSRange(location: 0, length: startOfLast))
    str.addAttributes(lastComponentAttributes, range: NSRange(location: startOfLast, length: url.lastPathComponent.count))
    
    return str
}
