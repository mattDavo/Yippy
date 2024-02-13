//
//  HistoryImageCellView.swift
//  Yippy
//
//  Created by v.prusakov on 2/13/24.
//  Copyright © 2024 MatthewDavidson. All rights reserved.
//

import SwiftUI

struct HistoryImageCellView: View {
    
    let item: HistoryItem
    let proxy: GeometryProxy
    
    @Environment(\.historyCellSettings) private var settings
    
    var body: some View {
        Group {
            if let image = item.getImage() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.gray)
            }
        }
        .frame(width: width,
               height: Self.imageHeight(for: item, width: width, proxy: proxy, settings: settings))
        .clipped()
        .accessibilityIdentifier(Accessibility.identifiers.yippyTiffCellView)
    }
    
    // MARK: - Private
    
    private var width: CGFloat {
        return proxy.size.width - settings.padding.xTotal
    }
    
    private static func imageHeight(
        for historyItem: HistoryItem,
        width: CGFloat,
        proxy: GeometryProxy,
        settings: HistoryCellSettings
    ) -> CGFloat {
        
        let imagePadding = NSEdgeInsetsZero
        
        guard let image = historyItem.getImage() else {
            return 50
        }
        
        let imageWidth = width - imagePadding.xTotal - settings.contentViewInsets.xTotal
        
        // Get max image height based on pixels
        let maxImageHeight = image.size.height
        // Calcalute image height
        let imageHeight = min(image.size.height * imageWidth / image.size.width, maxImageHeight)
        
        // Get max height of cell based on visible on visible height
        let maxHeight = proxy.frame(in: .global).height
        // Calculate cell height
        let height = min(imageHeight + imagePadding.yTotal + settings.contentViewInsets.xTotal, maxHeight)
        
        return ceil(height)
    }
}
