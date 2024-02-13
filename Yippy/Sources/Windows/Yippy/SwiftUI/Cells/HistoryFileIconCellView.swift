//
//  HistoryFileIconCellView.swift
//  Yippy
//
//  Created by v.prusakov on 2/13/24.
//  Copyright © 2024 MatthewDavidson. All rights reserved.
//

import SwiftUI

struct HistoryFileIconCellView: View {
    
    let item: HistoryItem
    let proxy: GeometryProxy
    
    @Environment(\.historyCellSettings) private var settings
    @SwiftUI.State private var image: Image?
    @SwiftUI.State private var iconFileName: NSAttributedString?
    
    var body: some View {
        Group {
            HStack {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: Self.iconSize.width, height: Self.iconSize.height)
                }
                if let iconFileName {
                    Text(AttributedString(iconFileName))
                        .frame(width: width)
                        .padding(.all, 8)
                        .materialBlur(style: .contentBackground, opacity: 0.9)
                }
            }
            .frame(
                width: self.width,
                height: Self.getItemHeight(for: item, availableWidth: width, proxy: proxy, settings: settings)
            )
        }
        .onAppear(perform: self.onAppear)
        .accessibilityIdentifier(Accessibility.identifiers.yippyFileIconCellView)
    }
    
    // MARK: - Private
    
    private func onAppear() {
        if let icon = item.getFileIcon() {
            self.image = Image(nsImage: icon)
        }
        
        self.iconFileName = formatFileUrl(item.getFileUrl()!)
    }
    
    private var width: CGFloat {
        return self.proxy.size.width - settings.padding.xTotal
    }
    
    private static let textContainerInset = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
    private static let iconViewPadding = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
    private static let iconSize = NSSize(width: 32, height: 32)
    
    private static func getItemHeight(for historyItem: HistoryItem, availableWidth: CGFloat, proxy: GeometryProxy, settings: HistoryCellSettings) -> CGFloat {
        // Calculate the width of the cell
        let cellWidth = floor(availableWidth)
        
        // Calculate the text view height
        let textViewHeight = getFileNameTextViewHeight(withCellWidth: cellWidth, for: historyItem, settings: settings)
        
        // Calculate minimum cell height
        let minCellHeight = iconSize.height + settings.contentViewInsets.yTotal + iconViewPadding.yTotal
        
        // Add the padding back to get the height of the cell
        let height = max(textViewHeight + settings.contentViewInsets.yTotal, minCellHeight)
        
        return ceil(height)
    }
    
    private static func getFileNameTextViewHeight(withCellWidth cellWidth: CGFloat, for historyItem: HistoryItem, settings: HistoryCellSettings) -> CGFloat {
        // Calculate the width of the text container
        let width = cellWidth - settings.contentViewInsets.xTotal - iconSize.width - textContainerInset.xTotal - iconViewPadding.xTotal
        
        // Create an attributed string of the text
        let attrStr = formatFileUrl(historyItem.getFileUrl()!)
        
        // Get the max height of the text container
        let maxTextContainerHeight = Constants.panel.maxCellHeight - settings.contentViewInsets.yTotal - textContainerInset.yTotal
        
        // Determine the height of the text view (capping the cell height)
        let estHeight = attrStr.calculateSize(withMaxWidth: width).height
        
        return min(estHeight, maxTextContainerHeight) + textContainerInset.yTotal
    }
}
