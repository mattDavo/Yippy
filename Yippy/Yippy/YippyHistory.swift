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
    
    var history: [HistoryItem]
    
    init(history: [HistoryItem]) {
        self.history = history
    }
    
    func paste(selected: Int) {
        let pasteboard = NSPasteboard.general
        
        // Internally action the pasteboard change
        // Our pasteboard monitor will detect the change
        // But our `History` will know that it has already been consumed
        State.main.history.moveItem(at: selected, to: 0)
        let newChangeCount = pasteboard.clearContents()
        State.main.history.recordPasteboardChange(withCount: newChangeCount)
        
        // Write object
        pasteboard.writeObjects([history[selected]])
        
        Helper.pressCommandV()
    }
    
    func delete(selected: Int) {
        State.main.history.deleteItem(at: selected)
        if selected == 0 {
            // If we want to remove this, then we may have to change the `HistoryItem` writingOptions() to not `.promised`, because if something is pasted from history, then deleted, it can no longer satisfy the promise.
            NSPasteboard.general.clearContents()
        }
    }
}
