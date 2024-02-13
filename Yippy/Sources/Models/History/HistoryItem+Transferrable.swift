//
//  HistoryItem+Transferrable.swift
//  Yippy
//
//  Created by v.prusakov on 2/13/24.
//  Copyright © 2024 MatthewDavidson. All rights reserved.
//

import SwiftUI

extension HistoryItem: Transferable {
    
    private enum TrasnferableError: Error {
        case failed
    }
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .rtf) { item in
            guard let data = item.data(forType: .rtf) else {
                throw TrasnferableError.failed
            }
            
            return data
        }
        
        DataRepresentation(exportedContentType: .png) { item in
            guard let data = item.data(forType: .png) else {
                throw TrasnferableError.failed
            }
            
            return data
        }
        
        DataRepresentation(exportedContentType: .tiff) { item in
            guard let data = item.data(forType: .tiff) else {
                throw TrasnferableError.failed
            }
            
            return data
        }
        
        DataRepresentation(exportedContentType: .fileURL) { item in
            guard let data = item.data(forType: .fileURL) else {
                throw TrasnferableError.failed
            }
            
            return data
        }
        
        FileRepresentation(exportedContentType: .fileURL) { item in
            guard let fileURL = item.getFileUrl() else {
                throw TrasnferableError.failed
            }
            return .init(fileURL)
        }
        
        DataRepresentation(exportedContentType: .url) { item in
            guard let data = item.data(forType: .URL) else {
                throw TrasnferableError.failed
            }
            
            return data
        }
        
        DataRepresentation(exportedContentType: .pdf) { item in
            guard let data = item.data(forType: .pdf) else {
                throw TrasnferableError.failed
            }
            
            return data
        }
    }
}
