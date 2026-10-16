//
//  YippyHistory.swift
//  Yippy
//
//  Created by Matthew Davidson on 4/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class YippyHistory {
    
    let history: History
    var items: [HistoryItem]
    
    let pasteboard: NSPasteboard
    
    /// Whether pasting an item moves it to the top. True for the clipboard history, false for favourites, which keep their order.
    let movesPastedItemToTop: Bool
    
    init(history: History, items: [HistoryItem], pasteboard: NSPasteboard = .general, movesPastedItemToTop: Bool = true) {
        self.history = history
        self.items = items
        self.pasteboard = pasteboard
        self.movesPastedItemToTop = movesPastedItemToTop
    }
    
    /// Finds where the item shown at `row` currently sits in the full history.
    ///
    /// `items` may be a filtered search result, so a row is not a history index.
    /// Looks the item up by id rather than trusting a stored index, because the history can change between
    /// building `items` and acting on it.
    func historyIndex(ofRow row: Int) -> Int? {
        guard items.indices.contains(row) else {
            return nil
        }
        let id = items[row].fsId
        return history.items.firstIndex(where: { $0.fsId == id })
    }
    
    /// Pastes the item shown at `selected`.
    ///
    /// - Parameter plainText: Paste only the item's text, without any styling. Items with no text are pasted as they are.
    func paste(selected: Int, plainText: Bool = false) {
        guard items.indices.contains(selected) else {
            return
        }
        paste(selected: selected, text: plainText ? items[selected].getUnstyledText() : nil)
    }
    
    /// Pastes `text` in place of the item shown at `selected`, which still moves to the top like any paste.
    ///
    /// - Parameter text: The text to paste, e.g. the item's text transformed. If nil the item itself is pasted.
    func paste(selected: Int, text plainString: String?) {
        guard let index = historyIndex(ofRow: selected) else {
            return
        }

        if movesPastedItemToTop {
            // Internally action the pasteboard change
            // Our pasteboard monitor will detect the change
            // But our `History` will know that it has already been consumed
            history.moveItem(at: index, to: 0)
            let newChangeCount = pasteboard.clearContents()
            history.recordPasteboardChange(withCount: newChangeCount)
        }
        else {
            // Leave the change for the clipboard history to pick up like any other copy
            pasteboard.clearContents()
        }
        
        // Write object
        if let plainString = plainString {
            pasteboard.setString(plainString, forType: .string)
        }
        else {
            pasteboard.writeObjects([items[selected]])
        }

        DispatchQueue.global().async {
            DispatchQueue.main.async {
                self.executePaste(startTime: Date())
            }
        }
    }
    
    private func executePaste(startTime: Date) {
        if NSApp.isActive {
            if Date().timeIntervalSince(startTime) > 2 {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.03) {
                self.executePaste(startTime: startTime)
            }
        }
        else {
            Helper.pressCommandV()
        }
    }
    
    /// Returns the next item to select
    func delete(selected: Int) -> Int? {
        guard let index = historyIndex(ofRow: selected) else {
            return nil
        }
        
        history.deleteItemByUser(at: index)
        if index == 0 && movesPastedItemToTop {
            // If we want to remove this, then we may have to change the `HistoryItem` writingOptions() to not `.promised`, because if something is pasted from history, then deleted, it can no longer satisfy the promise.
            // Only the clipboard history has its top item on the pasteboard. The favourites' order doesn't follow the pasteboard, so removing the first favourite must not wipe whatever was copied.
            pasteboard.clearContents()
        }
        
        // Assume no selection
        var select: Int? = nil
        // If the deleted item is not the last in the list then keep the selection index the same.
        if selected < items.count - 1 {
            select = selected
        }
        // Otherwise if there is any items left, select the previous item
        else if selected > 0 {
            select = selected - 1
        }
        // No items, select nothing
        else {
            select = nil
        }
        return select
    }
    
    func move(from: Int, to: Int) {
        // Rows keep their relative history order, so landing at row `to` means taking the history position of the item that was there.
        guard let fromIndex = historyIndex(ofRow: from), let toIndex = historyIndex(ofRow: to) else {
            return
        }
        
        history.moveItem(at: fromIndex, to: toIndex)
        
        if toIndex == 0 {
            let newChangeCount = pasteboard.clearContents()
            history.recordPasteboardChange(withCount: newChangeCount)
            
            // Write object
            pasteboard.writeObjects([items[from]])
        }
    }
}

