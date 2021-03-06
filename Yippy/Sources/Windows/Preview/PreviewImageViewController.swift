//
//  PreviewTiffViewController.swift
//  Yippy
//
//  Created by Matthew Davidson on 17/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class PreviewImageViewController: NSViewController, PreviewViewController {
    
    static let identifier = NSStoryboard.SceneIdentifier(stringLiteral: "PreviewImageViewController")
    
    var imageView: NSImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView = NSImageView(frame: .zero)
        view.addSubview(imageView)
        
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        // See: https://stackoverflow.com/a/24323553
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.addConstraint(NSLayoutConstraint(item: imageView!, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: imageView!, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: view, attribute: .trailing, relatedBy: .equal, toItem: imageView, attribute: .trailing, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal, toItem: imageView, attribute: .bottom, multiplier: 1, constant: 0))
    }
    
    func configureView(forItem item: HistoryItem) -> NSRect {
        // TODO: Fix with "Missing image" image
        let image = item.getImage() ?? NSImage(size: NSSize(width: 0, height: 0))
        imageView.image = image
        return calculateWindowFrame(forImage: image)
    }
    
    func calculateWindowFrame(forImage image: NSImage) -> NSRect {
        let maxWindowWidth = NSScreen.main!.frame.width * 0.8
        let maxWindowHeight = NSScreen.main!.frame.height * 0.8
        
        var windowWidth: CGFloat = 0
        var windowHeight: CGFloat = 0
        
        if image.size.width > image.size.height {
            windowWidth = min(maxWindowWidth, image.size.width)
            windowHeight = windowWidth * image.size.height/image.size.width
        }
        else {
            windowHeight = min(maxWindowHeight, image.size.height)
            windowWidth = windowHeight * image.size.width/image.size.height
        }
        
        let center = NSPoint(x: NSScreen.main!.frame.midX - windowWidth / 2, y: NSScreen.main!.frame.midY - windowHeight / 2)
        
        return NSRect(origin: center, size: NSSize(width: windowWidth, height: windowHeight))
    }
}
