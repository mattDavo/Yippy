//
//  PanelPosition.swift
//  Yippy
//
//  Created by Matthew Davidson on 6/8/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

enum PanelPosition: Int, Codable, CaseIterable {
    case right = 0
    case left = 1
    case top = 2
    case bottom = 3
    case centerSmall = 4
    case centerMedium = 5
    case centerLarge = 6
    case fullScreen = 7
    
    var frame: NSRect {
        // TODO: Use NSEvent.mouseLocation to choose which screen
        switch self {
        case .right:
            return NSRect(x: NSScreen.main!.frame.maxX - Constants.panel.menuWidth, y: 0, width: Constants.panel.menuWidth, height: NSScreen.main!.frame.maxY)
        case .left:
            return NSRect(x: 0, y: 0, width: Constants.panel.menuWidth, height: NSScreen.main!.frame.maxY)
        case .top:
            return NSRect(x: 0, y: NSScreen.main!.frame.maxY - Constants.panel.menuHeight, width: NSScreen.main!.frame.width, height: Constants.panel.menuHeight)
        case .bottom:
            return NSRect(x: 0, y: 0, width: NSScreen.main!.frame.width, height: Constants.panel.menuHeight)
        case .centerSmall:
            let size = NSSize(width: NSScreen.main!.frame.width / 2, height: NSScreen.main!.frame.height / 2)
            return Self.centerRect(ofSize: size, inRect: NSScreen.main!.frame)
        case .centerMedium:
            let size = NSSize(width: NSScreen.main!.frame.width * 0.7, height: NSScreen.main!.frame.height * 0.7)
            return Self.centerRect(ofSize: size, inRect: NSScreen.main!.frame)
        case .centerLarge:
            let size = NSSize(width: NSScreen.main!.frame.width * 0.85, height: NSScreen.main!.frame.height * 0.85)
            return Self.centerRect(ofSize: size, inRect: NSScreen.main!.frame)
        case .fullScreen:
            return NSScreen.main!.frame
        }
    }
    
    private static func centerRect(ofSize size: NSSize, inRect rect: NSRect) -> NSRect {
        return NSRect(origin: NSPoint(x: (rect.width - size.width) / 2, y: (rect.height - size.height) / 2), size: size)
    }
    
    var title: String {
        switch self {
        case .right:
            return "Right"
        case .left:
            return "Left"
        case .top:
            return "Top"
        case .bottom:
            return "Bottom"
        case .centerSmall:
            return "Center (Small)"
        case .centerMedium:
            return "Center (Medium)"
        case .centerLarge:
            return "Center (Large)"
        case .fullScreen:
            return "Full Screen"
        }
    }
    
    var identifier: String {
        switch self {
        case .right:
            return Accessibility.identifiers.positionRightButton
        case .left:
            return Accessibility.identifiers.positionLeftButton
        case .top:
            return Accessibility.identifiers.positionTopButton
        case .bottom:
            return Accessibility.identifiers.positionBottomButton
        case .centerSmall:
            return Accessibility.identifiers.positionCenterSmall
        case .centerMedium:
            return Accessibility.identifiers.positionCenterMedium
        case .centerLarge:
            return Accessibility.identifiers.positionCenterLarge
        case .fullScreen:
            return Accessibility.identifiers.positionFullScreen
        }
    }
}
