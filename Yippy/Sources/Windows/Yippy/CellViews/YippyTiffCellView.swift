//
//  YippyTiffCellView.swift
//  Yippy
//
//  Created by Matthew Davidson on 17/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class YippyTiffCellView: YippyItemBaseCellView, YippyItem {
    
    override class var identifier: NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier(Accessibility.identifiers.yippyTiffCellView)
    }
    
    static let imagePadding = NSEdgeInsetsZero
    
    var tiffView: NSImageView!
    
    override func commonInit() {
        super.commonInit()
        
        tiffView = NSImageView(frame: .zero)
        contentView.addSubview(tiffView)
        
        setupTiffView()
    }
    
    func setupTiffView() {
        tiffView.translatesAutoresizingMaskIntoConstraints = false
        tiffView.imageAlignment = .alignCenter
        contentView.addConstraint(NSLayoutConstraint(item: tiffView!, attribute: .top, relatedBy: .equal, toItem: contentView, attribute: .top, multiplier: 1, constant: Self.imagePadding.top))
        contentView.addConstraint(NSLayoutConstraint(item: tiffView!, attribute: .leading, relatedBy: .equal, toItem: contentView, attribute: .leading, multiplier: 1, constant: Self.imagePadding.left))
        contentView.addConstraint(NSLayoutConstraint(item: contentView!, attribute: .trailing, relatedBy: .equal, toItem: tiffView, attribute: .trailing, multiplier: 1, constant: Self.imagePadding.right))
        contentView.addConstraint(NSLayoutConstraint(item: contentView!, attribute: .bottom, relatedBy: .equal, toItem: tiffView, attribute: .bottom, multiplier: 1, constant: Self.imagePadding.bottom))
    }
    
    func setupCell(withYippyTableView yippyTableView: YippyTableView, forHistoryItem historyItem: HistoryItem, at i: Int) {
        setupShortcutTextView(at: i)
        setHighlight(isSelected: yippyTableView.isRowSelected(i))
        tiffView.image = historyItem.getTiffImage()
    }
    
    static func getItemHeight(withYippyTableView yippyTableView: YippyTableView, forHistoryItem historyItem: HistoryItem) -> CGFloat {
        // Calculate the width of the cell
        let cellWidth = floor(yippyTableView.cellWidth)
        
        // TODO: Need placeholder or something
        guard let image = historyItem.getTiffImage() else {
            return 50
        }
        
        let imageWidth = cellWidth - imagePadding.xTotal - contentViewInsets.xTotal
        
        // Get max image height based on pixels
        let maxImageHeight = image.size.height
        // Calcalute image height
        let imageHeight = min(image.size.height * imageWidth / image.size.width, maxImageHeight)
        
        // Get max height of cell based on visible on visible height
        let maxHeight = yippyTableView.visibleRect.height
        // Calculate cell height
        let height = min(imageHeight + imagePadding.yTotal + contentViewInsets.xTotal, maxHeight)
        
        return ceil(height)
    }
    
    static func makeItem() -> YippyItem {
        return YippyTiffCellView(frame: .zero)
    }
}
