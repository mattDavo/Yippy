//
//  AlerterMock.swift
//  YippyTests
//
//  Created by Matthew Davidson on 20/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest
@testable import Yippy

class AlerterMock: Alerter {
    
    var expectation: XCTestExpectation!
    
    override func show(_ alertable: Alertable) {
        expectation.fulfill()
    }
}
