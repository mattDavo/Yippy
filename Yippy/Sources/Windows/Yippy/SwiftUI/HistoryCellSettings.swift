//
//  HistoryCellSettings.swift
//  Yippy
//
//  Created by v.prusakov on 2/13/24.
//  Copyright © 2024 MatthewDavidson. All rights reserved.
//

import SwiftUI

struct HistoryCellSettings {
    let padding = EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
    let textInset = EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
    let contentViewInsets = EdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
}

private struct HistoryCellSettingsKey: EnvironmentKey {
    static var defaultValue: HistoryCellSettings = HistoryCellSettings()
}

extension EnvironmentValues {
    var historyCellSettings: HistoryCellSettings {
        get {
            self[HistoryCellSettingsKey.self]
        }
        
        set {
            self[HistoryCellSettingsKey.self] = newValue
        }
    }
}

extension Color {
    static var yippySkeleton: Color {
        Color(NSColor.controlBackgroundColor.usingColorSpace(.sRGB)!)
    }
}
