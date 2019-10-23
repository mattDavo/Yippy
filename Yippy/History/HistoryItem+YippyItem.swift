//
//  HistoryItem+YippyItem.swift
//  Yippy
//
//  Created by Matthew Davidson on 14/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation

extension HistoryItem {
    
    func getCollectionViewItemType() -> YippyItem.Type {
        if getFileUrl() != nil {
            if getThumbnailImage() != nil {
                return YippyFileThumbnailItem.self
            }
            else {
                return YippyFileIconItem.self
            }
        }
        else if getColor() != nil {
            return YippyColorItem.self
        }
        else if types.contains(.tiff) {
            return YippyTiffItem.self
        }
        else {
            return YippyTextItem.self
        }
    }
}
