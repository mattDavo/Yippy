//
//  CategoryBadgeView.swift
//  Yippy
//
//  Created by AI Assistant on 2024.
//  Copyright © 2024 MatthewDavidson. All rights reserved.
//

import SwiftUI

struct CategoryBadgeView: View {
    let category: HistoryItemCategory
    let codeSource: CodeSource?
    
    var body: some View {
        HStack(spacing: 4) {
            // Main category badge
            HStack(spacing: 2) {
                Image(systemName: category.iconName)
                    .font(.system(size: 8))
                Text(category.displayName)
                    .font(.system(size: 8, weight: .medium))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(category.color).opacity(0.2))
            .foregroundColor(Color(category.color))
            .clipShape(Capsule())
            
            // Code source badge (if applicable)
            if let codeSource = codeSource, category == .code {
                HStack(spacing: 2) {
                    Image(systemName: codeSource.iconName)
                        .font(.system(size: 8))
                    Text(codeSource.displayName)
                        .font(.system(size: 8, weight: .medium))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .foregroundColor(.secondary)
                .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        CategoryBadgeView(category: .code, codeSource: .vscode)
        CategoryBadgeView(category: .text, codeSource: nil)
        CategoryBadgeView(category: .image, codeSource: nil)
        CategoryBadgeView(category: .url, codeSource: nil)
    }
    .padding()
}
