//
//  YippyTableView.swift
//  Yippy
//
//  Created by Matthew Davidson on 2/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class YippyTableView: NSTableView {
    
    var yippyItems = [HistoryItem]()
    
    var yippyDelegate: YippyTableViewDelegate?
    
    var cellWidth: CGFloat {
        return tableColumns[0].width
    }
    
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
        
        delegate = self
        dataSource = self
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
    
    func redisplayVisible(yippyItems: [HistoryItem]) {
        let vis = visibleRect
        let range = rows(in: vis)
        for row in range.location..<range.location+range.length {
            guard let cell = view(atColumn: 0, row: row, makeIfNecessary: false) as? YippyItem else { continue }
            cell.setupCell(withYippyTableView: self, forHistoryItem: yippyItems[row], at: row)
        }
    }
    
    func reloadData(_ data: [HistoryItem]) {
        yippyItems = data
        reloadData()
    }
}

extension YippyTableView: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return yippyItems.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let historyItem = yippyItems[row]
        let itemType = historyItem.getTableViewItemType()
        let cell = tableView.makeView(withIdentifier: itemType.identifier, owner: nil) as? YippyItem ?? itemType.makeItem()
        cell.setupCell(withYippyTableView: self, forHistoryItem: historyItem, at: row)
        if let cell = cell as? NSTableCellView {
            cell.setAccessibilityLabel(itemType.identifier.rawValue)
            cell.identifier = itemType.identifier
        }
        return cell as? NSView
    }
    
    func tableViewSelectionIsChanging(_ notification: Notification) {
        if let delegate = yippyDelegate {
            delegate.yippyTableView(self, selectedDidChange: selected)
        }
    }
    
    func tableViewColumnDidResize(_ notification: Notification) {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<yippyItems.count))
        NSAnimationContext.endGrouping()
        redisplayVisible(yippyItems: yippyItems)
    }
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        return yippyItems[row]
    }
    
    override func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return NSDragOperation.copy
    }
}

extension YippyTableView: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let historyItem = yippyItems[row]
        return historyItem.getTableViewItemType().getItemHeight(withYippyTableView: tableView as! YippyTableView, forHistoryItem: historyItem)
    }
}
