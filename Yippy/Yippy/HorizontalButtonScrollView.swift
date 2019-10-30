//
//  HorizontalButtonScrollView.swift
//  Yippy
//
//  Created by Matthew Davidson on 30/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import RxSwift
import RxRelay

class HorizontalButtonScrollView: NSScrollView {
    
    private var buttons = [NSButton]()
    private var buttonsDocumentView = NSView(frame: .zero)
    
    var leftPadding: CGFloat = 20
    var rightPadding: CGFloat = 20
    var innerPadding: CGFloat = 10
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        commonInit()
    }
    
    private func commonInit() {
        horizontalScrollElasticity = .automatic
        verticalScrollElasticity = .none
    }
    
    func bind(toData data: Observable<[String]>) -> Disposable {
        return data.bind(onNext: {
            self.buttons = self.createButtons(data: $0)
            self.buttonsDocumentView = NSView()
            self.buttons.forEach({self.buttonsDocumentView.addSubview($0)})
            self.layoutButtons()
        })
    }
    
    func bind(toSelected selected: Observable<Int>) -> Disposable {
        return selected.bind(onNext: {
            self.updateSelected($0)
        })
    }
    
    private func createButtons(data: [String]) -> [NSButton] {
        return data.enumerated().map({
            let button = NSButton(title: $1, target: self, action: #selector(buttonHandler(_:)))
            button.bezelStyle = .recessed
            button.setButtonType(.onOff)
            button.tag = $0
            button.state = .off
            return button
        })
    }
    
    private func getWidth(buttons: [NSButton]) -> CGFloat {
        return buttons.reduce(0, {$0 + $1.frame.width}) + CGFloat(buttons.count - 1) * innerPadding
    }
    
    private func layoutButtons() {
        let buttonWidth = getWidth(buttons: buttons)
        let totalWidth = buttonWidth + leftPadding + rightPadding
        let documentViewWidth = totalWidth < contentView.frame.width ? contentView.frame.width : totalWidth
        self.buttonsDocumentView.frame = CGRect(x: 0, y: 0, width: documentViewWidth, height: contentView.frame.height)
        
        var x: CGFloat = leftPadding
        if totalWidth < contentView.frame.width {
            x = contentView.frame.midX - buttonWidth/2
        }
        
        for button in buttons {
            button.setFrameOrigin(NSPoint(x: x, y: 0))
            x += button.frame.width + innerPadding
        }
        
        self.documentView = buttonsDocumentView
    }
    
    private func updateSelected(_ selected: Int?) {
        for (i, button) in buttons.enumerated() {
            button.state = i == selected ? .on : .off
        }
    }
    
    @objc private func buttonHandler(_ sender: NSButton) {
        updateSelected(sender.tag)
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        
        layoutButtons()
    }
}
