//
//  YippyError.swift
//  Yippy
//
//  Created by Matthew Davidson on 17/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

struct YippyError: Loggable, Alertable, Error {
    
    var error: Error
    
    var localizedDescription: String {
        return error.localizedDescription
    }
    
    var domain: String {
        return (error as NSError).domain
    }
    
    var consoleDescription: String {
        return "[\(domain)] \(localizedDescription)"
    }
    
    var logFileDescription: String {
        return "\(localizedDescription)"
    }
    
    init(error: Error) {
        self.error = error
    }
    
    init(domain: String = Constants.logging.historyErrorDomain, code: Int, userInfo: [String: Any]? = nil) {
        self.error = NSError(domain: domain, code: code, userInfo: userInfo)
    }
    
    init(domain: String = Constants.logging.historyErrorDomain, localizedDescription: String) {
        // TODO: Refactor error code
        self.error = NSError(domain: domain, code: 0, userInfo: [
            NSLocalizedDescriptionKey: localizedDescription
        ])
    }
    
    func createAlert() -> NSAlert {
        return NSAlert(error: error)
    }
    
    func logAndShow(withLogger logger: Logger, andAlerter alerter: Alerter = .general) {
        logger.log(self)
        alerter.show(self)
    }
}
