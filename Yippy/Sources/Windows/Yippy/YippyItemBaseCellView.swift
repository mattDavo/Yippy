//
//  YippyItemBaseCellView.swift
//  Yippy
//
//  Created by Matthew Davidson on 13/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

/// Abstract base class for all Yippy collection view items.
///
/// Creates and sets up the `contentView`, `shortcutTextView` and the `itemTextView`.
///
/// Handles highlight changes.
class YippyItemBaseCellView: NSTableCellView {
    
    static let contentViewInsets = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
    
    class var identifier: NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier("YippyItemBaseCellView")
    }
    
    var contentView: YippyItemContentView!
    var shortcutTextView: YippyItemCellTextView!
    var itemTextView: YippyItemCellTextView!
    
    private var lastSetSelected: Bool?
    
    override func updateLayer() {
        super.updateLayer()
        
        guard let lastSetSelected = self.lastSetSelected else { return }
        if !lastSetSelected { return }
        guard #available(OSX 10.14, *) else { return }
        layer?.backgroundColor = NSColor.controlAccentColor.cgColor
    }
    
    static let shortcutStringAttributes: [NSAttributedString.Key: Any] = [
        .font: Constants.fonts.yippyPlainText,
        .foregroundColor: NSColor.white.withAlphaComponent(0.7)
    ]
    
    func setHighlight(isSelected: Bool) {
        var highlightColor = NSColor.systemBlue.withAlphaComponent(0.7).cgColor
        if #available(OSX 10.14, *) {
            highlightColor = NSColor.controlAccentColor.cgColor
        }
        
        layer?.backgroundColor = isSelected ? highlightColor : NSColor.clear.cgColor
        self.lastSetSelected = isSelected
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        commonInit()
    }
    
    func commonInit() {
        contentView = YippyItemContentView(frame: .zero)
        addSubview(contentView)
        itemTextView = YippyItemCellTextView(frame: .zero)
        contentView.addSubview(itemTextView)
        shortcutTextView = YippyItemCellTextView(frame: .zero)
        contentView.addSubview(shortcutTextView)
        
        wantsLayer = true
        layer?.cornerRadius = 10
        itemTextView.drawsBackground = false
        itemTextView.setAccessibilityIdentifier(Accessibility.identifiers.yippyItemTextView)
        
        setupContentView()
        setupShortcutTextView()
    }
    
    func setupContentView() {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 7
        
        addConstraint(NSLayoutConstraint(item: contentView!, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: Self.contentViewInsets.left))
        addConstraint(NSLayoutConstraint(item: contentView!, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: Self.contentViewInsets.top))
        addConstraint(NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: contentView, attribute: .trailing, multiplier: 1, constant: Self.contentViewInsets.right))
        addConstraint(NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: contentView, attribute: .bottom, multiplier: 1, constant: Self.contentViewInsets.bottom))
    }
    
    func setupShortcutTextView() {
        shortcutTextView.translatesAutoresizingMaskIntoConstraints = false
        shortcutTextView.wantsLayer = true
        shortcutTextView.isSelectable = false
        shortcutTextView.textContainer?.lineFragmentPadding = 0
        shortcutTextView.alignment = .right
        shortcutTextView.textContainerInset = NSSize(width: 5, height: 2)
        shortcutTextView.layer?.cornerRadius = 7
        shortcutTextView.layer?.maskedCorners = .layerMinXMaxYCorner
        shortcutTextView.isHorizontallyResizable = false
        shortcutTextView.isVerticallyResizable = false
        shortcutTextView.backgroundColor = NSColor(named: NSColor.Name("ShortcutBackgroundColor"))!
        if #available(OSX 10.14, *) {
            shortcutTextView.backgroundColor = NSColor.controlAccentColor
        }
        shortcutTextView.layer?.zPosition = 1
        
        contentView.addConstraint(NSLayoutConstraint(item: shortcutTextView!, attribute: .top, relatedBy: .equal, toItem: contentView, attribute: .top, multiplier: 1, constant: 0))
        contentView.addConstraint(NSLayoutConstraint(item: contentView!, attribute: .trailing, relatedBy: .equal, toItem: shortcutTextView, attribute: .trailing, multiplier: 1, constant: 0))
        shortcutTextView.widthAnchor.constraint(equalToConstant: 0, withIdentifier: "width")?.isActive = true
        shortcutTextView.heightAnchor.constraint(equalToConstant: 0, withIdentifier: "height")?.isActive = true
    }
    
    func getShortcutTextViewSize() -> NSSize {
        // Determine the size of the text in one line
        let bRect = shortcutTextView.attributedString().getSingleLineSize()
        return NSSize(width: bRect.width + shortcutTextView.textContainer!.lineFragmentPadding + shortcutTextView.textContainerInset.width * 2, height: bRect.height + shortcutTextView.textContainerInset.height * 2)
    }
    
    func updateShortcutTextViewContraints() {
        let size = getShortcutTextViewSize()
        shortcutTextView.constraint(withIdentifier: "width")?.constant = ceil(size.width)
        shortcutTextView.constraint(withIdentifier: "height")?.constant = ceil(size.height)
    }
    
    func setupShortcutTextView(at i: Int) {
        let shortcutStr = NSAttributedString(string: i < 10 ? "⌘ + \(i)" : "", attributes: Self.shortcutStringAttributes)
        shortcutTextView.attributedText = shortcutStr
        shortcutTextView.isHidden = i >= 10
        updateShortcutTextViewContraints()
    }
    
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu(title: "Test").with(menuItem: NSMenuItem(title: "Options coming soon", action: nil, keyEquivalent: ""))
        
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}
