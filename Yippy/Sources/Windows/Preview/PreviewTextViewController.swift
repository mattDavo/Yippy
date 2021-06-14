//
//  PreviewTextViewController.swift
//  Yippy
//
//  Created by Matthew Davidson on 9/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class PreviewTextViewController: NSViewController, PreviewViewController {
    
    static let identifier = NSStoryboard.SceneIdentifier(stringLiteral: "PreviewTextViewController")
    
    @IBOutlet var textView: NSTextView!
    
    let padding = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
    @IBOutlet var topPaddingConstraint: NSLayoutConstraint!
    @IBOutlet var bottomPaddingConstraint: NSLayoutConstraint!
    @IBOutlet var rightPaddingConstraint: NSLayoutConstraint!
    @IBOutlet var leftPaddingConstraint: NSLayoutConstraint!
    
    var isRichText: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTextView()
        
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        view.layer?.borderWidth = padding.left
        
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
    
    func configureView(forItem item: HistoryItem) -> NSRect {
        let text = HistoryItemText.getAttributedString(forItem: item, usingItemRtf: isRichText)
        
        textView.attributedText = text
        return calculateWindowFrame(forText: text)
    }
    
    func calculateWindowFrame(forText text: NSAttributedString) -> NSRect {
        let maxWindowWidth = NSScreen.main!.frame.width * 0.8
        let maxWindowHeight = NSScreen.main!.frame.height * 0.8
        
        let maxTextContainerWidth = maxWindowWidth - padding.xTotal - textView.textContainerInset.width * 2
        
        let bRect = text.calculateSize(withMaxWidth: maxTextContainerWidth)
        
        let windowWidth = bRect.width + padding.xTotal + textView.textContainerInset.width * 2
        
        let windowHeight = min(maxWindowHeight, bRect.height + padding.yTotal + textView.textContainerInset.height * 2)
        
        let center = NSPoint(x: NSScreen.main!.frame.midX - windowWidth / 2, y: NSScreen.main!.frame.midY - windowHeight / 2)
        
        return NSRect(origin: center, size: NSSize(width: windowWidth, height: windowHeight))
    }
}
