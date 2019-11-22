//
//  NSTextCheckingResult+Groups.swift
//  Yippy
//
//  Created by Matthew Davidson on 22/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

extension NSTextCheckingResult {
    
    /// https://stackoverflow.com/a/51384977
    func groups(testedString:String) -> [String] {
        var groups = [String]()
        for i in  0 ..< self.numberOfRanges
        {
            let group = String(testedString[Range(self.range(at: i), in: testedString)!])
            groups.append(group)
        }
        return groups
    }
}
