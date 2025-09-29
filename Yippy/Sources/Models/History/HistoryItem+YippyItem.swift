//
//  HistoryItem+YippyItem.swift
//  Yippy
//
//  Created by Matthew Davidson on 14/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation

extension HistoryItem {
    
    var content: HistoryItemContent {
        if getFileUrl() != nil {
            if getThumbnailImage() != nil {
                return .thumbnailImage
            }
            else {
                return .fileIcon
            }
        }
        else if getUrl() != nil {
            return .webLink
        }
        else if getColor() != nil {
            return .color
        }
        else if types.contains(.tiff) || types.contains(.png) {
            return .tiffOrPng
        }
        else {
            return .text
        }
    }
}

enum HistoryItemContent {
    case thumbnailImage
    case fileIcon
    case text
    case tiffOrPng
    case color
    case webLink
}
