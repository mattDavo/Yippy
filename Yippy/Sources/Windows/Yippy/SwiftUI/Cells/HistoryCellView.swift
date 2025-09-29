//
//  HistoryCellView.swift
//  Yippy
//
//  Created by v.prusakov on 2/13/24.
//  Copyright © 2024 MatthewDavidson. All rights reserved.
//

import SwiftUI

struct HistoryCellView: View {
    
    let item: HistoryItem
    let proxy: GeometryProxy
    let usingItemRtf: Bool
    
    var body: some View {
        switch item.content {
        case .thumbnailImage:
            HistoryFileThumbnailCellView(item: item, proxy: proxy)
        case .fileIcon:
            HistoryFileIconCellView(item: item, proxy: proxy)
        case .text:
            HistoryTextCellView(item: item, proxy: proxy, usingItemRtf: usingItemRtf)
        case .tiffOrPng:
            HistoryImageCellView(item: item, proxy: proxy)
        case .color:
            HistoryColorCellView(item: item)
        case .webLink:
            HistoryWebLinkCellView(item: item, proxy: proxy)
        }
    }
}
