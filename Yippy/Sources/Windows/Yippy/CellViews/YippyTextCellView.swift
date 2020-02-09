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
    
    override class var identifier: NSUserInterfaceItemIdentifier {
        return NSUserInterfaceItemIdentifier(Accessibility.identifiers.yippyTextCellView)
    }
    
    static let font = Constants.fonts.yippyPlainText
    
    // MARK: - Methods
    
    override func commonInit() {
        super.commonInit()
        
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
        itemTextView.isHorizontallyResizable = false
        itemTextView.isVerticallyResizable = false
        
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
        else if let htmlStr = item.getHtmlRawString() {
            return NSAttributedString(string: htmlStr, attributes: attributes)
        }
        else if let url = item.getFileUrl() {
            return NSAttributedString(string: url.path, attributes: attributes)
        }
        else {
            return NSAttributedString(string: "Unknown format", attributes: attributes)
        }
    }
    
    static func getTextContainerWidth(cellWidth: CGFloat) -> CGFloat {
        return cellWidth - Self.padding.left - Self.padding.right - Self.textInset.xTotal - Self.contentViewInsets.xTotal
    }
    
    static func getTextContainerMaxHeight() -> CGFloat {
        return Constants.panel.maxCellHeight - Self.padding.top - Self.padding.bottom - Self.textInset.yTotal - Self.contentViewInsets.yTotal
    }
    
    static func getCellHeight(estTextHeight: CGFloat) -> CGFloat {
        // Get the max height of the text container
        let maxTextContainerHeight = getTextContainerMaxHeight()
        
        return min(estTextHeight, maxTextContainerHeight) + Self.padding.top + Self.padding.bottom + Self.textInset.yTotal + Self.contentViewInsets.yTotal
    }
    
    static func calculateCellHeight(yippyTableView: YippyTableView, historyItem: HistoryItem) -> CGFloat {
        // Calculate the width of the cell
        let cellWidth = floor(yippyTableView.cellWidth)
        
        // Calculate the width of the text container
        let width = YippyTextCellView.getTextContainerWidth(cellWidth: cellWidth)
        
        // Create an attributed string of the text
        let attrStr = YippyTextCellView.getAttributedString(forHistoryItem: historyItem, withDefaultAttributes: YippyTextCellView.itemStringAttributes)
        
        // Determine the height of the text
        let estTextHeight = attrStr.calculateSize(withMaxWidth: width).height
        
        // Add the padding back to get the height of the cell
        let height = YippyTextCellView.getCellHeight(estTextHeight: estTextHeight)
        
        return ceil(height)
    }
    
    static func getItemHeight(withYippyTableView yippyTableView: YippyTableView, forHistoryItem historyItem: HistoryItem) -> CGFloat {
        
        return calculateCellHeight(yippyTableView: yippyTableView, historyItem: historyItem)
    }
    
    class func makeItem() -> YippyItem {
        return YippyTextCellView(frame: .zero)
    }
}
