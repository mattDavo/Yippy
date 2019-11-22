//
//  UITesting.swift
//  Yippy
//
//  Created by Matthew Davidson on 28/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation

struct UITesting {
    
    static func setupUITestEnvironment(launchArgs: [String], environment: [String: String]) throws {
        // Mock the access control and key pressing
        Helper.accessControlHelper = AccessControlHelperMock()
        Helper.keyPressHelper = KeyPressHelperMock()
        
        // Remove the settings
        _ = UserDefaults.standard.blank()
        
        if let test = CommandLine.arguments.filter({$0.contains("--Settings.testData=")}).first {
            Settings.main = Settings.testData.from(test)
        }
        
        try loadTestAppSupport(launchArgs: launchArgs, environment: environment)
    }
    
    static func loadTestAppSupport(launchArgs: [String], environment: [String: String]) throws {
        guard let testData = launchArgs.first(where: {$0.contains("--test-dir=")}) else {
            return
        }
        let pattern = "--test-dir=(.*)"
        let regex = try! NSRegularExpression(pattern: pattern)
        guard let firstMatch = regex.firstMatch(in: testData, range: NSRange(location: 0, length: testData.count)) else {
            return
        }
        let groups = firstMatch.groups(testedString: testData)
        if groups.count < 2 {
            return
        }
        let test = groups[1]
        
        guard let srcroot = environment["SRCROOT"] else {
            throw NSError(domain: "UITestError", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Cannot load test app support directory because the SRCROOT environment variable is not set."
            ])
        }
        guard let testDir = NSURL(fileURLWithPath: srcroot)
            .appendingPathComponent("TestData", isDirectory: true)?
            .appendingPathComponent(test, isDirectory: true) else {
            throw NSError(domain: "UITestError", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create test url for path srcroot/TestData/\(test)."
            ])
        }
        if FileManager.default.fileExists(atPath: testDir.path) {
            if FileManager.default.fileExists(atPath: Constants.urls.yippyAppSupport.path) {
                try FileManager.default.removeItem(at: Constants.urls.yippyAppSupport)
            }
            try FileManager.default.copyItem(at: testDir, to: Constants.urls.yippyAppSupport)
        }
        else {
            throw NSError(domain: "TestDirectoryError", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Could not copy test directory \(test) because it doesn't exist."
            ])
        }
    }
}
