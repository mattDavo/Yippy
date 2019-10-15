//
//  YippyItemBase.swift
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
class YippyItemBase: NSCollectionViewItem {
    
    static let contentViewInsets = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
    
    var contentView: YippyItemContentView!
    var shortcutTextView: YippyItemCellTextView!
    var itemTextView: YippyItemCellTextView!
    
    override var isSelected: Bool {
        didSet {
            setHighlight()
        }
    }
    
    func setHighlight() {
        view.layer?.backgroundColor = self.isSelected ? NSColor.systemBlue.withAlphaComponent(0.7).cgColor : NSColor.lightGray.withAlphaComponent(0.0).cgColor
    }
    
    override func loadView() {
        view = NSView(frame: .zero)
        contentView = YippyItemContentView(frame: .zero)
        view.addSubview(contentView)
        itemTextView = YippyItemCellTextView(frame: .zero)
        contentView.addSubview(itemTextView)
        shortcutTextView = YippyItemCellTextView(frame: .zero)
        contentView.addSubview(shortcutTextView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        itemTextView.setAccessibilityIdentifier(Accessibility.identifiers.yippyItemTextView)
        itemTextView.drawsBackground = false
        
        setupContentView()
        setupShortcutTextView()
    }
    
    func setupContentView() {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 7
        
        view.addConstraint(NSLayoutConstraint(item: contentView!, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1, constant: Self.contentViewInsets.left))
        view.addConstraint(NSLayoutConstraint(item: contentView!, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: Self.contentViewInsets.top))
        view.addConstraint(NSLayoutConstraint(item: view, attribute: .trailing, relatedBy: .equal, toItem: contentView, attribute: .trailing, multiplier: 1, constant: Self.contentViewInsets.right))
        view.addConstraint(NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal, toItem: contentView, attribute: .bottom, multiplier: 1, constant: Self.contentViewInsets.bottom))
    }
    
    func setupShortcutTextView() {
        shortcutTextView.translatesAutoresizingMaskIntoConstraints = false
        shortcutTextView.wantsLayer = true
        shortcutTextView.isSelectable = false
        shortcutTextView.textContainer?.lineFragmentPadding = 0
        shortcutTextView.alignment = .right
        shortcutTextView.textContainerInset = NSSize(width: 5, height: 2.5)
        shortcutTextView.layer?.cornerRadius = 7
        shortcutTextView.layer?.maskedCorners = .layerMinXMaxYCorner
        shortcutTextView.isHorizontallyResizable = true
        shortcutTextView.backgroundColor = NSColor(named: NSColor.Name("ShortcutBackgroundColor"))!
        shortcutTextView.layer?.zPosition = 1
        
        contentView.addConstraint(NSLayoutConstraint(item: shortcutTextView!, attribute: .top, relatedBy: .equal, toItem: contentView, attribute: .top, multiplier: 1, constant: 0))
        contentView.addConstraint(NSLayoutConstraint(item: contentView!, attribute: .trailing, relatedBy: .equal, toItem: shortcutTextView, attribute: .trailing, multiplier: 1, constant: 0))
        shortcutTextView.widthAnchor.constraint(equalToConstant: 0, withIdentifier: "width")?.isActive = true
        shortcutTextView.heightAnchor.constraint(equalToConstant: 0, withIdentifier: "height")?.isActive = true
    }
    
    func getShortcutTextViewSize() -> NSSize {
        // Determine the size of the text in one line
        let bRect = shortcutTextView.attributedString().getSingleLineSize()
        
        return NSSize(width: bRect.width + shortcutTextView.textContainerInset.width * 2, height: bRect.height + shortcutTextView.textContainerInset.height * 2)
    }
    
    func updateShortcutTextViewContraints() {
        let size = getShortcutTextViewSize()
        shortcutTextView.constraint(withIdentifier: "width")?.constant = size.width
        shortcutTextView.constraint(withIdentifier: "height")?.constant = size.height
    }
    
    func setupShortcutTextView(atIndexPath indexPath: IndexPath) {
        let shortcutStr = NSAttributedString(string: indexPath.item < 10 ? "⌘ + \(indexPath.item)" : "", attributes: YippyTextItem.shortcutStringAttributes)
        shortcutTextView.attributedText = shortcutStr
        shortcutTextView.isHidden = indexPath.item >= 10
        updateShortcutTextViewContraints()
    }
}
