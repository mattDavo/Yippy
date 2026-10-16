//
//  Constants.swift
//  Yippy
//
//  Created by Matthew Davidson on 7/8/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

struct Constants {
    
    struct panel {
        static let menuWidth: CGFloat = 400
        static let menuHeight: CGFloat = 300
        static let maxCellHeight: CGFloat = 200
    }
    
    struct statusItemMenu {
        static let deleteKeyEquivalent = NSString(format: "%c", NSDeleteCharacter) as String
        static let leftArrowKeyEquivalent = NSString(format: "%C", 0x001c) as String
        static let rightArrowKeyEquivalent = NSString(format: "%C", 0x001d) as String
        static let downArrowKeyEquivalent = NSString(format: "%C", 0x001f) as String
        static let upArrowKeyEquivalent = NSString(format: "%C", 0x001e) as String
    }
    
    struct fonts {
        
        /// Copied text, in the panel and the preview: Cairn sets it in the system font, like the Windows app.
        static var yippyPlainText: NSFont {
            return NSFont.systemFont(ofSize: 13)
        }
        
        /// File paths stay monospaced, so their folders line up.
        static var yippyFileNameText: NSFont {
            if #available(OSX 10.15, *) {
                return NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            }
            return NSFont.userFixedPitchFont(ofSize: 12) ?? NSFont.systemFont(ofSize: 12)
        }
    }
    
    struct urls {
        static var applicationSupport: URL {
            return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        }
        
        static var yippyAppSupport: URL {
            return applicationSupport.appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
        }
        
        static var history: URL {
            return yippyAppSupport.appendingPathComponent("history", isDirectory: true)
        }
        
        static var historyOrder: URL {
            return history.appendingPathComponent("order.xml", isDirectory: false)
        }
        
        static var favourites: URL {
            return yippyAppSupport.appendingPathComponent("favourites", isDirectory: true)
        }
        
        static var favouritesOrder: URL {
            return favourites.appendingPathComponent("order.xml", isDirectory: false)
        }
        
        static var errorLog: URL {
            return yippyAppSupport.appendingPathComponent("error.log", isDirectory: false)
        }
        
        static var warningLog: URL {
            return yippyAppSupport.appendingPathComponent("warning.log", isDirectory: false)
        }
        
        /// What sync remembers between runs (see `FileSyncStateStore`).
        static var syncState: URL {
            return yippyAppSupport.appendingPathComponent("sync.json", isDirectory: false)
        }
    }
    
    struct logging {
        
        static let historyErrorDomain = "YippyHistoryErrorDomain"
        
        static let historyWarningDomain = "YippyHistoryWarningDomain"
    }
    
    struct system {
        
        static let maxHistoryItems = 5000
    }
    
    struct settings {
        
        static let maxHistoryItemsOptions = [50, 100, 200, 500, 750, 1000, 1500]
        
        static let maxHistoryItemsDefaultIndex = 3
        
        static let maxHistoryItemsDefault = Constants.settings.maxHistoryItemsOptions[Constants.settings.maxHistoryItemsDefaultIndex]
    }
}
