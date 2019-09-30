//
//  YippyItem.swift
//  Yippy
//
//  Created by Matthew Davidson on 2/8/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Cocoa

class YippyItem: NSCollectionViewItem {
    
    class CustomTextView: NSTextView {
        
        override func mouseDown(with event: NSEvent) {
            self.nextResponder?.mouseDown(with: event)
        }
    }
    
    static let attributes: [NSAttributedString.Key: Any] = [:]
    
    static let padding = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
    
    var textView: CustomTextView!
    
    static let identifier = Accessibility.identifiers.yippyItem
    
    static let font = NSFont(name: "Roboto Mono Light for Powerline", size: 12)!
    
    override var isSelected: Bool {
        didSet {
            setHighlight()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        view.wantsLayer = true
        view.layer?.borderColor = NSColor.gray.cgColor
        view.layer?.borderWidth = 0.1
        view.layer?.cornerRadius = 7
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = .clear
        
        textView = CustomTextView(frame: view.frame)
        view.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.drawsBackground = true
        textView.wantsLayer = true
        textView.backgroundColor = .clear
        textView.isSelectable = false
        textView.textContainerInset = NSSize.zero
        textView.textContainer?.lineFragmentPadding = 0
        // Define the maximum size of the text container, so that the text renders correctly when there needs to be clipping.
        // Width can be any value
        textView.textContainer?.size = NSSize(width: 200, height: Constants.panel.maxCellHeight - YippyItem.padding.top - YippyItem.padding.bottom)
        
        view.addConstraint(NSLayoutConstraint(item: textView!, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1, constant: YippyItem.padding.left))
        view.addConstraint(NSLayoutConstraint(item: textView!, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: YippyItem.padding.top))
        view.addConstraint(NSLayoutConstraint(item: view, attribute: .trailing, relatedBy: .equal, toItem: textView, attribute: .trailing, multiplier: 1, constant: YippyItem.padding.right))
        view.addConstraint(NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal, toItem: textView, attribute: .bottom, multiplier: 1, constant: YippyItem.padding.bottom))
    }
    
    func setHighlight() {
        view.layer?.backgroundColor = self.isSelected ? NSColor.systemBlue.withAlphaComponent(0.5).cgColor : NSColor.lightGray.withAlphaComponent(0.5).cgColor
    }
}
