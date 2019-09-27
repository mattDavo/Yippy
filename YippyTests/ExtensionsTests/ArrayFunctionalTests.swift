//
//  ArrayFunctionalTests.swift
//  YippyTests
//
//  Created by Matthew Davidson on 27/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest
@testable import Yippy

class ArrayFunctionalTests: XCTestCase {
    
    func testEmptyWithAppend() {
        // 1. Given an empty array
        let arr = [String]()
        
        // 2. When with appended it
        let new = arr.with(elementAppened: "Test")
        
        // 3. Then it returns an array with one element
        XCTAssertEqual(new, ["Test"])
    }
    
    func testNonEmptyWithAppend() {
        // 1. Given a non-empty array
        let arr = ["1", "2"]
        
        // 2. When with appended it
        let new = arr.with(elementAppened: "3")
        
        // 3. Then it returns an array with one element
        XCTAssertEqual(new, ["1", "2", "3"])
    }
    
    func testWithInsertedAt() {
        // 1. Given a non-empty array
        let arr = ["1", "2", "4", "5"]
        
        // 2. When elements are inserted
        let new = arr
            .with(element: "0", insertedAt: 0)
            .with(element: "3", insertedAt: 3)
            .with(element: "6", insertedAt: 6)
        
        // 3. An array is returned with the elements inserted in the correct positions
        XCTAssertEqual(new, ["0", "1", "2", "3", "4", "5", "6"])
    }
    
    func testWithoutStart() {
        // 1. Given a non-empty array
        let arr = ["1", "1", "2", "2", "3", "3"]
        
        // 2. When items are removed
        let new = arr
            .without(elementAt: 5)
            .without(elementAt: 2)
            .without(elementAt: 0)
        
        // An array is returned with the correct elements removed
        XCTAssertEqual(new, ["1", "2", "3"])
    }
    
}
