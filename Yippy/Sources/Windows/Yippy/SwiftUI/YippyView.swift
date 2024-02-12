//
//  YippyView.swift
//  Yippy
//
//  Created by v.prusakov on 2/13/24.
//  Copyright © 2024 MatthewDavidson. All rights reserved.
//

import Cocoa
import HotKey
import RxSwift
import RxRelay
import RxCocoa
import SwiftUI

class SUIYippyViewController: NSHostingController<YippyView> {
    required init?(coder: NSCoder) {
        super.init(coder: coder, rootView: YippyView())
    }
}

struct YippyView: View {
    
    @Bindable var viewModel = YippyViewModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Spacer()
                    
                    Text(viewModel.itemCountLabel)
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                
                YippyHistoryTableView(viewModel: viewModel)
                    .onAppear(perform: viewModel.onAppear)
                    .searchable(text: $viewModel.searchBarValue, placement: .sidebar, prompt: Text("Search"))
            }
        }
        .safeAreaPadding(.top, 32)
    }
}

struct YippyHistoryTableView: View {
    
    @Bindable var viewModel: YippyViewModel
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.yippyHistory.items) { item in
                        HistoryCellView(item: item, proxy: proxy, usingItemRtf: viewModel.isRichText)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(viewModel.selectedItem == item ? Color.accentColor : Color.white.opacity(0.7))
                            )
                            .onTapGesture {
                                viewModel.onSelectItem(item)
                            }
                            .contextMenu(
                                ContextMenu(menuItems: {
                                    Button("Copy") {
                                        viewModel.pasteSelected()
                                    }
                                    
                                    Button("Delete") {
                                        viewModel.deleteSelected()
                                    }
                                })
                            )
                    }
                }
            }
        }
    }
}

let contentViewInsets = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)

struct HistoryCellView: View {
    
    let item: HistoryItem
    let proxy: GeometryProxy
    let usingItemRtf: Bool
    
    var body: some View {
        switch item.content {
        case .thumbnailImage:
            Text("1")
        case .fileIcon:
            Text("1")
        case .text:
            HistoryTextCellView(item: item, proxy: proxy, usingItemRtf: usingItemRtf)
        case .tiffOrPng:
            HistoryImageCellView(item: item, proxy: proxy)
        case .color:
            HistoryColorCellView(item: item)
        }
    }
}

struct HistoryColorCellView: View {
    
    let item: HistoryItem
    
    var body: some View {
        Group {
            if let color = item.getColor()?.withAlphaComponent(1) {
                Color(cgColor: color.cgColor)
            }
        }
        .accessibilityIdentifier(Accessibility.identifiers.yippyColorCellView)
    }
}

struct HistoryImageCellView: View {
    
    let item: HistoryItem
    let proxy: GeometryProxy
    
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
        .frame(height: Self.imageHeight(for: item, proxy: proxy))
        .accessibilityIdentifier(Accessibility.identifiers.yippyTiffCellView)
    }
    
    // MARK: Private
    
    private static func imageHeight(for historyItem: HistoryItem, proxy: GeometryProxy) -> CGFloat {
        
        let imagePadding = NSEdgeInsetsZero
        
        guard let image = historyItem.getImage() else {
            return 50
        }
        
        let imageWidth = proxy.size.width - imagePadding.xTotal - contentViewInsets.xTotal
        
        // Get max image height based on pixels
        let maxImageHeight = image.size.height
        // Calcalute image height
        let imageHeight = min(image.size.height * imageWidth / image.size.width, maxImageHeight)
        
        // Get max height of cell based on visible on visible height
        let maxHeight = proxy.frame(in: .global).height
        // Calculate cell height
        let height = min(imageHeight + imagePadding.yTotal + contentViewInsets.xTotal, maxHeight)
        
        return ceil(height)
    }
}

struct HistoryTextCellView: View {
    
    static let padding = NSEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
    
    static let textInset = NSEdgeInsetsZero // NSEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
    
    let item: HistoryItem
    let proxy: GeometryProxy
    let usingItemRtf: Bool
    
    var body: some View {
        Text(AttributedString(HistoryItemText.getAttributedString(forItem: item, usingItemRtf: usingItemRtf)))
            .accessibilityIdentifier(Accessibility.identifiers.yippyTextCellView)
            .frame(width: 300, height: Self.calculateCellHeight(historyItem: item, proxy: proxy, usingItemRtf: usingItemRtf))
            .multilineTextAlignment(.leading)
    }
    
    static func getTextContainerWidth(cellWidth: CGFloat) -> CGFloat {
        return cellWidth - Self.padding.left - Self.padding.right - Self.textInset.xTotal - contentViewInsets.xTotal
    }
    
    static func getTextContainerMaxHeight() -> CGFloat {
        return Constants.panel.maxCellHeight - Self.padding.top - Self.padding.bottom - Self.textInset.yTotal - contentViewInsets.yTotal
    }
    
    static func getCellHeight(estTextHeight: CGFloat) -> CGFloat {
        // Get the max height of the text container
        let maxTextContainerHeight = getTextContainerMaxHeight()
        
        return min(estTextHeight, maxTextContainerHeight) + Self.padding.top + Self.padding.bottom + Self.textInset.yTotal + contentViewInsets.yTotal
    }
    
    static func calculateCellHeight(historyItem: HistoryItem, proxy: GeometryProxy, usingItemRtf: Bool) -> CGFloat {
        // Calculate the width of the cell
        let cellWidth = floor(proxy.size.width)
        
        // Calculate the width of the text container
        let width = Self.getTextContainerWidth(cellWidth: cellWidth)
        
        // Create an attributed string of the text
        let attrStr = HistoryItemText.getAttributedString(forItem: historyItem, usingItemRtf: Settings.main.showsRichText)
        
        // Determine the height of the text
        let estTextHeight = attrStr.calculateSize(withMaxWidth: width).height
        
        // Add the padding back to get the height of the cell
        let height = Self.getCellHeight(estTextHeight: estTextHeight)
        
        return ceil(height)
    }
}
