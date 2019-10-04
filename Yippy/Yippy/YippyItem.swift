//
//  YippyItem.swift
//  Yippy
//
//  Created by Matthew Davidson on 2/8/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Cocoa

class YippyItem: NSCollectionViewItem {
    
    class YippyItemCellTextView: NSTextView {
        
        override func mouseDown(with event: NSEvent) {
            self.nextResponder?.mouseDown(with: event)
        }
    }
    
    // MARK: - UI Constants
    
    static let itemStringAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "Roboto Mono Light for Powerline", size: 12)!
    ]
    
    static let shortcutStringAttributes: [NSAttributedString.Key: Any] = [
        .font: YippyItem.font,
        .foregroundColor: NSColor.white
    ]
    
    static let padding = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
    
    static let textContainerInset = NSSize(width: 20, height: 10)
    
    static let identifier = Accessibility.identifiers.yippyItem
    
    static let font = NSFont(name: "Roboto Mono Light for Powerline", size: 12)!
    
    // MARK: - UI Items
    
    var itemTextView: YippyItemCellTextView!
    var shortcutTextView: YippyItemCellTextView!
    
    // MARK: - isSelected override
    
    override var isSelected: Bool {
        didSet {
            setHighlight()
        }
    }
    
    // MARK: - Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.wantsLayer = true
        
        setupItemTextView()
        setupShortcutTextView()
    }
    
    func setHighlight() {
        itemTextView.layer?.backgroundColor = self.isSelected ? NSColor.systemBlue.withAlphaComponent(0.5).cgColor : NSColor.lightGray.withAlphaComponent(0.5).cgColor
    }
    
    func setupItemTextView() {
        // Create item text view
        itemTextView = YippyItemCellTextView(frame: view.frame)
        view.addSubview(itemTextView)
        // Define the maximum size of the text container, so that the text renders correctly when there needs to be clipping.
        // Width can be any value
        itemTextView.textContainer?.size = NSSize(width: 300, height: Constants.panel.maxCellHeight - YippyItem.padding.top - YippyItem.padding.bottom - YippyItem.textContainerInset.height * 2)
        
        itemTextView.translatesAutoresizingMaskIntoConstraints = false
        itemTextView.drawsBackground = true
        itemTextView.wantsLayer = true
        itemTextView.backgroundColor = .clear
        itemTextView.isSelectable = false
        itemTextView.textContainerInset = YippyItem.textContainerInset
        itemTextView.textContainer?.lineFragmentPadding = 0
        itemTextView.layer?.borderColor = NSColor.gray.cgColor
        itemTextView.layer?.borderWidth = 0.1
        itemTextView.layer?.cornerRadius = 7
        itemTextView.layer?.masksToBounds = true
        
        // Add constraints for the item text view
        view.addConstraint(NSLayoutConstraint(item: itemTextView!, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1, constant: YippyItem.padding.left))
        view.addConstraint(NSLayoutConstraint(item: itemTextView!, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: YippyItem.padding.top))
        view.addConstraint(NSLayoutConstraint(item: view, attribute: .trailing, relatedBy: .equal, toItem: itemTextView, attribute: .trailing, multiplier: 1, constant: YippyItem.padding.right))
        view.addConstraint(NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal, toItem: itemTextView, attribute: .bottom, multiplier: 1, constant: YippyItem.padding.bottom))
    }
    
    func setupShortcutTextView() {
        shortcutTextView = YippyItemCellTextView(frame: view.frame)
        itemTextView.addSubview(shortcutTextView)
        shortcutTextView.translatesAutoresizingMaskIntoConstraints = false
        shortcutTextView.wantsLayer = true
        shortcutTextView.backgroundColor = .clear
        shortcutTextView.isSelectable = false
        shortcutTextView.textContainer?.lineFragmentPadding = 0
        shortcutTextView.alignment = .right
        shortcutTextView.textContainerInset = NSSize(width: 5, height: 5)
        shortcutTextView.layer?.cornerRadius = 7
        shortcutTextView.layer?.maskedCorners = .layerMinXMaxYCorner
        shortcutTextView.layer?.backgroundColor = NSColor.darkGray.withAlphaComponent(0.5).cgColor
        shortcutTextView.isHorizontallyResizable = true
    }
    
    func getShortcutTextViewSize() -> NSSize {
        // Determine the size of the text in one line
        let bRect = shortcutTextView.attributedString().getSingleLineSize()
        
        return NSSize(width: bRect.width + shortcutTextView.textContainerInset.width * 2, height: bRect.height + shortcutTextView.textContainerInset.height * 2)
    }
    
    func getShortcutTextViewOrigin() -> NSPoint {
        let minSize = getShortcutTextViewSize()
        return NSPoint(x: view.frame.width - YippyItem.padding.left - YippyItem.padding.right - minSize.width + shortcutTextView.layer!.borderWidth, y: -shortcutTextView.layer!.borderWidth)
    }
}
