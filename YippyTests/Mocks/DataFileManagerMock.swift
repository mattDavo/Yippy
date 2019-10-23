//
//  DataFileManagerMock.swift
//  YippyTests
//
//  Created by Matthew Davidson on 21/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest
@testable import Yippy

class DataFileManagerMock: DataFileManager {
    
    var writeDataSucceeds = [URL: Bool]()
    var loadData = [URL: Data]()
    
    override func writeData(_ data: Data, to url: URL, options: Data.WritingOptions = []) throws {
        if writeDataSucceeds[url] == nil || writeDataSucceeds[url] == false {
            throw NSError(domain: "FileManagerTests", code: 0)
        }
    }
    
    override func loadData(contentsOf url: URL) throws -> Data {
        if let data = loadData[url] {
            return data
        }
        throw NSError(domain: "FileManagerTests", code: 0)
    }
}
