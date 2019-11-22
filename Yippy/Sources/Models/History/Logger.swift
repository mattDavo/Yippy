//
//  Logger.swift
//  Yippy
//
//  Created by Matthew Davidson on 17/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class Logger {
    
    var url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    func log(_ loggable: Loggable) {
        let timestamp = Timestamp()
        do {
            try "[\(timestamp)] \(loggable.logFileDescription)".appendLine(toURL: url)
        }
        catch {
            // Not much we can do
            print("Failed to log:")
        }
        print("[\(timestamp)]", loggable.consoleDescription)
    }
}

// https://stackoverflow.com/a/40687742
extension String {
   func appendLine(toURL url: URL) throws {
        try (self + "\n").append(toURL: url)
    }

    func append(toURL url: URL) throws {
        let data = self.data(using: String.Encoding.utf8)!
        try data.append(fileURL: url)
    }
}

// https://stackoverflow.com/a/40687742
extension Data {
    func append(fileURL: URL) throws {
        if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        }
        else {
            var isDirectory: ObjCBool = false
            let url = fileURL.deletingLastPathComponent()
            
            // Directory doesn't exist
            if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            }
            // Path exists but it's not a directory
            else if !isDirectory.boolValue {
                try FileManager.default.removeItem(at: url)
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            }
            // Directory is already set up.
            // Now write the file
            try write(to: fileURL, options: .atomic)
        }
    }
}

/// https://stackoverflow.com/a/51198997
class Timestamp: CustomStringConvertible {
    
    var date: Date
    
    init(date: Date = Date()) {
        self.date = date
    }
    
    static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    var description: String {
        return Self.dateFormatter.string(from: date)
    }
}
