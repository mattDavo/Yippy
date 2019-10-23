//
//  History.swift
//  Yippy
//
//  Created by Matthew Davidson on 16/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import RxSwift
import RxRelay

/// Representation of all the history
class History {
    
    private var items = [HistoryItem]()
    
    /// Behaviour relay for the last change count of the pasteboard.
    /// Private so that it cannot be manipulated outside of the class.
    private var _lastRecordedChangeCount = BehaviorRelay<Int>(value: -1)
    
    /// Observable for the last recorded change count of the pasteboard.
    var observableLastRecordedChangeCount: Observable<Int> {
        return _lastRecordedChangeCount.asObservable()
    }
    
    /// The last change count for which the items on the pasteboard have been added to the history.
    var lastRecordedChangeCount: Int {
        return _lastRecordedChangeCount.value
    }
    
    /// The file manager for the storage of pasteboard history.
    var historyFM: HistoryFileManager
    
    typealias InsertHandler = ([HistoryItem], Int) -> Void
    typealias DeleteHandler = ([HistoryItem], HistoryItem) -> Void
    typealias ClearHandler = () -> Void
    typealias MoveHandler = ([HistoryItem], Int, Int) -> Void
    typealias SubscribeHandler = ([HistoryItem]) -> Void
    
    private var insertObservers = [InsertHandler]()
    private var deleteObservers = [DeleteHandler]()
    private var clearObservers = [ClearHandler]()
    private var moveObservers = [MoveHandler]()
    private var subscribers = [SubscribeHandler]()
    
    init(historyFM: HistoryFileManager = .default, items: [HistoryItem]) {
        self.historyFM = historyFM
        self.items = items
    }
    
    static func load(historyFM: HistoryFileManager = .default, cache: HistoryCache) -> History {
        return historyFM.loadHistory(cache: cache)
    }
    
    func onInsert(handler: @escaping InsertHandler) {
        insertObservers.append(handler)
    }
    
    func onDelete(handler: @escaping DeleteHandler) {
        deleteObservers.append(handler)
    }
    
    func onClear(handler: @escaping ClearHandler) {
        clearObservers.append(handler)
    }
    
    func onMove(handler: @escaping MoveHandler) {
        moveObservers.append(handler)
    }
    
    func subscribe(onNext: @escaping SubscribeHandler) {
        subscribers.append(onNext)
        onNext(items)
    }
    
    func insertItem(_ item: HistoryItem, at i: Int) {
        items.insert(item, at: i)
        insertObservers.forEach({$0(items, i)})
        subscribers.forEach({$0(items)})
        historyFM.insertItem(newHistory: items, at: i)
    }
    
    func deleteItem(at i: Int) {
        let removed = items.remove(at: i)
        deleteObservers.forEach({$0(items, removed)})
        subscribers.forEach({$0(items)})
        historyFM.deleteItem(newHistory: items, deleted: removed)
    }
    
    func clear() {
        items.forEach({$0.stopCaching()})
        items = []
        clearObservers.forEach({$0()})
        subscribers.forEach({$0(items)})
        historyFM.clearHistory()
        
    }
    
    func moveItem(at i: Int, to j: Int) {
        let item = items.remove(at: i)
        items.insert(item, at: j)
        moveObservers.forEach({$0(items, i, j)})
        subscribers.forEach({$0(items)})
        historyFM.moveItem(newHistory: items, from: i, to: j)
    }
    
    func recordPasteboardChange(withCount changeCount: Int) {
        _lastRecordedChangeCount.accept(changeCount)
    }
}

extension History: PasteboardMonitorDelegate {
    
    func pasteboardDidChange(_ pasteboard: NSPasteboard) {
        // Check if we made this pasteboard change, if so, ignore
        if pasteboard.changeCount == State.main.history.lastRecordedChangeCount {
            return
        }
        
        // Check there are items on the pasteboard
        guard let items = pasteboard.pasteboardItems else {
            return
        }
        
        for item in items {
            // Only do anything if the pasteboard change includes having data
            if !item.types.isEmpty {
                var data = [NSPasteboard.PasteboardType: Data]()
                for type in item.types {
                    if let d = item.data(forType: type) {
                        data[type] = d
                    }
                    else {
                        print("Warning: new pasteboard data nil for type '\(type.rawValue)'")
                    }
                }
                let historyItem = HistoryItem(unsavedData: data, cache: State.main.historyCache)
                insertItem(historyItem, at: 0)
                let selected = (State.main.selected.value ?? -1) + 1
                State.main.selected.accept(selected)
            }
        }
        
        // Save pasteboard change count
        recordPasteboardChange(withCount: pasteboard.changeCount)
    }
}
