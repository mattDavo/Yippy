//
//  HistoryFileManagerMock.swift
//  YippyTests
//
//  Created by Matthew Davidson on 21/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest
@testable import Yippy

class HistoryFileManagerMock: HistoryFileManager {
    
    var dataCallCount = 0
    var data = [UUID: [NSPasteboard.PasteboardType: Data]]()
    
    override func loadData(forItemWithId id: UUID, andType type: NSPasteboard.PasteboardType) -> Data? {
        dataCallCount += 1
        if let d = data[id]?[type] {
            return d
        }
        return nil
    }
}
