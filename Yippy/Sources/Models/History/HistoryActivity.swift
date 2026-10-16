//
//  HistoryActivity.swift
//  Yippy
//

import Foundation

/// What the user did to a history, as opposed to what Yippy did by itself (trimming to the limit, automatic cleaning, or
/// applying another device's changes). Sync sends these to the user's other devices.
///
/// Called on the main thread.
protocol HistoryActivity: AnyObject {
    
    /// Something was copied: a new item, or an item already in the history copied again (now at the top).
    func history(_ history: History, didCopy item: HistoryItem)
    
    /// The user is deleting these items, or replacing them with edited copies. Called while their content can still be read.
    func history(_ history: History, willDelete items: [HistoryItem])
    
    /// The user cleared the history.
    func historyDidClear(_ history: History)
    
    /// A favourite was added, renamed or edited.
    func history(_ history: History, didChangeFavourite item: HistoryItem)
}
