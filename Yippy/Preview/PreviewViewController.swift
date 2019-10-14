//
//  PreviewViewController.swift
//  Yippy
//
//  Created by Matthew Davidson on 9/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class PreviewViewController: NSViewController {
    
    @IBOutlet var textView: NSTextView!
    
    let padding = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    @IBOutlet var topPaddingConstraint: NSLayoutConstraint!
    @IBOutlet var bottomPaddingConstraint: NSLayoutConstraint!
    @IBOutlet var rightPaddingConstraint: NSLayoutConstraint!
    @IBOutlet var leftPaddingConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTextView()
        
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        
        topPaddingConstraint.constant = padding.top
        bottomPaddingConstraint.constant = padding.bottom
        rightPaddingConstraint.constant = padding.right
        leftPaddingConstraint.constant = padding.left
    }
    
    func setupTextView() {
        textView.textContainerInset = NSSize(width: 15, height: 15)
        textView.textContainer?.lineFragmentPadding = 0
        textView.drawsBackground = false
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
    }
    
    func getAttributedString(forHistoryItem item: HistoryItem, withDefaultAttributes attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        if let attrStr = item.getRtfAttributedString() {
            return attrStr
        }
        else if let plainStr = item.getPlainString() {
            return NSAttributedString(string: plainStr, attributes: attributes)
        }
        else if let htmlStr = item.getHtmlString() {
            return NSAttributedString(string: htmlStr, attributes: attributes)
        }
        else if let url = item.getFileUrl() {
            return NSAttributedString(string: url.path, attributes: attributes)
        }
        else {
            return NSAttributedString(string: "Unknown format", attributes: attributes)
        }
    }
    
    func sizeTo(historyItem: HistoryItem) -> NSRect {
        let text = getAttributedString(forHistoryItem: historyItem, withDefaultAttributes: YippyTextItem.itemStringAttributes)
        
        let maxWindowWidth = NSScreen.main!.frame.width * 0.8
        let maxWindowHeight = NSScreen.main!.frame.height * 0.8
        
        let maxTextContainerWidth = maxWindowWidth - padding.xTotal - textView.textContainerInset.width * 2
        
        let bRect = text.boundingRect(with: NSSize(width: maxTextContainerWidth, height: CGFloat.greatestFiniteMagnitude), options: NSString.DrawingOptions(arrayLiteral: .usesFontLeading, .usesLineFragmentOrigin))
        
        let windowWidth = bRect.width + padding.xTotal + textView.textContainerInset.width * 2
        
        let windowHeight = min(maxWindowHeight, bRect.height + padding.yTotal + textView.textContainerInset.height * 2)
        
        let center = NSPoint(x: NSScreen.main!.frame.midX - windowWidth / 2, y: NSScreen.main!.frame.midY - windowHeight / 2)
        
        textView.textStorage?.setAttributedString(text)
        
        return NSRect(origin: center, size: NSSize(width: windowWidth, height: windowHeight))
    }
}
