//
//  CategoryDetector.swift
//  Yippy
//
//  Created by AI Assistant on 2024.
//  Copyright © 2024 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

/// Detects the category and source of clipboard items
final class CategoryDetector {

    static let shared = CategoryDetector()
    
    private init() {}
    
    /// Detects the category and metadata for a history item
    func detectCategory(for item: HistoryItem) -> HistoryItemMetadata {
        let codeSource = detectCodeSource(for: item)
        let category = detectCategoryType(for: item, codeSource: codeSource)

        return HistoryItemMetadata(category: category, codeSource: codeSource)
    }
    
    /// Detects the main category type for a history item
    private func detectCategoryType(for item: HistoryItem, codeSource: CodeSource?) -> HistoryItemCategory {
        // Check for specific pasteboard types first
        if item.types.contains(.color) {
            return .color
        }
        
        if item.types.contains(.fileURL) {
            return detectFileCategory(for: item)
        }
        
        if item.types.contains(.URL) {
            return .url
        }
        
        if item.types.contains(.tiff) || item.types.contains(.png) {
            return .image
        }
        
        if item.types.contains(.pdf) {
            return .pdf
        }
        
        // Check text content for more specific categorization
        if let text = item.getPlainString() {
            return detectTextCategory(text: text, codeSource: codeSource)
        }
        
        // Default fallback
        return .other
    }
    
    /// Detects file category based on file extension
    private func detectFileCategory(for item: HistoryItem) -> HistoryItemCategory {
        guard let fileURL = item.getFileUrl() else { return .file }
        
        let pathExtension = fileURL.pathExtension.lowercased()
        
        // Image files
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "svg", "ico"]
        if imageExtensions.contains(pathExtension) {
            return .image
        }
        
        // Video files
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "3gp"]
        if videoExtensions.contains(pathExtension) {
            return .video
        }
        
        // Audio files
        let audioExtensions = ["mp3", "wav", "aac", "flac", "ogg", "m4a", "wma", "aiff"]
        if audioExtensions.contains(pathExtension) {
            return .audio
        }
        
        // PDF files
        if pathExtension == "pdf" {
            return .pdf
        }
        
        return .file
    }
    
    /// Detects text category based on content analysis
    private func detectTextCategory(text: String, codeSource: CodeSource?) -> HistoryItemCategory {
        if let codeSource, codeSource != .unknown {
            return .code
        }

        // Check for URLs
        if isURL(text: text) {
            return .url
        }
        
        // Check for code patterns
        if isCode(text: text) {
            return .code
        }
        
        return .text
    }
    
    /// Checks if text contains a URL
    private func isURL(text: String) -> Bool {
        let urlPattern = #"https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(?:/[^\s]*)?"#
        let regex = try? NSRegularExpression(pattern: urlPattern)
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex?.firstMatch(in: text, options: [], range: range) != nil
    }
    
    /// Checks if text appears to be code
    private func isCode(text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return false }
        
        var codeIndicators = 0
        let totalLines = min(lines.count, 10) // Check first 10 lines
        
        for line in lines.prefix(totalLines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmedLine.isEmpty { continue }
            
            // Check for common code patterns
            if hasCodePatterns(line: trimmedLine) {
                codeIndicators += 1
            }
        }
        
        // If more than 30% of lines show code patterns, consider it code
        return Double(codeIndicators) / Double(totalLines) > 0.3
    }
    
    /// Checks for common code patterns in a line
    private func hasCodePatterns(line: String) -> Bool {
        // Keywords and patterns that suggest code
        let codePatterns = [
            // Keywords
            "function", "class", "import", "export", "const", "let", "var",
            "if", "else", "for", "while", "switch", "case", "break", "return",
            "public", "private", "protected", "static", "final", "abstract",
            "interface", "extends", "implements", "throws", "try", "catch",
            "def", "end", "begin", "rescue", "yield", "module", "namespace",
            "using", "include", "require", "from", "as", "with", "lambda",
            "async", "await", "void", "int", "string", "float", "bool", "true", "false", "null", "nil",
            "func", "fun",

            // Operators and symbols
            "=>", "->", "::", "++", "--", "!=", "==", "===", "!==",
            "&&", "||", "&", "|", "^", "~", "<<", ">>", ">>>",
            
            // Brackets and parentheses
            "{", "}", "[", "]", "(", ")", "<", ">",
            
            // Comments
            "//", "/*", "*/", "#", "--", "<!--", "-->",
            
            // String literals
            "\"", "'", "`",
            
            // Semicolons and colons
            ";", ":",
            
            // Common function calls
            "console.log", "print", "printf", "echo", "System.out.println"
        ]
        
        for pattern in codePatterns {
            if line.contains(pattern) {
                return true
            }
        }
        
        // Check for indentation patterns (tabs or multiple spaces)
        if line.hasPrefix("\t") || line.hasPrefix("    ") {
            return true
        }
        
        return false
    }
    
    /// Detects the source application for code items
    private func detectCodeSource(for item: HistoryItem) -> CodeSource? {
        guard let bundleID = item.originBundleId?.lowercased() else { return nil }
        return CodeSource(bundleId: bundleID)
    }
}
