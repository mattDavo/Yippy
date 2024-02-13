//
//  HistoryFileThumbnailCellView.swift
//  Yippy
//
//  Created by v.prusakov on 2/13/24.
//  Copyright © 2024 MatthewDavidson. All rights reserved.
//

import SwiftUI
import QuickLook

struct HistoryFileThumbnailCellView: View {
    
    let item: HistoryItem
    let proxy: GeometryProxy
    
    @Environment(\.historyCellSettings) private var settings
    
    @SwiftUI.State private var isLoading = false
    @SwiftUI.State private var previewImage: Image?
    @SwiftUI.State private var attributedPath: AttributedString?
    
    private var width: CGFloat {
        return proxy.size.width - self.settings.padding.xTotal
    }
    
    var body: some View {
        Group {
            if self.isLoading {
                RoundedRectangle(cornerRadius: 7)
                    .frame(width: width, height: Self.imageSize.height)
                    .skeletonable()
            } else {
                ZStack {
                    if let previewImage {
                        previewImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: Self.imageSize.height)
                    }
                    
                    VStack {
                        
                        Spacer()
                        
                        if let attributedPath {
                            Text(attributedPath)
                                .frame(width: width)
                                .padding(.all, 8)
                                .materialBlur(style: .contentBackground, opacity: 0.9)
                        }
                    }
                }
                .frame(
                    width: self.width,
                    height: Self.getItemHeight(for: item, availableWidth: width, settings: settings, proxy: proxy)
                )
            }
        }
        .accessibilityIdentifier(Accessibility.identifiers.yippyFileThumbnailCellView)
        .onAppear(perform: self.onAppear)
        .setSkeleton($isLoading, animationType: .gradient(Color.yippySkeleton.makeGradient()))
    }
    
    // MARK: - Private
    
    private func onAppear() {
        guard let url = item.getFileUrl() else { return }
        self.isLoading = true
        
        self.attributedPath = AttributedString(formatFileUrl(url))
        
        DispatchQueue.global(qos: .background).async {
            let cgImageRef = QLThumbnailImageCreate(kCFAllocatorDefault, url as CFURL, CGSize(width: 200, height: 200), [kQLThumbnailOptionIconModeKey: false, kQLThumbnailOptionScaleFactorKey: 4] as CFDictionary)
            
            DispatchQueue.main.async {
                if let cgImage = cgImageRef?.takeRetainedValue() {
                    let image = NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
                    self.previewImage = Image(nsImage: image)
                }
                else {
                    ErrorLogger.general.log(YippyError(localizedDescription: "Failed to create thumbnail for file with url '\(url.path)'"))
                    self.previewImage = nil
                }
            }
            
            self.isLoading = false
        }
    }
    
    private static let fileNamePadding = NSEdgeInsets(top: 10, left: 5, bottom: 10, right: 5)
    
    private static let imageSize = NSSize(width: 300, height: 200)
    
    private static let imageTopPadding: CGFloat = 5
    
    private static func getItemHeight(
        for historyItem: HistoryItem,
        availableWidth: CGFloat,
        settings: HistoryCellSettings,
        proxy: GeometryProxy
    ) -> CGFloat {
        // Calculate the width of the cell
        let cellWidth = floor(availableWidth)
        
        // Calculate the text container width
        let textContainerWidth = cellWidth - settings.contentViewInsets.xTotal - fileNamePadding.xTotal
        
        // Create the attributed string
        let str = formatFileUrl(historyItem.getFileUrl()!)
        
        // Calculate the height of the text
        let estHeight = str.calculateSize(withMaxWidth: textContainerWidth).height
        
        // Calculate the height of the cell
        let height = estHeight + settings.contentViewInsets.yTotal + fileNamePadding.yTotal + imageSize.height + imageTopPadding
        
        return ceil(height)
    }
}

// TODO: Move to other place

@inlinable
@inline(__always)
public func clamp<T: Comparable>(_ value: T, _ min: T, _ max: T) -> T {
    return value < min ? (min) : (value > max ? max : value)
}
