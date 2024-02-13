//
//  SafariPreviewController.swift
//  Yippy
//
//  Created by v.prusakov on 2/13/24.
//  Copyright © 2024 MatthewDavidson. All rights reserved.
//

import SafariServices
import SwiftUI
import WebKit

class SafariPreviewController: NSHostingController<SafariPreviewView>, PreviewViewController {
    
    let padding = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
    
    private var viewModel = SafariPreviewViewModel()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder, rootView: SafariPreviewView(viewModel: viewModel))
    }
    
    static var identifier: NSStoryboard.SceneIdentifier = "SafariPreviewController"
    
    func configureView(forItem item: HistoryItem) -> NSRect {
        guard let url = item.getUrl() else {
            return calculateWindowFrame()
        }
        
        viewModel.url = url
        
        return calculateWindowFrame()
    }
    
    func calculateWindowFrame() -> NSRect {
        let maxWindowWidth = NSScreen.main!.frame.width * 0.8
        let maxWindowHeight = NSScreen.main!.frame.height * 0.8
        
        let center = NSPoint(x: NSScreen.main!.frame.midX - maxWindowWidth / 2, y: NSScreen.main!.frame.midY - maxWindowHeight / 2)
        
        return NSRect(origin: center, size: NSSize(width: maxWindowWidth, height: maxWindowHeight))
    }
}

@Observable
class SafariPreviewViewModel {
    var url: URL?
}

struct SafariPreviewView: View {
    
    @Bindable var viewModel: SafariPreviewViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack(alignment: .top) {
            HStack {
                Spacer()
                
                Button("Open in browser") {
                    if let url = viewModel.url {
                        NSWorkspace.shared.open(url)
                        dismiss()
                    }
                }
                .buttonBorderShape(.roundedRectangle)
            }
            .frame(height: 24)
            .padding(.all, 16)
            .materialBlur(style: .headerView)
            
            WebViewView(url: viewModel.url)
                .safeAreaPadding(.top, 48)
        }
        .cornerRadius(16)
    }
}

struct WebViewView: NSViewRepresentable {
    
    var url: URL?
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        return WKWebView(frame: .zero, configuration: config)
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        if let url = self.url {
            nsView.load(URLRequest(url: url))
        }
    }
}
