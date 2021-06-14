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

/// Interface for an item that was on the pasteboard
class HistoryItem: NSObject {
    
    // MARK: - Private attributes
    
    /// Private variable for data that hasn't yet been saved to disk.
    private var _unsavedData: [NSPasteboard.PasteboardType: Data]?
    
    
    // MARK: - Public attributes
    
    /// The types of pasteboard data the item contains.
    let types: [NSPasteboard.PasteboardType]
    
    /// Data for the item that hasn't yet been saved to disk.
    ///
    /// This will be become `nil` when `startCaching()` is called to release it from memory.
    ///
    /// If you expect to need the items data after a call to `stopCaching(unsavedData:)` and the data is not saved to disk then you should should provide the data as an argument to `stopCaching(unsavedData:)`.
    var unsavedData: [NSPasteboard.PasteboardType: Data]? {
        return _unsavedData
    }
    
    /// The cache to load data from when requesting data and using caching.
    var cache: HistoryCache
    
    /// File system id. Unique name of the folder contains the data for this item
    let fsId: UUID
    
    /// Whether the item is being cached.
    var isCached: Bool {
        return cache.isItemRegistered(fsId)
    }
    
    static let historyItemIdType = NSPasteboard.PasteboardType(rawValue: "MatthewDavidson.Yippy.historyItemId")
    
    /// Static definition of whether the history items should write RTF data to the pasteboard.
    ///
    /// This value is used when determining the writable types for an item.
    static var pastesRichText = true
    
    
    // MARK: - Constructors
    
    /// Creates a `HistoryItem` for an item that has not been saved to disk yet.
    ///
    /// It will be initialised with a unique id.
    ///
    /// - Parameter unsavedData: Pastebaord data that has not yet been saved to disk.
    /// - Parameter cache: `HistoryCache` to use for caching if this item starts using caching.
    init(unsavedData: [NSPasteboard.PasteboardType: Data], cache: HistoryCache) {
        self._unsavedData = unsavedData
        self.types = unsavedData.keys.map({$0})
        self.cache = cache
        self.fsId = UUID()
    }
    
    /// Creates a `HistoryItem` for an item that is saved to disk.
    ///
    /// - Parameter fsId: The unique id of the item.
    /// - Parameter types: The types of pasteboard data that this item contains.
    /// - Parameter cache: `HistoryCache` to use for caching.
    init(fsId: UUID, types: [NSPasteboard.PasteboardType], cache: HistoryCache) {
        self.fsId = fsId
        self._unsavedData = nil
        self.types = types
        self.cache = cache
        self.cache.registerItem(withId: fsId)
    }
    
    
    // MARK: - Public methods
    
    /// Returns the data for given type.
    ///
    /// If the data is available in `unsavedData` it will be returned.
    /// Otherwise if the item is not being cached, the data will be loaded from disk using the cache, but it will not be cached.
    /// Otherwise it will use the cache to get the data.
    ///
    /// - Parameter type: The type of pasteboard data to get.
    /// - Returns: The data if successful, otherwise `nil`.
    ///
    func data(forType type: NSPasteboard.PasteboardType) -> Data? {
        if !types.contains(type) {
            return nil
        }
        if let data = unsavedData, data.keys.contains(type) {
            return data[type]
        }
        return cache.data(withId: fsId, forType: type)
    }
    
    /// Requests all the data for the item.
    ///
    /// - Returns: A dictionary of all the data by calling `data(forType:)`.
    func allData() -> [NSPasteboard.PasteboardType: Data?] {
        var data = [NSPasteboard.PasteboardType: Data?]()
        for type in types {
            data[type] = self.data(forType: type)
        }
        return data
    }
    
    /// Starts caching the item.
    ///
    /// Deallocates the `unsavedData`. Assumes that the data has been saved to disk.
    func startCaching() {
        _unsavedData = nil
        cache.registerItem(withId: fsId)
    }
    
    /// Stops caching the item.
    ///
    /// - Parameter unsavedData: If the item's data is writen to disk this parameter can be ignored. But if itsn't then the `unsavedData` should be provided so it isn't lost.
    func stopCaching(unsavedData: [NSPasteboard.PasteboardType: Data]? = nil) {
        self._unsavedData = unsavedData
        cache.unregisterItem(withId: fsId)
    }
    
    func getImage() -> NSImage? {
        if let image = getTiffImage() {
            return image
        }
        if let image = getPng() {
            return image
        }
        return nil
    }
    
    func getTiffImage() -> NSImage? {
        guard let tiffData = data(forType: .tiff) else { return nil }
        return NSImage(data: tiffData)
    }
    
    func getPlainString() -> String? {
        guard let data = data(forType: .string) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func getRtfAttributedString() -> NSAttributedString? {
        guard let data = data(forType: .rtf) else { return nil }
        return NSAttributedString(rtf: data, documentAttributes: nil)
    }
    
    func getHtmlRawString() -> String? {
        guard let data = data(forType: .html) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func getHtmlAttributedString() -> NSAttributedString? {
        guard let data = data(forType: .html) else { return nil }
        return NSAttributedString(html: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil)
    }
    
    func getUrl() -> URL? {
        guard let data = data(forType: .URL) else { return nil }
        return URL(dataRepresentation: data, relativeTo: nil)
    }
    
    func getFileUrl() -> URL? {
        guard let data = data(forType: .fileURL) else { return nil }
        return URL(dataRepresentation: data, relativeTo: nil)
    }
    
    func getPdf() -> PDFDocument? {
        guard let data = data(forType: .pdf) else { return nil }
        return PDFDocument(data: data)
    }
    
    func getPng() -> NSImage? {
        guard let data = data(forType: .png) else { return nil }
        return NSImage(data: data)
    }
    
    func getThumbnailImage() -> NSImage? {
        var image: NSImage?
        DispatchQueue.global(qos: .userInteractive).sync {
            guard let url = getFileUrl() else { return }
            let ref = QLThumbnailCreate(kCFAllocatorDefault, url as CFURL, CGSize(width: 300, height: 300), [kQLThumbnailOptionIconModeKey: true] as CFDictionary)
            
            guard let thumbnail = ref?.takeRetainedValue() else { return }
            let cgImageRef = QLThumbnailCopyImage(thumbnail)
            guard let cgImage = cgImageRef?.takeRetainedValue() else { return }
            image = NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
        }
        return image
        
        
    }
    
    func getFileIcon() -> NSImage? {
        guard let url = getFileUrl() else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    
    func getColor() -> NSColor? {
        guard let data = data(forType: .color) else { return nil }
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(rawValue: "YippyBeta.ColorTest"))
        pasteboard.declareTypes([.color], owner: nil)
        pasteboard.setData(data, forType: .color)
        return NSColor(from: pasteboard)
    }
    
    private func isStringLink(string: String) -> Bool {
        let types: NSTextCheckingResult.CheckingType = [.link]
        let detector = try? NSDataDetector(types: types.rawValue)
        guard (detector != nil && string.count > 0) else { return false }
        if detector!.numberOfMatches(in: string, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, string.count)) > 0 {
            return true
        }
        return false
    }
    
    private let richTextPasteboardTypes = [
        NSPasteboard.PasteboardType.rtf.rawValue,
        NSPasteboard.PasteboardType.html.rawValue,
        "public.utf16-external-plain-text",
        "org.chromium.web-custom-data",
    ]
}

// MARK: - HistoryItem+NSPasteboardWriting
extension HistoryItem: NSPasteboardWriting {
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return types.filter{
            HistoryItem.pastesRichText || !richTextPasteboardTypes.contains($0.rawValue)
        } + [Self.historyItemIdType]
    }
    
    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        if type == Self.historyItemIdType {
            return fsId.uuidString
        }
        return data(forType: type)
    }
    
    func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions {
        return .promised
    }
}
