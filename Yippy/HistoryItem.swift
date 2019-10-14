//
//  HistoryItem.swift
//  Yippy
//
//  Created by Matthew Davidson on 9/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import Quartz

struct HistoryItem: Codable {
    
    var data: [NSPasteboard.PasteboardType: Data?] = [:]
    
    func getTiffImage() -> NSImage? {
        guard let tiffData = data[.tiff] as? Data else { return nil }
        return NSImage(data: tiffData)
    }
    
    func getPlainString() -> String? {
        guard let data = data[.string] as? Data  else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func getRtfAttributedString() -> NSAttributedString? {
        guard let data = data[.rtf] as? Data  else { return nil }
        return NSAttributedString(rtf: data, documentAttributes: nil)
    }
    
    func getHtmlString() -> String? {
        guard let data = data[.html] as? Data  else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func getUrl() -> URL? {
        guard let data = data[.URL] as? Data else { return nil }
        return URL(dataRepresentation: data, relativeTo: nil)
    }
    
    func getFileUrl() -> URL? {
        guard let data = data[.fileURL] as? Data else { return nil }
        return URL(dataRepresentation: data, relativeTo: nil)
    }
    
    func getPdf() -> PDFDocument? {
        guard let data = data[.pdf] as? Data else { return nil }
        return PDFDocument(data: data)
    }
    
    func getPng() -> NSImage? {
        guard let data = data[.png] as? Data else { return nil }
        return NSImage(data: data)
    }
    
    func getThumnailImage() -> NSImage? {
        guard let url = getFileUrl() else { return nil }
        let ref = QLThumbnailCreate(kCFAllocatorDefault, url as CFURL, CGSize(width: 300, height: 300), [kQLThumbnailOptionIconModeKey: true] as CFDictionary)
        
        guard let thumbnail = ref?.takeRetainedValue() else { return nil }
        let cgImageRef = QLThumbnailCopyImage(thumbnail)
        guard let cgImage = cgImageRef?.takeRetainedValue() else { return nil }
        return NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
    }
    
    func getFileIcon() -> NSImage? {
        guard let url = getFileUrl() else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    
    func getColor() -> NSColor? {
        guard let data = data[.color] as? Data else { return nil }
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(rawValue: "YippyBeta.ColorTest"))
        pasteboard.declareTypes([.color], owner: nil)
        pasteboard.setData(data, forType: .color)
        return NSColor(from: pasteboard)
    }
}

extension HistoryItem: Equatable {
    
    // TODO: Do I even need to implement this?
    static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs.data.count != rhs.data.count {
            return false
        }
        
        let lhsKeys = lhs.data.keys.sorted(by: {return $0.rawValue < $1.rawValue})
        let rhsKeys = rhs.data.keys.sorted(by: {return $0.rawValue < $1.rawValue})
        
        for (lType, rType) in zip(lhsKeys, rhsKeys) {
            if lType != rType {
                return false
            }
            if lhs.data[lType] != rhs.data[rType] {
                return false
            }
        }
        
        return true
    }
}
