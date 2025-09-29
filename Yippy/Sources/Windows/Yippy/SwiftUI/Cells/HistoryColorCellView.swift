//
//  HistoryColorCellView.swift
//  Yippy
//
//  Created by v.prusakov on 2/13/24.
//  Copyright © 2024 MatthewDavidson. All rights reserved.
//

import SwiftUI

struct HistoryColorCellView: View {
    
    let item: HistoryItem

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Color content
            Group {
                if let color = item.getColor()?.withAlphaComponent(1) {
                    Color(cgColor: color.cgColor)
                }
            }

            // Category badge
            CategoryBadgeView(
                category: item.getCategory(),
                codeSource: item.getCodeSource()
            )
        }
        .accessibilityIdentifier(Accessibility.identifiers.yippyColorCellView)
    }
}
