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
    
    struct fonts {
        
        static let yippyPlainText = NSFont(name: "Roboto Mono Light for Powerline", size: 12)!
        static let yippyFileNameText = NSFont(name: "Roboto Mono Light for Powerline", size: 12)!
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
        
        static var errorLog: URL {
            return yippyAppSupport.appendingPathComponent("error.log", isDirectory: false)
        }
        
        static var warningLog: URL {
            return yippyAppSupport.appendingPathComponent("warning.log", isDirectory: false)
        }
    }
    
    struct logging {
        
        static let historyErrorDomain = "YippyHistoryErrorDomain"
        
        static let historyWarningDomain = "YippyHistoryWarningDomain"
    }
}
