//
//  HistoryTextCellView.swift
//  Yippy
//
//  Created by v.prusakov on 2/13/24.
//  Copyright © 2024 MatthewDavidson. All rights reserved.
//

import SwiftUI

struct HistoryTextCellView: View {
    
    @Environment(\.historyCellSettings) private var settings
    
    let item: HistoryItem
    let proxy: GeometryProxy
    let usingItemRtf: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            Text(AttributedString(HistoryItemText.getAttributedString(forItem: item, usingItemRtf: usingItemRtf)))
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(settings.textInset)
        .frame(
            width: width,
            height: Self.calculateCellHeight(
                historyItem: item,
                proxy: proxy,
                availableWidth: width,
                settings: settings,
                usingItemRtf: usingItemRtf
            )
        )
        .accessibilityIdentifier(Accessibility.identifiers.yippyTextCellView)
    }
    
    // MARK: - Private
    
    private var width: CGFloat {
        return proxy.size.width - settings.padding.xTotal
    }
    
    private static func getTextContainerWidth(cellWidth: CGFloat, settings: HistoryCellSettings) -> CGFloat {
        return cellWidth - settings.textInset.xTotal - settings.contentViewInsets.xTotal
    }
    
    private static func getTextContainerMaxHeight(settings: HistoryCellSettings) -> CGFloat {
        return Constants.panel.maxCellHeight - settings.textInset.yTotal - settings.contentViewInsets.yTotal
    }
    
    private static func getCellHeight(estTextHeight: CGFloat, settings: HistoryCellSettings) -> CGFloat {
        // Get the max height of the text container
        let maxTextContainerHeight = getTextContainerMaxHeight(settings: settings)
        
        return min(estTextHeight, maxTextContainerHeight) + settings.textInset.yTotal + settings.contentViewInsets.yTotal
    }
    
    private static func calculateCellHeight(
        historyItem: HistoryItem,
        proxy: GeometryProxy,
        availableWidth: CGFloat,
        settings: HistoryCellSettings,
        usingItemRtf: Bool
    ) -> CGFloat {
        // Calculate the width of the cell
        let cellWidth = floor(availableWidth)
        
        // Calculate the width of the text container
        let width = Self.getTextContainerWidth(cellWidth: cellWidth, settings: settings)
        
        // Create an attributed string of the text
        let attrStr = HistoryItemText.getAttributedString(forItem: historyItem, usingItemRtf: Settings.main.showsRichText)
        
        // Determine the height of the text
        let estTextHeight = attrStr.calculateSize(withMaxWidth: width).height
        
        // Add the padding back to get the height of the cell
        let height = Self.getCellHeight(estTextHeight: estTextHeight, settings: settings)
        
        return ceil(height)
    }
}
