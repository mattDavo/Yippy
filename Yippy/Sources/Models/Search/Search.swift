//
//  Search.swift
//  Yippy
//
//  Created by Matthew Davidson on 6/9/20.
//  Copyright © 2020 MatthewDavidson. All rights reserved.
//

import Foundation

// Adapted from: https://github.com/khoi/fuzzy-swift/blob/master/Sources/Fuzzy/Fuzzy.swift
public func performSearch(needle: String, haystack: String) -> Bool {
    guard needle.count <= haystack.count else {
        return false
    }

    if needle == haystack {
        return true
    }

    var needleIdx = needle.startIndex
    var haystackIdx = haystack.startIndex

    while needleIdx != needle.endIndex {
        if haystackIdx == haystack.endIndex {
            return false
        }
        if String(needle[needleIdx]).localizedCaseInsensitiveCompare(String(haystack[haystackIdx])) == .orderedSame {
            needleIdx = needle.index(after: needleIdx)
        }
        haystackIdx = haystack.index(after: haystackIdx)
    }

    return true
}
