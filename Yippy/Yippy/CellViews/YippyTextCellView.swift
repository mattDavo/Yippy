//
//  YippyTextCellView.swift
//  Yippy
//
//  Created by Matthew Davidson on 2/8/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Cocoa

class YippyTextCellView: YippyItemBaseCellView, YippyItem {
    
    // MARK: - UI Constants
    
    static let itemStringAttributes: [NSAttributedString.Key: Any] = [
        .font: YippyTextCellView.font,
        .foregroundColor: NSColor.textColor
    ]
    
    static let padding = NSEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
    
    static let textInset = NSEdgeInsetsZero // NSEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
    
    class var identifier: NSUserInterfaceItemIdentifier {
        return NSUserInterfaceItemIdentifier(Accessibility.identifiers.yippyTextCellView)
    }
    
    static let font = Constants.fonts.yippyPlainText
    
    // MARK: - Methods
    
    override func commonInit() {
        super.commonInit()
        
        identifier = Self.identifier
        
        setupItemTextView()
    }
    
    func setupItemTextView() {
        // Define the maximum size of the text container, so that the text renders correctly when there needs to be clipping.
        // Width can be any value
        itemTextView.textContainer?.size = NSSize(width: 300, height: Constants.panel.maxCellHeight - Self.padding.top - Self.padding.bottom - Self.textInset.yTotal - Self.contentViewInsets.yTotal)
        
        itemTextView.translatesAutoresizingMaskIntoConstraints = false
        itemTextView.isSelectable = false
        itemTextView.usingEdgeInsets = true
        itemTextView.textInset = Self.textInset
        itemTextView.textContainer?.lineFragmentPadding = 0
        
        // Add constraints for the item text view
        contentView.addConstraint(NSLayoutConstraint(item: itemTextView!, attribute: .leading, relatedBy: .equal, toItem: contentView, attribute: .leading, multiplier: 1, constant: Self.padding.left))
        contentView.addConstraint(NSLayoutConstraint(item: itemTextView!, attribute: .top, relatedBy: .equal, toItem: contentView, attribute: .top, multiplier: 1, constant: Self.padding.top))
        contentView.addConstraint(NSLayoutConstraint(item: contentView!, attribute: .trailing, relatedBy: .equal, toItem: itemTextView, attribute: .trailing, multiplier: 1, constant: Self.padding.right))
        contentView.addConstraint(NSLayoutConstraint(item: contentView!, attribute: .bottom, relatedBy: .equal, toItem: itemTextView, attribute: .bottom, multiplier: 1, constant: Self.padding.bottom))
    }
    
    func setupCell(withYippyTableView yippyTableView: YippyTableView, forHistoryItem historyItem: HistoryItem, at i: Int) {
        let itemStr = Self.getAttributedString(forHistoryItem: historyItem, withDefaultAttributes: Self.itemStringAttributes)
        itemTextView.attributedText = itemStr
        
        setHighlight(isSelected: yippyTableView.isRowSelected(i))
        
        setupShortcutTextView(at: i)
    }
    
    static func getAttributedString(forHistoryItem item: HistoryItem, withDefaultAttributes attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
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
    
    static func getItemHeight(withYippyTableView yippyTableView: YippyTableView, forHistoryItem historyItem: HistoryItem) -> CGFloat {
        // Calculate the width of the cell
        let cellWidth = floor(yippyTableView.cellWidth)
        
        // Calculate the width of the text container
        let width = cellWidth - Self.padding.left - Self.padding.right - Self.textInset.xTotal - Self.contentViewInsets.xTotal
        
        // Create an attributed string of the text
        let attrStr = getAttributedString(forHistoryItem: historyItem, withDefaultAttributes: Self.itemStringAttributes)
        
        // Get the max height of the text container
        let maxTextContainerHeight = Constants.panel.maxCellHeight - Self.padding.top - Self.padding.bottom - Self.textInset.yTotal - Self.contentViewInsets.yTotal
        
        // Determine the height of the text view (capping the cell height)
        let bRect = attrStr.boundingRect(with: NSSize(width: width, height: maxTextContainerHeight), options: NSString.DrawingOptions.usesLineFragmentOrigin.union(.usesFontLeading))
        
        // Add the padding back to get the height of the cell
        let height = min(bRect.height, maxTextContainerHeight) + Self.padding.top + Self.padding.bottom + Self.textInset.yTotal + Self.contentViewInsets.yTotal
        
        return ceil(height)
    }
    
    class func makeItem() -> YippyItem {
        return YippyTextCellView(frame: .zero)
    }
}
