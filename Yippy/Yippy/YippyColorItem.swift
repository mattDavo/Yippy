//
//  YippyColorItem.swift
//  Yippy
//
//  Created by Matthew Davidson on 13/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class YippyColorItem: YippyTextItem {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        contentView.usesDynamicBackgroundColor = false
    }
    
    override class var identifier: NSUserInterfaceItemIdentifier {
        return NSUserInterfaceItemIdentifier("YippyColorItem")
    }
    
    override func setupCell(withHistoryItem historyItem: HistoryItem, atIndexPath indexPath: IndexPath) {
        super.setupCell(withHistoryItem: historyItem, atIndexPath: indexPath)
        
        if let color = historyItem.getColor()?.withAlphaComponent(1) {
            contentView.layer?.backgroundColor = color.cgColor
        }
    }
}
