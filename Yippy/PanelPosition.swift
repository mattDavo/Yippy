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
            return NSRect(x: NSScreen.main!.visibleFrame.maxX - Constants.panel.menuWidth, y: NSScreen.main!.visibleFrame.minY, width: Constants.panel.menuWidth, height: NSScreen.main!.visibleFrame.height)
        case .left:
            return NSRect(x: 0, y: 0, width: Constants.panel.menuWidth, height: NSScreen.main!.visibleFrame.maxY)
        case .top:
            return NSRect(x: 0, y: NSScreen.main!.visibleFrame.height - Constants.panel.menuHeight, width: NSScreen.main!.visibleFrame.width, height: Constants.panel.menuHeight)
        case .bottom:
            return NSRect(x: 0, y: 0, width: NSScreen.main!.visibleFrame.width, height: Constants.panel.menuHeight)
        }
    }
}
