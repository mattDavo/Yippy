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
    
    var history: [String]
    
    init(history: [String]) {
        self.history = history
    }
    
    func paste(selected: Int) {
        if selected != 0 {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
            pasteboard.setString(history[selected], forType: NSPasteboard.PasteboardType.string)
            State.main.history.accept(history.without(elementAt: selected))
        }
        Helper.pressCommandV()
    }
    
    func delete(selected: Int) {
        if selected == 0 {
            NSPasteboard.general.clearContents()
        }
        State.main.history.accept(history.without(elementAt: selected))
    }
}
