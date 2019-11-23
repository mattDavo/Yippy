//
//  YippyWarning.swift
//  Yippy
//
//  Created by Matthew Davidson on 17/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation

struct YippyWarning: Loggable {
    
    var localizedDescription: String
    
    var domain: String
    
    var consoleDescription: String {
        return "[\(domain)] \(localizedDescription)"
    }
    
    var logFileDescription: String {
        return "\(localizedDescription)"
    }
    
    init(domain: String = Constants.logging.historyWarningDomain, localizedDescription: String) {
        self.domain = domain
        self.localizedDescription = localizedDescription
    }
}
