//
//  YippyTextItem.swift
//  Yippy
//
//  Created by Matthew Davidson on 2/8/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Cocoa

class YippyTextItem: YippyItemBase, YippyItem {
    
    // MARK: - UI Constants
    
    static let itemStringAttributes: [NSAttributedString.Key: Any] = [
        .font: YippyTextItem.font,
        .foregroundColor: NSColor.textColor
    ]
    
    static let shortcutStringAttributes: [NSAttributedString.Key: Any] = [
        .font: YippyTextItem.font,
        .foregroundColor: NSColor.white.withAlphaComponent(0.7)
    ]
    
    static let padding = NSEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
    
    static let textInset = NSEdgeInsetsZero // NSEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
    
    class var identifier: NSUserInterfaceItemIdentifier {
        return NSUserInterfaceItemIdentifier(Accessibility.identifiers.yippyTextItem)
    }
    
    static let font = Fonts.yippyPlainText
    
    // MARK: - Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupItemTextView()
    }
    
    func setupItemTextView() {
        // Define the maximum size of the text container, so that the text renders correctly when there needs to be clipping.
        // Width can be any value
        itemTextView.textContainer?.size = NSSize(width: 300, height: Constants.panel.maxCellHeight - YippyTextItem.padding.top - YippyTextItem.padding.bottom - Self.textInset.yTotal - Self.contentViewInsets.yTotal)
        
        itemTextView.translatesAutoresizingMaskIntoConstraints = false
        itemTextView.isSelectable = false
        itemTextView.usingEdgeInsets = true
        itemTextView.textInset = YippyTextItem.textInset
        itemTextView.textContainer?.lineFragmentPadding = 0
        itemTextView.drawsBackground = false
        
        // Add constraints for the item text view
        contentView.addConstraint(NSLayoutConstraint(item: itemTextView!, attribute: .leading, relatedBy: .equal, toItem: contentView, attribute: .leading, multiplier: 1, constant: Self.padding.left))
        contentView.addConstraint(NSLayoutConstraint(item: itemTextView!, attribute: .top, relatedBy: .equal, toItem: contentView, attribute: .top, multiplier: 1, constant: Self.padding.top))
        contentView.addConstraint(NSLayoutConstraint(item: contentView!, attribute: .trailing, relatedBy: .equal, toItem: itemTextView, attribute: .trailing, multiplier: 1, constant: Self.padding.right))
        contentView.addConstraint(NSLayoutConstraint(item: contentView!, attribute: .bottom, relatedBy: .equal, toItem: itemTextView, attribute: .bottom, multiplier: 1, constant: Self.padding.bottom))
    }
    
    func setupCell(withHistoryItem historyItem: HistoryItem, atIndexPath indexPath: IndexPath) {
        let itemStr = Self.getAttributedString(forHistoryItem: historyItem, withDefaultAttributes: YippyTextItem.itemStringAttributes)
        itemTextView.attributedText = itemStr
        
        let shortcutStr = NSAttributedString(string: indexPath.item < 10 ? "⌘ + \(indexPath.item)" : "", attributes: YippyTextItem.shortcutStringAttributes)
        shortcutTextView.attributedText = shortcutStr
        shortcutTextView.isHidden = indexPath.item >= 10
        updateShortcutTextViewContraints()
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
    
    static func getItemSize(withCollectionView collectionView: NSCollectionView, forHistoryItem historyItem: HistoryItem) -> NSSize {
        // Calculate the width of the cell
        let cellWidth = floor(collectionView.frame.width - sectionInset.left - sectionInset.right)
        
        // Calculate the width of the text container
        let width = cellWidth - Self.padding.left - Self.padding.right - Self.textInset.xTotal - Self.contentViewInsets.xTotal
        
        // Create an attributed string of the text
        let attrStr = getAttributedString(forHistoryItem: historyItem, withDefaultAttributes: Self.itemStringAttributes)
        
        // Get the max height of the text container
        let maxTextContainerHeight = Constants.panel.maxCellHeight - Self.padding.top - Self.padding.bottom - Self.textInset.yTotal - Self.contentViewInsets.yTotal
        
        // Determine the height of the text view (capping the cell height)
        let bRect = attrStr.boundingRect(with: NSSize(width: width, height: maxTextContainerHeight), options: NSString.DrawingOptions.usesLineFragmentOrigin.union(.usesFontLeading))
        
        // Add the padding back to get the height of the cell
        let height = min(bRect.height, maxTextContainerHeight) + YippyTextItem.padding.top + Self.padding.bottom + Self.textInset.yTotal + Self.contentViewInsets.yTotal
        
        return NSSize(width: cellWidth, height: ceil(height))
    }
}
