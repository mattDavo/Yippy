//
//  YippyHistoryView.swift
//  Yippy
//
//  Created by Matthew Davidson on 2/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class YippyHistoryView: NSTableView {
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        commonInit()
    }
    
    private func commonInit() {
        selectionHighlightStyle = .none
        allowsMultipleSelection = false
        
        intercellSpacing = NSSize(width: 40, height: 5)
        setAccessibilityIdentifier(Accessibility.identifiers.yippyTableView)
    }
    
    var selected: Int? {
        return self.selectedRowIndexes.first
    }
    
    func selectItem(_ i: Int) {
        let items = IndexSet(arrayLiteral: i)
        selectRowIndexes(items, byExtendingSelection: false)
        scrollRowToVisible(items.first!)
    }
    
    func deselectItem(_ i: Int) {
        deselectRow(i)
    }
    
    func reloadItem(_ i: Int) {
        reloadData(forRowIndexes: IndexSet(arrayLiteral: i), columnIndexes: IndexSet(arrayLiteral: 0))
    }
    
    func redisplayVisible(yippyHistory: YippyHistory) {
        let vis = visibleRect
        let range = rows(in: vis)
        for row in range.location..<range.location+range.length {
            guard let cell = view(atColumn: 0, row: row, makeIfNecessary: false) as? YippyItem else { continue }
            cell.setupCell(withTableView: self, forHistoryItem: yippyHistory.history[row], atIndexPath: IndexPath(item: row, section: 0))
        }
    }
}
