//
//  YippyHistoryView.swift
//  Yippy
//
//  Created by Matthew Davidson on 2/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class YippyHistoryView: NSCollectionView {
    
    var selected: Int? {
        return selectionIndexPaths.first?.item
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        commonInit()
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        
        commonInit()
    }
    
    private func commonInit() {
        layer?.backgroundColor = .clear
        allowsEmptySelection = false
        setAccessibilityIdentifier(Accessibility.identifiers.yippyCollectionView)
        
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: 160.0, height: 140.0)
        flowLayout.sectionInset = sectionInset
        flowLayout.minimumLineSpacing = 5.0
        collectionViewLayout = flowLayout
        layer?.backgroundColor = NSColor.black.cgColor
    }
    
    func selectItem(_ i: Int) {
        selectItems(at: Set(arrayLiteral: IndexPath(item: i, section: 0)), scrollPosition: .nearestHorizontalEdge)
    }
    
    func deselectItem(_ i: Int) {
        deselectItems(at: Set(arrayLiteral: IndexPath(item: i, section: 0)))
    }
}
