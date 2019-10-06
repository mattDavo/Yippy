//
//  PanelPosition.swift
//  Yippy
//
//  Created by Matthew Davidson on 6/8/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

enum PanelPosition: Int, Codable {
    case right = 0
    case left = 1
    case top = 2
    case bottom = 3
    
    var frame: NSRect {
        switch self {
        case .right:
            return NSRect(x: NSScreen.main!.frame.maxX - Constants.panel.menuWidth, y: NSScreen.main!.visibleFrame.minY, width: Constants.panel.menuWidth, height: NSScreen.main!.frame.maxY)
        case .left:
            return NSRect(x: 0, y: NSScreen.main!.visibleFrame.minY, width: Constants.panel.menuWidth, height: NSScreen.main!.frame.maxY)
        case .top:
            return NSRect(x: 0, y: NSScreen.main!.frame.maxY - Constants.panel.menuHeight, width: NSScreen.main!.frame.width, height: Constants.panel.menuHeight)
        case .bottom:
            return NSRect(x: 0, y: 0, width: NSScreen.main!.frame.width, height: Constants.panel.menuHeight)
        }
    }
}
