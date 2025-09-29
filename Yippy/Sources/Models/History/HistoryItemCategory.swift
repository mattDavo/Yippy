//
//  HistoryItemCategory.swift
//  Yippy
//
//  Created by AI Assistant on 2024.
//  Copyright © 2024 MatthewDavidson. All rights reserved.
//

import Foundation
import SwiftUI

/// Represents different categories of clipboard items
enum HistoryItemCategory: String, CaseIterable, Codable {
    case text = "text"
    case code = "code"
    case url = "url"
    case image = "image"
    case file = "file"
    case color = "color"
    case video = "video"
    case audio = "audio"
    case pdf = "pdf"
    case other = "other"
    
    /// Display name for the category
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .code: return "Code"
        case .url: return "URLs"
        case .image: return "Images"
        case .file: return "Files"
        case .color: return "Colors"
        case .video: return "Videos"
        case .audio: return "Audio"
        case .pdf: return "PDFs"
        case .other: return "Other"
        }
    }
    
    /// System icon name for the category
    var iconName: String {
        switch self {
        case .text: return "text.alignleft"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .url: return "link"
        case .image: return "photo"
        case .file: return "doc"
        case .color: return "paintpalette"
        case .video: return "video"
        case .audio: return "music.note"
        case .pdf: return "doc.richtext"
        case .other: return "questionmark.circle"
        }
    }
    
    /// Color for the category badge
    var color: NSColor {
        switch self {
        case .text: return .systemBlue
        case .code: return .systemGreen
        case .url: return .systemPurple
        case .image: return .systemOrange
        case .file: return .systemGray
        case .color: return .systemPink
        case .video: return .systemRed
        case .audio: return .systemYellow
        case .pdf: return .systemIndigo
        case .other: return .systemBrown
        }
    }
}

extension NSColor {
    var swiftUIColor: SwiftUI.Color {
        return SwiftUI.Color(self)
    }
}

/// Represents the source application for code items
enum CodeSource: String, CaseIterable, Codable {
    case vscode = "vscode"
    case xcode = "xcode"
    case sublime = "sublime"
    case atom = "atom"
    case vim = "vim"
    case emacs = "emacs"
    case webstorm = "webstorm"
    case cursor = "cursor"
    case intellij = "intellij"
    case unknown = "unknown"

    init?(bundleId: String) {
        switch bundleId.lowercased() {
        case "com.microsoft.vscode", "com.visualstudio.code": self = .vscode
        case "com.apple.dt.xcode": self = .xcode
        case "com.sublimetext.3", "com.sublimetext.4": self = .sublime
        case "com.github.atom": self = .atom
        case "org.vim.macvim", "org.vim": self = .vim
        case "org.gnu.macs", "org.gnu.emacs": self = .emacs
        case "com.jetbrains.webstorm": self = .webstorm
        case "com.jetbrains.intellij": self = .intellij
        case "com.cursor.app": self = .cursor
        default: self = .unknown
        }
    }
    
    var displayName: String {
        switch self {
        case .vscode: return "VS Code"
        case .xcode: return "Xcode"
        case .sublime: return "Sublime Text"
        case .atom: return "Atom"
        case .vim: return "Vim"
        case .emacs: return "Emacs"
        case .webstorm: return "WebStorm"
        case .intellij: return "IntelliJ IDEA"
        case .cursor: return "Cursor"
        case .unknown: return "Unknown"
        }
    }
    
    var iconName: String {
        switch self {
        case .vscode: return "chevron.left.forwardslash.chevron.right"
        case .xcode: return "hammer"
        case .sublime: return "text.alignleft"
        case .atom: return "atom"
        case .vim: return "terminal"
        case .emacs: return "terminal"
        case .webstorm: return "chevron.left.forwardslash.chevron.right"
        case .intellij: return "chevron.left.forwardslash.chevron.right"
        case .cursor: return "cursorarrow"
        case .unknown: return "questionmark.circle"
        }
    }
}

/// Metadata for a history item including category and source information
struct HistoryItemMetadata: Codable {
    let category: HistoryItemCategory
    let codeSource: CodeSource?
    let detectedAt: Date
    let originBundleId: String?

    init(category: HistoryItemCategory, codeSource: CodeSource? = nil, originBundleId: String? = nil) {
        self.category = category
        self.codeSource = codeSource
        self.detectedAt = Date()
        self.originBundleId = originBundleId
    }
}
