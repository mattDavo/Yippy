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
    
    static func getItemHeight(withYippyTableView yippyTableView: YippyTableView, forHistoryItem historyItem: HistoryItem) -> CGFloat
    
    func setHighlight(isSelected: Bool)
    
    func setupCell(withYippyTableView yippyTableView: YippyTableView, forHistoryItem historyItem: HistoryItem, at i: Int)
    
    static func makeItem() -> YippyItem
}
