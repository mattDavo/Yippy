//
//  YippyTiffItem.swift
//  Yippy
//
//  Created by Matthew Davidson on 17/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class YippyTiffItem: YippyItemBase, YippyItem {
    
    static let identifier = NSUserInterfaceItemIdentifier("YippyTiffItem")
    
    static let imagePadding = NSEdgeInsetsZero
    
    var tiffView: NSImageView!
    
    override func loadView() {
        super.loadView()
        
        tiffView = NSImageView(frame: .zero)
        contentView.addSubview(tiffView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
    
    func willDisplayCell(withHistoryItem historyItem: HistoryItem, atIndexPath indexPath: IndexPath) {
        setHighlight()
    }
    
    func setupCell(withHistoryItem historyItem: HistoryItem, atIndexPath indexPath: IndexPath) {
        setupShortcutTextView(atIndexPath: indexPath)
        
        tiffView.image = historyItem.getTiffImage()
    }
    
    static func getItemSize(withCollectionView collectionView: NSCollectionView, forHistoryItem historyItem: HistoryItem) -> NSSize {
        // Calculate the width of the cell
        let cellWidth = floor(collectionView.frame.width - sectionInset.left - sectionInset.right)
        
        guard let image = historyItem.getTiffImage() else {
            return CGSize(width: cellWidth, height: 50)
        }
        
        let imageWidth = cellWidth - imagePadding.xTotal - contentViewInsets.xTotal
        
        // Get max image height based on pixels
        let maxImageHeight = image.size.height
        // Calcalute image height
        let imageHeight = min(image.size.height * imageWidth / image.size.width, maxImageHeight)
        
        // Get max height of cell based on visible on visible height
        let maxHeight = collectionView.visibleRect.height
        // Calculate cell height
        let height = min(imageHeight + imagePadding.yTotal + contentViewInsets.xTotal, maxHeight)
        
        return NSSize(width: cellWidth, height: height)
    }
}
