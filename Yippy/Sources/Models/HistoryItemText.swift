//
//  HistoryItemText.swift
//  Yippy
//
//  Created by Matthew Davidson on 12/4/20.
//  Copyright © 2020 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

struct HistoryItemText {
    
    static let itemStringAttributes: [NSAttributedString.Key: Any] = [
        .font: Constants.fonts.yippyPlainText,
        .foregroundColor: NSColor.textColor
    ]
    
    static func getString(forItem item: HistoryItem) -> String {
        if let plainStr = item.getPlainString() {
            return plainStr
        }
        else if let attrStr = item.getRtfAttributedString() {
            return attrStr.string
        }
        else if let htmlStr = item.getHtmlRawString() {
            return htmlStr
        }
        else if let url = item.getFileUrl() {
            return url.path
        }
        else {
            return "Unknown format"
        }
    }
    
    static func getAttributedString(forItem item: HistoryItem, usingItemRtf: Bool = true) -> NSAttributedString {
        if usingItemRtf {
            if let attrStr = item.getRtfAttributedString() {
                return attrStr
            }
        }
        
        return NSAttributedString(string: getString(forItem: item), attributes: itemStringAttributes)
    }
}
