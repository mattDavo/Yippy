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
    case centerExtraSmall = 8
    case centerSmall = 4
    case centerMedium = 5
    case centerLarge = 6
    case fullScreen = 7
    
    public func getFrame(forScreen screen: NSScreen) -> NSRect {
        switch self {
        case .right:
            return NSRect(x: screen.frame.maxX - Constants.panel.menuWidth, y: screen.frame.minY, width: Constants.panel.menuWidth, height: screen.frame.height)
        case .left:
            return NSRect(x: screen.frame.minX, y: screen.frame.minY, width: Constants.panel.menuWidth, height: screen.frame.height)
        case .top:
            return NSRect(x: screen.frame.minX, y: screen.frame.maxY - Constants.panel.menuHeight, width: screen.frame.width, height: Constants.panel.menuHeight)
        case .bottom:
            return NSRect(x: screen.frame.minX, y: screen.frame.minY, width: screen.frame.width, height: Constants.panel.menuHeight)
        case .centerExtraSmall:
            let size = NSSize(width: screen.frame.width / 3, height: screen.frame.height / 3)
            return Self.centerRect(ofSize: size, inRect: screen.frame)
        case .centerSmall:
            let size = NSSize(width: screen.frame.width / 2, height: screen.frame.height / 2)
            return Self.centerRect(ofSize: size, inRect: screen.frame)
        case .centerMedium:
            let size = NSSize(width: screen.frame.width * 0.7, height: screen.frame.height * 0.7)
            return Self.centerRect(ofSize: size, inRect: screen.frame)
        case .centerLarge:
            let size = NSSize(width: screen.frame.width * 0.85, height: screen.frame.height * 0.85)
            return Self.centerRect(ofSize: size, inRect: screen.frame)
        case .fullScreen:
            return screen.frame
        }
    }
    
    private static func centerRect(ofSize size: NSSize, inRect rect: NSRect) -> NSRect {
        return NSRect(origin: NSPoint(x: (rect.width - size.width) / 2 + rect.minX, y: (rect.height - size.height) / 2 + rect.minY), size: size)
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
        case .centerExtraSmall:
            return "Center (Extra Small)"
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
        case.centerExtraSmall:
            return Accessibility.identifiers.positionCenterExtraSmall
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
