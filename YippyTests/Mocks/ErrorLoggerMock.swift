//
//  ErrorLoggerMock.swift
//  YippyTests
//
//  Created by Matthew Davidson on 20/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest
@testable import Yippy

class ErrorLoggerMock: ErrorLogger {
    
    var expectation: XCTestExpectation!
    
    init() {
        super.init(url: URL(fileURLWithPath: "test"))
    }
    
    override func log(_ loggable: Loggable) {
        expectation.fulfill()
    }
}
