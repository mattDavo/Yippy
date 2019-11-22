//
//  WarningLogger.swift
//  Yippy
//
//  Created by Matthew Davidson on 17/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation

class WarningLogger: Logger {
    
    static let general = WarningLogger(url: Constants.urls.warningLog)
}
