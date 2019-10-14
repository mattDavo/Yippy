//
//  YippyFileThumbnailItem.swift
//  Yippy
//
//  Created by Matthew Davidson on 11/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import QuickLook
import Quartz

class YippyFileThumbnailItem: YippyItemBase, YippyItem {
    
    static let identifier = NSUserInterfaceItemIdentifier("YippyFileThumbnailItem")
    
    static let fileNamePadding = NSEdgeInsets(top: 10, left: 5, bottom: 10, right: 5)
    
    static let imageSize = NSSize(width: 300, height: 200)
    
    static let imageTopPadding: CGFloat = 5
    
    static let fileNameTextAttributes: [NSAttributedString.Key: Any] = [
        .font: Fonts.yippyFileNameText,
        .foregroundColor: NSColor.textColor
    ]
    
    var previewView: NSImageView!
    
    override func loadView() {
        super.loadView()
        
        previewView = NSImageView(frame: .zero)
        contentView.addSubview(previewView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupPreviewView()
        setupItemTextView()
    }
    
    func setupPreviewView() {
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.imageAlignment = .alignCenter
        contentView.addConstraint(NSLayoutConstraint(item: previewView!, attribute: .top, relatedBy: .equal, toItem: contentView, attribute: .top, multiplier: 1, constant: Self.imageTopPadding))
        previewView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        previewView.widthAnchor.constraint(equalToConstant: Self.imageSize.width).isActive = true
        previewView.heightAnchor.constraint(equalToConstant: Self.imageSize.height).isActive = true
    }
    
    func setupItemTextView() {
        itemTextView.translatesAutoresizingMaskIntoConstraints = false
        itemTextView.alignment = .center
        itemTextView.textContainer?.lineFragmentPadding = 0
        itemTextView.textContainerInset = .zero
        contentView.addConstraint(NSLayoutConstraint(item: itemTextView!, attribute: .top, relatedBy: .equal, toItem: previewView, attribute: .bottom, multiplier: 1, constant: Self.fileNamePadding.top))
        contentView.addConstraint(NSLayoutConstraint(item: itemTextView!, attribute: .leading, relatedBy: .equal, toItem: contentView, attribute: .leading, multiplier: 1, constant: Self.fileNamePadding.left))
        contentView.addConstraint(NSLayoutConstraint(item: contentView!, attribute: .trailing, relatedBy: .equal, toItem: itemTextView, attribute: .trailing, multiplier: 1, constant: Self.fileNamePadding.right))
        contentView.addConstraint(NSLayoutConstraint(item: contentView!, attribute: .bottom, relatedBy: .equal, toItem: itemTextView, attribute: .bottom, multiplier: 1, constant: Self.fileNamePadding.bottom))
    }
    
    func setupCell(withHistoryItem historyItem: HistoryItem, atIndexPath indexPath: IndexPath) {
        guard let url = historyItem.getFileUrl() else { return }
        
        itemTextView.attributedText = NSAttributedString(string: url.path, attributes: Self.fileNameTextAttributes)
        
        Thread.detachNewThread {
            
            let cgImageRef = QLThumbnailImageCreate(kCFAllocatorDefault, url as CFURL, CGSize(width: 200, height: 200), [kQLThumbnailOptionIconModeKey: false, kQLThumbnailOptionScaleFactorKey: 4] as CFDictionary)
            
            DispatchQueue.main.async {
                if let cgImage = cgImageRef?.takeRetainedValue() {
                    let image = NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
                    self.previewView.image = image
                }
                else {
                    self.previewView.image = nil
                }
            }
        }
    }
    
    static func getItemSize(withCollectionView collectionView: NSCollectionView, forHistoryItem historyItem: HistoryItem) -> NSSize {
        // Calculate the width of the cell
        let cellWidth = floor(collectionView.frame.width - sectionInset.left - sectionInset.right)
        
        // Calculate the text container width
        let textContainerWidth = cellWidth - contentViewInsets.xTotal - fileNamePadding.xTotal
        
        // Create the attributed string
        let str = NSAttributedString(string: historyItem.getFileUrl()!.path, attributes: fileNameTextAttributes)
        
        // Calculate the height of the text
        let bRect = str.boundingRect(with: NSSize(width: textContainerWidth, height: 100000), options: NSString.DrawingOptions.usesLineFragmentOrigin.union(.usesFontLeading))
        
        // Calculate the height of the cell
        let height = bRect.height + contentViewInsets.yTotal + fileNamePadding.yTotal + imageSize.height + imageTopPadding
        
        return NSSize(width: cellWidth, height: height)
    }
}
