//
//  YippyItemBaseCellView.swift
//  Yippy
//
//  Created by Matthew Davidson on 13/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

/// Abstract base class for all Yippy collection view items.
///
/// Creates and sets up the `contentView`, `shortcutTextView`, `itemTextView`, and the info bar under the content
/// (source app, when it was copied, its name and the `favouriteButton`).
///
/// Handles highlight changes and the right-click menu.
class YippyItemBaseCellView: NSTableCellView {
    
    /// Height of the info bar, which sits in the bottom inset.
    static let infoBarHeight: CGFloat = 16
    
    static let contentViewInsets = NSEdgeInsets(top: 5, left: 5, bottom: 5 + infoBarHeight + 2, right: 5)
    
    class var identifier: NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier("YippyItemBaseCellView")
    }
    
    var contentView: YippyItemContentView!
    var shortcutTextView: YippyItemCellTextView!
    var itemTextView: YippyItemCellTextView!
    var favouriteButton: NSButton!
    var sourceAppIconView: NSImageView!
    var infoTextField: NSTextField!
    
    private var lastSetSelected: Bool?
    
    /// The table and item this cell was last set up for, which the heart and the menu act on.
    private weak var yippyTableView: YippyTableView?
    private var historyItem: HistoryItem?
    
    override func updateLayer() {
        super.updateLayer()
        
        guard let lastSetSelected = self.lastSetSelected else { return }
        if !lastSetSelected { return }
        layer?.backgroundColor = DesignTokens.Color.accent.cgColor
    }
    
    static let shortcutStringAttributes: [NSAttributedString.Key: Any] = [
        .font: Constants.fonts.yippyPlainText,
        .foregroundColor: DesignTokens.Color.textOnAccent
    ]
    
    func setHighlight(isSelected: Bool) {
        // Cairn's selection is the Ember accent around the card, the newest stone's colour
        layer?.backgroundColor = isSelected ? DesignTokens.Color.accent.cgColor : NSColor.clear.cgColor
        self.lastSetSelected = isSelected
        infoTextField?.textColor = isSelected ? DesignTokens.Color.textOnAccent : DesignTokens.Color.secondaryText
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        commonInit()
    }
    
    func commonInit() {
        contentView = YippyItemContentView(frame: .zero)
        addSubview(contentView)
        itemTextView = YippyItemCellTextView(frame: .zero)
        contentView.addSubview(itemTextView)
        shortcutTextView = YippyItemCellTextView(frame: .zero)
        contentView.addSubview(shortcutTextView)
        
        wantsLayer = true
        layer?.cornerRadius = DesignTokens.Radius.card
        itemTextView.drawsBackground = false
        itemTextView.setAccessibilityIdentifier(Accessibility.identifiers.yippyItemTextView)
        
        setupContentView()
        setupShortcutTextView()
        setupFavouriteButton()
        setupInfoBar()
    }
    
    func setupContentView() {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = DesignTokens.Radius.card - Self.contentViewInsets.left
        
        addConstraint(NSLayoutConstraint(item: contentView!, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: Self.contentViewInsets.left))
        addConstraint(NSLayoutConstraint(item: contentView!, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: Self.contentViewInsets.top))
        addConstraint(NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: contentView, attribute: .trailing, multiplier: 1, constant: Self.contentViewInsets.right))
        addConstraint(NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: contentView, attribute: .bottom, multiplier: 1, constant: Self.contentViewInsets.bottom))
    }
    
    func setupShortcutTextView() {
        shortcutTextView.translatesAutoresizingMaskIntoConstraints = false
        shortcutTextView.wantsLayer = true
        shortcutTextView.isSelectable = false
        shortcutTextView.textContainer?.lineFragmentPadding = 0
        shortcutTextView.alignment = .right
        shortcutTextView.textContainerInset = NSSize(width: 5, height: 2)
        shortcutTextView.layer?.cornerRadius = DesignTokens.Radius.card - Self.contentViewInsets.left
        shortcutTextView.layer?.maskedCorners = .layerMinXMaxYCorner
        shortcutTextView.isHorizontallyResizable = false
        shortcutTextView.isVerticallyResizable = false
        shortcutTextView.backgroundColor = DesignTokens.Color.accent
        shortcutTextView.layer?.zPosition = 1
        
        contentView.addConstraint(NSLayoutConstraint(item: shortcutTextView!, attribute: .top, relatedBy: .equal, toItem: contentView, attribute: .top, multiplier: 1, constant: 0))
        contentView.addConstraint(NSLayoutConstraint(item: contentView!, attribute: .trailing, relatedBy: .equal, toItem: shortcutTextView, attribute: .trailing, multiplier: 1, constant: 0))
        shortcutTextView.widthAnchor.constraint(equalToConstant: 0, withIdentifier: "width")?.isActive = true
        shortcutTextView.heightAnchor.constraint(equalToConstant: 0, withIdentifier: "height")?.isActive = true
    }
    
    func getShortcutTextViewSize() -> NSSize {
        // Determine the size of the text in one line
        let bRect = shortcutTextView.attributedString().getSingleLineSize()
        return NSSize(width: bRect.width + shortcutTextView.textContainer!.lineFragmentPadding + shortcutTextView.textContainerInset.width * 2, height: bRect.height + shortcutTextView.textContainerInset.height * 2)
    }
    
    func updateShortcutTextViewContraints() {
        let size = getShortcutTextViewSize()
        shortcutTextView.constraint(withIdentifier: "width")?.constant = ceil(size.width)
        shortcutTextView.constraint(withIdentifier: "height")?.constant = ceil(size.height)
    }
    
    func setupShortcutTextView(at i: Int) {
        let shortcutStr = NSAttributedString(string: i < 10 ? "⌘ + \(i)" : "", attributes: Self.shortcutStringAttributes)
        shortcutTextView.attributedText = shortcutStr
        shortcutTextView.isHidden = i >= 10
        updateShortcutTextViewContraints()
    }
    
    // MARK: - Favourite button
    
    /// Creates the heart at the right of the info bar.
    func setupFavouriteButton() {
        favouriteButton = NSButton(frame: .zero)
        favouriteButton.translatesAutoresizingMaskIntoConstraints = false
        favouriteButton.isBordered = false
        favouriteButton.focusRingType = .none
        favouriteButton.imageScaling = .scaleProportionallyDown
        favouriteButton.target = self
        favouriteButton.action = #selector(favouriteButtonClicked)
        favouriteButton.setAccessibilityIdentifier(Accessibility.identifiers.yippyFavouriteButton)
        favouriteButton.wantsLayer = true
        favouriteButton.layer?.zPosition = 1
        addSubview(favouriteButton)
        
        NSLayoutConstraint.activate([
            favouriteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            favouriteButton.topAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 2),
            favouriteButton.widthAnchor.constraint(equalToConstant: 14),
            favouriteButton.heightAnchor.constraint(equalToConstant: 14),
        ])
        
        setIsFavourite(false)
    }
    
    /// Points the heart, the info bar and the right-click menu at `historyItem`.
    func setupRowControls(withYippyTableView yippyTableView: YippyTableView, forHistoryItem historyItem: HistoryItem) {
        self.yippyTableView = yippyTableView
        self.historyItem = historyItem
        setIsFavourite(yippyTableView.yippyDelegate?.yippyTableView(yippyTableView, isFavourite: historyItem) ?? false)
        setupInfoBar(forHistoryItem: historyItem)
    }
    
    /// Fills the heart in red for a favourite, otherwise shows it as an outline.
    func setIsFavourite(_ isFavourite: Bool) {
        favouriteButton.toolTip = isFavourite ? "Remove from favourites (⌃F)" : "Add to favourites (⌃F)"
        
        let color = isFavourite ? DesignTokens.Color.favourite : DesignTokens.Color.secondaryText
        if #available(OSX 11.0, *) {
            favouriteButton.image = NSImage(systemSymbolName: isFavourite ? "heart.fill" : "heart", accessibilityDescription: isFavourite ? "Remove from favourites" : "Add to favourites")
            favouriteButton.imagePosition = .imageOnly
            favouriteButton.contentTintColor = color
        }
        else {
            // SF Symbols need macOS 11, so draw the heart as text
            favouriteButton.image = nil
            favouriteButton.imagePosition = .noImage
            favouriteButton.attributedTitle = NSAttributedString(string: isFavourite ? "♥" : "♡", attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: color,
            ])
        }
    }
    
    /// Subclasses add their content over the whole `contentView` after the heart, so without this the content would take the clicks meant for the heart.
    override func hitTest(_ point: NSPoint) -> NSView? {
        if !favouriteButton.isHidden, favouriteButton.bounds.contains(favouriteButton.convert(point, from: superview)) {
            return favouriteButton
        }
        return super.hitTest(point)
    }
    
    // MARK: - Info bar
    
    /// Creates the source app's icon and the line of text after it, under the item's content.
    func setupInfoBar() {
        sourceAppIconView = NSImageView(frame: .zero)
        sourceAppIconView.translatesAutoresizingMaskIntoConstraints = false
        sourceAppIconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(sourceAppIconView)
        
        infoTextField = NSTextField(labelWithString: "")
        infoTextField.translatesAutoresizingMaskIntoConstraints = false
        infoTextField.font = NSFont.systemFont(ofSize: 10)
        infoTextField.textColor = DesignTokens.Color.secondaryText
        infoTextField.lineBreakMode = .byTruncatingTail
        infoTextField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        infoTextField.setAccessibilityIdentifier(Accessibility.identifiers.yippyItemInfoText)
        addSubview(infoTextField)
        
        NSLayoutConstraint.activate([
            sourceAppIconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            sourceAppIconView.centerYAnchor.constraint(equalTo: favouriteButton.centerYAnchor),
            sourceAppIconView.widthAnchor.constraint(equalToConstant: 14),
            sourceAppIconView.heightAnchor.constraint(equalToConstant: 14),
            infoTextField.leadingAnchor.constraint(equalTo: sourceAppIconView.trailingAnchor, constant: 4),
            infoTextField.centerYAnchor.constraint(equalTo: favouriteButton.centerYAnchor),
            infoTextField.trailingAnchor.constraint(lessThanOrEqualTo: favouriteButton.leadingAnchor, constant: -6),
        ])
    }
    
    /// Shows the item's name (if it has one), the app it was copied from and how long ago.
    func setupInfoBar(forHistoryItem historyItem: HistoryItem) {
        let metadata = historyItem.metadata
        var parts = [String]()
        if let title = metadata.title, !title.isEmpty {
            parts.append(title)
        }
        if let source = metadata.sourceBundleId {
            parts.append(AppInfo.name(forBundleId: source))
            sourceAppIconView.image = AppInfo.icon(forBundleId: source)
        }
        else {
            sourceAppIconView.image = nil
        }
        if let copiedAt = metadata.copiedAt {
            parts.append(HistoryItemMetadata.timeAgo(copiedAt))
        }
        infoTextField.stringValue = parts.joined(separator: " · ")
        infoTextField.toolTip = metadata.copiedAt.map({ DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .short) })
    }
    
    @objc func favouriteButtonClicked() {
        guard let yippyTableView = yippyTableView, let historyItem = historyItem else { return }
        yippyTableView.yippyDelegate?.yippyTableView(yippyTableView, didToggleFavouriteOf: historyItem)
    }
    
    // MARK: - Right-click menu
    
    override func rightMouseDown(with event: NSEvent) {
        guard let yippyTableView = yippyTableView, let historyItem = historyItem else { return }
        let isFavourite = yippyTableView.yippyDelegate?.yippyTableView(yippyTableView, isFavourite: historyItem) ?? false
        
        let menu = NSMenu(title: "Item")
        menu.autoenablesItems = false
        
        let paste = NSMenuItem(title: "Paste", action: #selector(pasteMenuItemClicked), keyEquivalent: "")
        let pastePlainText = NSMenuItem(title: "Paste as Plain Text", action: #selector(pastePlainTextMenuItemClicked), keyEquivalent: "")
        pastePlainText.isEnabled = historyItem.getUnstyledText() != nil
        let favourite = NSMenuItem(title: isFavourite ? "Remove from Favourites" : "Add to Favourites", action: #selector(favouriteButtonClicked), keyEquivalent: "")
        
        for menuItem in [paste, pastePlainText, favourite] {
            menuItem.target = self
        }
        menu.addItem(paste)
        menu.addItem(pastePlainText)
        if let transformed = makeTransformMenuItem(for: historyItem) {
            menu.addItem(transformed)
        }
        if let recognizedText = historyItem.metadata.recognizedText, !recognizedText.isEmpty {
            menu.addItem(makePasteTextMenuItem(title: "Paste Text from Image", text: recognizedText))
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(favourite)
        
        if yippyTableView.yippyDelegate?.yippyTableView(yippyTableView, canEdit: historyItem) ?? false {
            let rename = NSMenuItem(title: "Rename…", action: #selector(renameMenuItemClicked), keyEquivalent: "")
            let edit = NSMenuItem(title: "Edit Text…", action: #selector(editMenuItemClicked), keyEquivalent: "")
            edit.isEnabled = historyItem.getUnstyledText() != nil
            for menuItem in [rename, edit] {
                menuItem.target = self
                menu.addItem(menuItem)
            }
        }
        
        if let source = historyItem.metadata.sourceBundleId {
            menu.addItem(NSMenuItem.separator())
            let filter = NSMenuItem(title: "Show Only Items from \(AppInfo.name(forBundleId: source))", action: #selector(filterByAppMenuItemClicked), keyEquivalent: "")
            filter.target = self
            menu.addItem(filter)
        }
        
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    /// The "Paste Transformed" submenu, with the transforms that change the item's text. Nil if the item has no text.
    private func makeTransformMenuItem(for historyItem: HistoryItem) -> NSMenuItem? {
        guard let text = historyItem.getUnstyledText() else {
            return nil
        }
        let submenu = NSMenu(title: "Paste Transformed")
        submenu.autoenablesItems = false
        for transform in TextTransform.allCases {
            let result = transform.apply(to: text)
            let menuItem = makePasteTextMenuItem(title: transform.title, text: result ?? text)
            menuItem.isEnabled = result != nil && result != text
            submenu.addItem(menuItem)
        }
        let menuItem = NSMenuItem(title: "Paste Transformed", action: nil, keyEquivalent: "")
        menuItem.submenu = submenu
        return menuItem
    }
    
    /// A menu item that pastes `text` instead of the item.
    private func makePasteTextMenuItem(title: String, text: String) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: #selector(pasteTextMenuItemClicked(_:)), keyEquivalent: "")
        menuItem.target = self
        menuItem.representedObject = text
        return menuItem
    }
    
    @objc private func pasteTextMenuItemClicked(_ sender: NSMenuItem) {
        guard let yippyTableView = yippyTableView, let historyItem = historyItem, let text = sender.representedObject as? String else { return }
        yippyTableView.yippyDelegate?.yippyTableView(yippyTableView, didRequestPasteOf: historyItem, text: text)
    }
    
    @objc private func renameMenuItemClicked() {
        guard let yippyTableView = yippyTableView, let historyItem = historyItem else { return }
        yippyTableView.yippyDelegate?.yippyTableView(yippyTableView, didRequestRenameOf: historyItem)
    }
    
    @objc private func editMenuItemClicked() {
        guard let yippyTableView = yippyTableView, let historyItem = historyItem else { return }
        yippyTableView.yippyDelegate?.yippyTableView(yippyTableView, didRequestEditOf: historyItem)
    }
    
    @objc private func filterByAppMenuItemClicked() {
        guard let yippyTableView = yippyTableView, let source = historyItem?.metadata.sourceBundleId else { return }
        yippyTableView.yippyDelegate?.yippyTableView(yippyTableView, didRequestItemsFromApp: source)
    }
    
    @objc private func pasteMenuItemClicked() {
        requestPaste(plainText: false)
    }
    
    @objc private func pastePlainTextMenuItemClicked() {
        requestPaste(plainText: true)
    }
    
    private func requestPaste(plainText: Bool) {
        guard let yippyTableView = yippyTableView, let historyItem = historyItem else { return }
        yippyTableView.yippyDelegate?.yippyTableView(yippyTableView, didRequestPasteOf: historyItem, plainText: plainText)
    }
}
