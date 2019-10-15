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
        pasteboard.clearContents()
        for (type, data) in history[selected].data {
            pasteboard.addTypes([type], owner: nil)
            pasteboard.setData(data, forType: type)
        }
        State.main.history.accept(history.without(elementAt: selected))
        Helper.pressCommandV()
    }
    
    func delete(selected: Int) {
        State.main.history.accept(history.without(elementAt: selected))
        if selected == 0 {
            NSPasteboard.general.clearContents()
        }
    }
}
