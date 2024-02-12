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
    
    var cellHeightsCache = CellHeightsCache()
    
    var isRichText: Bool = true
    
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
        
        registerForDraggedTypes([HistoryItem.historyItemIdType])
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
    
    func reloadData(_ data: [HistoryItem], isRichText: Bool) {
        yippyItems = data
        self.isRichText = isRichText
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
        if context == .outsideApplication {
            return NSDragOperation.copy
        }
        else {
            return .move
        }
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        }
        else {
            return []
        }
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        
        var id: UUID?
        info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) { dragItem, _, _ in
            
            if let idStr = (dragItem.item as! NSPasteboardItem).string(forType: HistoryItem.historyItemIdType) {
                id = UUID(uuidString: idStr)
            }
        }
        
        guard let droppedId = id else {
            return false
        }
        
        guard let originalIndex = yippyItems.map({ $0.fsId }).firstIndex(of: droppedId) else {
            return false
        }
        
        let newIndex = originalIndex < row ? row - 1 : row
        
        if originalIndex == newIndex {
            return false
        }
        
        CATransaction.begin()
        CATransaction.setCompletionBlock({
            self.reloadData(forRowIndexes: IndexSet(integersIn: 0..<10), columnIndexes: IndexSet(arrayLiteral: 0))
            if let delegate = self.yippyDelegate {
                delegate.yippyTableView(self, didMoveItem: originalIndex, to: newIndex)
            }
        })
        tableView.beginUpdates()
        
        let removed = yippyItems.remove(at: originalIndex)
        
        tableView.moveRow(at: originalIndex, to: newIndex)
        yippyItems.insert(removed, at: newIndex)
        
        tableView.endUpdates()
        CATransaction.commit()

        return true
    }
}

extension YippyTableView: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let historyItem = yippyItems[row]
        let itemType = historyItem.getTableViewItemType()
        
        if let height = cellHeightsCache.cellHeight(forId: historyItem.fsId, withCellIdentifier: itemType.identifier.rawValue, cellWidth: cellWidth, isRichText: isRichText) {
            return height
        }
        
        let height = historyItem.getTableViewItemType().getItemHeight(withYippyTableView: tableView as! YippyTableView, forHistoryItem: historyItem)
        
        cellHeightsCache.storeCellHeight(height, forId: historyItem.fsId, withCellIdentifier: itemType.identifier.rawValue, cellWidth: cellWidth, isRichText: isRichText)
        
        return height
    }
}
