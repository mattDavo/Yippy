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
    
    static func getItemSize(withCollectionView collectionView: NSCollectionView, forHistoryItem historyItem: HistoryItem) -> NSSize
    
    func setHighlight()
    
    func setupCell(withHistoryItem historyItem: HistoryItem, atIndexPath indexPath: IndexPath)
}
