//
//  SyncPasteboardMapper.swift
//  Yippy
//
//  Converts between the pasteboard types an item is saved in and the formats it is synced in (Adapter).
//

import Cocoa

enum SyncPasteboardMapper {
    
    /// Pasteboard types that mean the item is copied files, which aren't synced: their paths mean nothing on another device.
    private static let fileTypes: Set<NSPasteboard.PasteboardType> = [
        .fileURL,
        NSPasteboard.PasteboardType("NSFilenamesPboardType"),
    ]
    
    private static let direct: [(type: NSPasteboard.PasteboardType, format: String)] = [
        (.string, SyncFormats.text),
        (.rtf, SyncFormats.rtf),
        (.html, SyncFormats.html),
        (.png, SyncFormats.png),
    ]
    
    /// The synced formats of an item with these types, reading each with `read`.
    ///
    /// - Returns: Empty if the item has none of the formats or is copied files; nil if its data can't be read.
    static func syncContent(types: [NSPasteboard.PasteboardType], read: (NSPasteboard.PasteboardType) -> Data?) -> SyncContent? {
        let types = Set(types)
        guard types.isDisjoint(with: fileTypes) else {
            return SyncContent([:])
        }
        var formats = [String: Data]()
        for (type, format) in direct where types.contains(type) {
            guard let data = read(type) else {
                return nil
            }
            formats[format] = data
        }
        // Screenshots and most apps copy images as TIFF; every platform reads PNG
        if formats[SyncFormats.png] == nil, types.contains(.tiff) {
            guard let tiff = read(.tiff) else {
                return nil
            }
            if let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                formats[SyncFormats.png] = png
            }
        }
        return SyncContent(formats)
    }
    
    /// The pasteboard data to save for synced content. Images get TIFF as well as PNG, since many apps only paste TIFF.
    static func pasteboardData(for content: SyncContent) -> [NSPasteboard.PasteboardType: Data] {
        var data = [NSPasteboard.PasteboardType: Data]()
        for (type, format) in direct {
            data[type] = content.formats[format]
        }
        if let png = content.formats[SyncFormats.png], let tiff = NSBitmapImageRep(data: png)?.tiffRepresentation {
            data[.tiff] = tiff
        }
        return data
    }
}
