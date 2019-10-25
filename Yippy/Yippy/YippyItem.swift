//
//  YippyItem.swift
//  Yippy
//
//  Created by Matthew Davidson on 11/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

protocol YippyItem {
    
    static var identifier: NSUserInterfaceItemIdentifier { get }
    
    static func getItemHeight(withTableView tableView: NSTableView, forHistoryItem historyItem: HistoryItem) -> CGFloat
    
    func setHighlight(isSelected: Bool)
    
    func setupCell(withTableView tableView: NSTableView, forHistoryItem historyItem: HistoryItem, atIndexPath indexPath: IndexPath)
    
    static func makeItem() -> YippyItem
}
