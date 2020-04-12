//
//  GeneralSettingsViewController.swift
//  Yippy
//
//  Created by Matthew Davidson on 12/4/20.
//  Copyright © 2020 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import RxSwift

class GeneralSettingsViewController: NSViewController {
    
    
    @IBOutlet var maxHistoryItemsPopUpButton: NSPopUpButton!
    @IBOutlet var showsRichTextButton: NSButton!
    @IBOutlet var pastesRichTextButton: NSButton!
    
    private var disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMaxHistoryItemsPopUpButton()
        setupShowsRichTextButton()
        setupPastesRichTextButton()
    }
    
    // MARK: Setup view
    
    private func setupMaxHistoryItemsPopUpButton() {
        maxHistoryItemsPopUpButton.removeAllItems()
        for val in Constants.settings.maxHistoryItemsOptions {
            maxHistoryItemsPopUpButton.addItem(withTitle: "\(val)")
        }
        
        State.main.history.maxItems.subscribe(onNext: onMaxHistoryItems).disposed(by: disposeBag)
        
        maxHistoryItemsPopUpButton.target = self
        maxHistoryItemsPopUpButton.action = #selector(onMaxItemsSelected)
        maxHistoryItemsPopUpButton.isEnabled = true
        maxHistoryItemsPopUpButton.autoenablesItems = true
    }
    
    private func setupShowsRichTextButton() {
        State.main.showsRichText.subscribe(onNext: onShowsRichText).disposed(by: disposeBag)
        
        showsRichTextButton.target = self
        showsRichTextButton.action = #selector(onShowsRichTextButtonClicked)
    }
    
    private func setupPastesRichTextButton() {
        State.main.pastesRichText.subscribe(onNext: onPastesRichText).disposed(by: disposeBag)
        
        pastesRichTextButton.target = self
        pastesRichTextButton.action = #selector(onPastesRichTextButtonClicked)
    }
    
    // MARK: Bind to settings
    
    private func onMaxHistoryItems(_ maxItems: Int) {
        let newIndex = Constants.settings.maxHistoryItemsOptions.firstIndex(of: maxItems) ?? Constants.settings.maxHistoryItemsDefaultIndex
        if newIndex != maxHistoryItemsPopUpButton.indexOfSelectedItem {
            maxHistoryItemsPopUpButton.selectItem(at: newIndex)
        }
    }
    
    private func onShowsRichText(_ showsRichText: Bool) {
        showsRichTextButton.state = showsRichText ? .on : .off
    }
    
    private func onPastesRichText(_ pastesRichText: Bool) {
        pastesRichTextButton.state = pastesRichText ? .on : .off
    }
    
    // MARK: Handle Actions
    
    @objc private func onMaxItemsSelected() {
        State.main.history.setMaxItems(Constants.settings.maxHistoryItemsOptions[maxHistoryItemsPopUpButton.indexOfSelectedItem])
    }
    
    @objc private func onShowsRichTextButtonClicked() {
        State.main.showsRichText.accept(showsRichTextButton.state == .on)
    }
    
    @objc private func onPastesRichTextButtonClicked() {
        State.main.pastesRichText.accept(pastesRichTextButton.state == .on)
    }
}
