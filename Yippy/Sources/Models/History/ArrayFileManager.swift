//
//  ArrayFileManager.swift
//  Yippy
//
//  Created by Matthew Davidson on 20/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation

class ArrayFileManager {
    
    var url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    func write(_ array: NSArray) throws {
        try Self.write(array, toUrl: url)
    }
    
    func read() -> NSArray? {
        Self.read(fromUrl: url)
    }
    
    static func write(_ array: NSArray, toUrl url: URL) throws {
        try array.write(to: url)
    }
    
    static func read(fromUrl url: URL) -> NSArray? {
        return NSArray(contentsOf: url)
    }
}
