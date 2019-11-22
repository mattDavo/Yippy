//
//  DataFileManager.swift
//  Yippy
//
//  Created by Matthew Davidson on 21/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation

class DataFileManager {
    
    func loadData(contentsOf url: URL) throws -> Data {
        return try Data(contentsOf: url)
    }
    
    func writeData(_ data: Data, to url: URL, options: Data.WritingOptions = []) throws {
        try data.write(to: url, options: options)
    }
}
