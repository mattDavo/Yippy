//
//  CellHeightCache.swift
//  Yippy
//
//  Created by Matthew Davidson on 7/2/20.
//  Copyright © 2020 MatthewDavidson. All rights reserved.
//

import Foundation

class CellHeightsCache {
    
    struct Context: Equatable {
        var cellWidth: CGFloat
    }
    
    var caches: [String: Cache<CGFloat, UUID, Context>]
    
    
    init() {
        caches = [:]
    }
    
    func createCache(forCellIdentifier cellIdentifier: String) {
        caches[cellIdentifier] = Cache()
    }
    
    func cellHeight(forId id: UUID, withCellIdentifier cellIdentifier: String, cellWidth: CGFloat) -> CGFloat? {
        if !caches.keys.contains(cellIdentifier) {
            createCache(forCellIdentifier: cellIdentifier)
        }
        
        return caches[cellIdentifier]?.cellHeight(forId: id, withContext: Context(cellWidth: cellWidth))
    }
    
    func storeCellHeight(_ height: CGFloat, forId id: UUID, withCellIdentifier cellIdentifier: String, cellWidth: CGFloat) {
        if !caches.keys.contains(cellIdentifier) {
            createCache(forCellIdentifier: cellIdentifier)
        }
        
        caches[cellIdentifier]?.storeCellHeight(height, forId: id, withContext: Context(cellWidth: cellWidth))
    }
    
    func removeCellHeight(forId id: UUID) {
        for (k,_) in caches {
            caches[k]?.removeCellHeight(forId: id)
        }
    }
    
    func clearCache() {
        for (k,_) in caches {
            caches[k]?.clearCache()
        }
    }
}
