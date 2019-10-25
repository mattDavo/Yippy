//
//  YippyColorCellView.swift
//  Yippy
//
//  Created by Matthew Davidson on 13/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class YippyColorCellView: YippyTextCellView {
    
    override class var identifier: NSUserInterfaceItemIdentifier {
        return NSUserInterfaceItemIdentifier(Accessibility.identifiers.yippyColorCellView)
    }
    
    override func commonInit() {
        super.commonInit()
        
        identifier = Self.identifier
        
        contentView.usesDynamicBackgroundColor = false
    }
    
    override func setupCell(withYippyTableView yippyTableView: YippyTableView, forHistoryItem historyItem: HistoryItem, at i: Int) {
        super.setupCell(withYippyTableView: yippyTableView, forHistoryItem: historyItem, at: i)
        
        if let color = historyItem.getColor()?.withAlphaComponent(1) {
            contentView.layer?.backgroundColor = color.cgColor
        }
    }
    
    override class func makeItem() -> YippyItem {
        return YippyColorCellView(frame: .zero)
    }
}
