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
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(BorderStrokeButtonStyle(shape: Circle()))

                Spacer()

                Button("Open in browser") {
                    if let url = viewModel.url {
                        NSWorkspace.shared.open(url)
                        dismiss()
                    }
                }
                .buttonStyle(BorderStrokeButtonStyle(shape: Capsule()))
            }
            .padding(.all, 16)
            .newBackgroundEffect()

            if #available(macOS 26, *) {
                WebView(url: viewModel.url)
            } else {
                WebViewView(url: viewModel.url)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accentColor, lineWidth: 10)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
    }
}

private extension View {
    @ViewBuilder
    func newBackgroundEffect() -> some View {
        if #available(macOS 26, *) {
            self
                .glassEffect(.regular, in: Rectangle())
        } else {
            self
                .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

struct BorderStrokeButtonStyle<S: Shape>: ButtonStyle {

    let shape: S

    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26, *) {
            configuration.label
                .font(.system(size: 14))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .glassEffect(.regular.tint(.blue), in: shape)
        } else {
            configuration.label
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .foregroundStyle(Color(NSColor.controlTextColor))
                .background(
                    shape
                        .fill(Color(.controlBackgroundColor))
                )
                .overlay {
                    shape
                        .stroke(Color(NSColor.separatorColor))
                }
                .clipShape(
                    shape
                )
        }
    }
}

struct WebViewView: NSViewRepresentable {
    
    var url: URL?
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        if let url = self.url {
            nsView.load(URLRequest(url: url))
        }
    }
}
