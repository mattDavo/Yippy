//
//  HistoryWebLinkCellView.swift
//  Yippy
//
//  Created by v.prusakov on 2/13/24.
//  Copyright © 2024 MatthewDavidson. All rights reserved.
//

import SwiftUI
import LinkPresentation
import EasySkeleton

struct HistoryWebLinkCellView: View {
    
    let item: HistoryItem
    let proxy: GeometryProxy
    
    @Environment(\.historyCellSettings) private var settings
    
    @SwiftUI.State private var metadata: LPLinkMetadata?
    @SwiftUI.State private var isLoading = false
    
    private var width: CGFloat {
        proxy.size.width - self.settings.padding.xTotal
    }
    
    var body: some View {
        Group {
            if isLoading {
                 RoundedRectangle(cornerRadius: 7)
                    .frame(width: width, height: width / 2)
                    .skeletonable()
            } else {
                if let metadata = self.metadata {
                    LinkPreview(metadata: metadata)
                        .frame(width: width)
                        .allowsHitTesting(false)
                } else {
                    HistoryTextCellView(item: item, proxy: proxy, usingItemRtf: false)
                }
            }
        }
        .accessibilityIdentifier(Accessibility.identifiers.yippyWebLinkCellView)
        .task {
            guard self.metadata == nil else {
                return
            }
            if let url = item.getUrl() {
                self.isLoading = true
                let provider = LPMetadataProvider()
                self.metadata = try? await provider.startFetchingMetadata(for: url)
                self.isLoading = false
            }
        }
        .setSkeleton($isLoading, animationType: .gradient(Color.yippySkeleton.makeGradient()))
    }
}

struct LinkPreview: NSViewRepresentable {
    
    let metadata: LPLinkMetadata
    
    func makeNSView(context: Context) -> some NSView {
        let view = LPLinkView(metadata: metadata)
        return view
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) { }
}
