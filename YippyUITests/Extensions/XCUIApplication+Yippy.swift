//
//  XCUIApplication+Yippy.swift
//  YippyUITests
//
//  Created by Matthew Davidson on 30/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import XCTest

extension XCUIApplication {
    
    var yippyCollectionView: XCUIElement {
        return yippyWindow.collectionViews[Accessibility.identifiers.yippyCollectionView]
    }
    
    var yippyCollectionViewItems: XCUIElementQuery {
        return yippyCollectionView.otherElements.children(matching: .group).matching(identifier: Accessibility.identifiers.yippyItem)
    }
    
    func getYippyCollectionViewCell(at i: Int) -> XCUIElement {
        return yippyCollectionViewItems.element(boundBy: i)
    }
    
    func getYippyCollectionViewCellTextView(at i: Int) -> XCUIElement {
        return yippyCollectionViewItems.element(boundBy: i).children(matching: .textView).element
    }
    
    func getYippyCollectionViewString(at i: Int) -> String? {
        return getYippyCollectionViewCellTextView(at: i).value as? String
    }
}
