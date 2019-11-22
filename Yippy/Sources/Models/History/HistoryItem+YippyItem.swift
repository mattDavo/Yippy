//
//  HistoryItem+YippyItem.swift
//  Yippy
//
//  Created by Matthew Davidson on 14/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation

extension HistoryItem {
    
    func getTableViewItemType() -> YippyItem.Type {
        if getFileUrl() != nil {
            if getThumbnailImage() != nil {
                return YippyFileThumbnailCellView.self
            }
            else {
                return YippyFileIconCellView.self
            }
        }
        else if getColor() != nil {
            return YippyColorCellView.self
        }
        else if types.contains(.tiff) {
            return YippyTiffCellView.self
        }
        else {
            return YippyTextCellView.self
        }
    }
}
