//
//  HistoryCache.swift
//  Yippy
//
//  Created by Matthew Davidson on 16/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

/// Cache for history.
class HistoryCache {
    
    // MARK: - Private structures
    
    /// Struct identifiying what data was used when.
    private struct Usage {
        var id: UUID
        var type: NSPasteboard.PasteboardType
    }
    
    
    // MARK: - Private attributes
    
    /// Cached data
    private var data = [UUID: [NSPasteboard.PasteboardType: Data]]()
    
    /// Queue identifying the usage of data, so that when it becomes full the least recently used can be removed from the cache. The first item in the list is the next item to be removed.
    private var usage = [Usage]()
    
    /// Private variable for the current amount of data in bytes stored in the cache.
    private var _currentCacheSize = 0
    
    
    // MARK: - Public attributes
    
    /// The maximum amount of the data stored in the cache in bytes.
    ///
    /// Defaults to 100 MB.
    let maxCacheSize: Int
    
    /// Public getter for the current amount of data in bytes stored in the cache.
    var currentCacheSize: Int {
        return _currentCacheSize
    }
    
    /// The file manager for the storage of pasteboard history.
    var historyFM: HistoryFileManager
    
    /// The error logger for the class.
    var errorLogger: ErrorLogger
    
    /// The error logger for the class.
    var warningLogger: WarningLogger
    
    
    // MARK: - Constructor
    
    init(
        historyFM: HistoryFileManager = .default,
        maxCacheSize: Int = 100000000,
        errorLogger: ErrorLogger = .general,
        warningLogger: WarningLogger = .general
    ) {
        self.historyFM = historyFM
        self.maxCacheSize = maxCacheSize
        self.errorLogger = errorLogger
        self.warningLogger = warningLogger
    }
    
    
    // MARK: - Public methods
    
    /// Returns the data for given item and type
    ///
    /// The item must be first registered with the cache. If the data has already been loading into the cache it is returned right away. Otherwise it is tried to be fetched from file, and cache for future use.
    ///
    /// If the data is too large for the cache it will not be cache but just returned.
    ///
    /// If the cache is full, cached data will be evicted until there is room.
    ///
    /// - Parameter id: The id of the item to retrieve data.
    /// - Parameter type: The type of data to retrieve.
    /// - Returns: The data if successful.
    ///
    func data(withId id: UUID, forType type: NSPasteboard.PasteboardType) -> Data? {
        // Try and get the data from the cache.
        if let data = data[id]?[type] {
            usedData(withId: id, andType: type)
            return data
        }
        // Get the data from file, save to cache and return
        guard let data = historyFM.loadData(forItemWithId: id, andType: type) else {
            return nil
        }
        // If we're not caching the item, just return the data
        if !isItemRegistered(id) {
            return data
        }
        // Check data size
        // TODO: Might want to optimize this, doesn't make much sense to cache if it's taking up 99% of the room anyway
        if data.count > maxCacheSize {
            // So large we can't store it in our cache
            return data
        }
        // Remove LRU data until there is enough room
        while data.count + currentCacheSize > maxCacheSize {
            removeLRU()
        }
        // Save to cache
        self.data[id]![type] = data
        // Record usage
        usedData(withId: id, andType: type)
        // Increase current cache size
        _currentCacheSize += data.count
        return data
    }
    
    /// Registers the item with the given id to be cached.
    ///
    /// This __must__ be done before data can be retrieved.
    ///
    /// - Parameter id: the id of the item to regsiter for caching.
    func registerItem(withId id: UUID) {
        if !data.keys.contains(id) {
            data[id] = [:]
        }
    }
    
    /// Unregisters the item with the given id from caching.
    ///
    /// This will remove data from the cache, and any calls to `data(id:type:)` after will be unsuccessful until it is registered again.
    ///
    /// - Parameter id: the id of the item to unregsiter from caching.
    func unregisterItem(withId id: UUID) {
        if let data = data.removeValue(forKey: id) {
            _currentCacheSize -= data.reduce(0, {$0 + $1.value.count})
            usage.removeAll(where: {$0.id == id})
        }
    }
    
    /// Returns whether an item is registered in the cache or not.
    ///
    /// - Parameter id: The id of the item to register.
    /// - Returns: `true` if the item is registered, `false` otherwise.
    func isItemRegistered(_ id: UUID) -> Bool {
        return data.keys.contains(id)
    }
    
    
    // MARK: - Private methods
    
    /// Records cached data has been used, updating the usage queue.
    ///
    /// - Parameter id: The id of the item data retrieved.
    /// - Parameter type: The type of data retrieved.
    private func usedData(withId id: UUID, andType type: NSPasteboard.PasteboardType) {
        // See if we've used the data before, if so, moved it to the back of the queue
        if let i = usage.firstIndex(where: {$0.id == id && $0.type == type}) {
            let usage = self.usage.remove(at: i)
            self.usage.append(usage)
        }
        // Data must be new to the cache, add it to the back of the queue.
        else {
            self.usage.append(Usage(id: id, type: type))
        }
    }
    
    /// Removes the least recently used data in the cache.
    private func removeLRU() {
        let removed = usage.removeFirst()
        if data.keys.contains(removed.id) && data[removed.id]!.keys.contains(removed.type) {
            _currentCacheSize -= data[removed.id]!.removeValue(forKey: removed.type)!.count
        }
        else {
            YippyError(localizedDescription: "Error: Didn't find data with type \(removed.type.rawValue) for item with id \(removed.id.uuidString) to remove from the cache.").log(with: errorLogger)
        }
    }
}
