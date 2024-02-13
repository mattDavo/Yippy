//
//  BlurView.swift
//  Yippy
//
//  Created by v.prusakov on 2/13/24.
//  Copyright © 2024 MatthewDavidson. All rights reserved.
//

import SwiftUI

extension View {
    func materialBlur(style: NSVisualEffectView.Material, opacity: CGFloat = 1.0) -> some View {
        modifier(MaterialBlur(style: style, opacity: opacity))
    }
}

struct VisualEffectView: NSViewRepresentable {
    
    private let style: NSVisualEffectView.Material
    
    init(style: NSVisualEffectView.Material) {
        self.style = style
    }
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView(frame: .zero)
        view.material = style
        return view
    }
    
    func updateNSView(_ uiView: NSVisualEffectView, context: Context) {}
}

struct MaterialBlur: ViewModifier {
    let style: NSVisualEffectView.Material
    let opacity: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    VisualEffectView(style: style)
                        .opacity(opacity)
                }
                    .ignoresSafeArea()
            )
    }
}

