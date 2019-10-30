//
//  YippyViewController.swift
//  Yippy
//
//  Created by Matthew Davidson on 26/7/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Cocoa
import HotKey
import RxSwift
import RxRelay
import RxCocoa

class YippyViewController: NSViewController {
    
    @IBOutlet var yippyHistoryView: YippyTableView!
    
    @IBOutlet var itemGroupScrollView: HorizontalButtonScrollView!
    
    var yippyHistory = YippyHistory(history: State.main.history, items: [])
    
    let disposeBag = DisposeBag()
    
    var isPreviewShowing = false
    
    var itemGroups = BehaviorRelay<[String]>(value: ["Clipboard", "Favourites", "Clipboard", "Favourites", "Clipboard", "Favourites"])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        yippyHistoryView.yippyDelegate = self
        
        State.main.history.subscribe(onNext: onHistoryChange)
        State.main.history.selected.withPrevious(startWith: nil).subscribe(onNext: onSelectedChange).disposed(by: disposeBag)
        
        itemGroupScrollView.bind(toData: itemGroups.asObservable()).disposed(by: disposeBag)
        itemGroupScrollView.bind(toSelected: BehaviorRelay<Int>(value: 0).asObservable()).disposed(by: disposeBag)
        
        YippyHotKeys.downArrow.onDown(goToNextItem)
        YippyHotKeys.downArrow.onLong(goToNextItem)
        YippyHotKeys.pageDown.onDown(goToNextItem)
        YippyHotKeys.pageDown.onLong(goToNextItem)
        YippyHotKeys.upArrow.onDown(goToPreviousItem)
        YippyHotKeys.upArrow.onLong(goToPreviousItem)
        YippyHotKeys.pageUp.onDown(goToPreviousItem)
        YippyHotKeys.pageUp.onLong(goToPreviousItem)
        YippyHotKeys.escape.onDown(close)
        YippyHotKeys.return.onDown(pasteSelected)
        YippyHotKeys.cmdLeftArrow.onDown { State.main.panelPosition.accept(.left) }
        YippyHotKeys.cmdRightArrow.onDown { State.main.panelPosition.accept(.right) }
        YippyHotKeys.cmdDownArrow.onDown { State.main.panelPosition.accept(.bottom) }
        YippyHotKeys.cmdUpArrow.onDown { State.main.panelPosition.accept(.top) }
        YippyHotKeys.cmdDelete.onDown(deleteSelected)
        YippyHotKeys.space.onDown(togglePreview)
        
        // Paste hot keys
        YippyHotKeys.cmd0.onDown { self.shortcutPressed(key: 0) }
        YippyHotKeys.cmd1.onDown { self.shortcutPressed(key: 1) }
        YippyHotKeys.cmd2.onDown { self.shortcutPressed(key: 2) }
        YippyHotKeys.cmd3.onDown { self.shortcutPressed(key: 3) }
        YippyHotKeys.cmd4.onDown { self.shortcutPressed(key: 4) }
        YippyHotKeys.cmd5.onDown { self.shortcutPressed(key: 5) }
        YippyHotKeys.cmd6.onDown { self.shortcutPressed(key: 6) }
        YippyHotKeys.cmd7.onDown { self.shortcutPressed(key: 7) }
        YippyHotKeys.cmd8.onDown { self.shortcutPressed(key: 8) }
        YippyHotKeys.cmd9.onDown { self.shortcutPressed(key: 9) }
        
        bindHotKeyToYippyWindow(YippyHotKeys.downArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.upArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.return, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.escape, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.pageDown, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.pageUp, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmdLeftArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmdRightArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmdDownArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmdUpArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd0, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd1, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd2, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd3, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd4, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd5, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd6, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd7, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd8, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmd9, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.cmdDelete, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(YippyHotKeys.space, disposeBag: disposeBag)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        isPreviewShowing = false
        if yippyHistory.items.count > 0 {
            State.main.history.setSelected(0)
        }
        else {
            State.main.history.setSelected(nil)
        }
    }
    
    func onHistoryChange(_ history: [HistoryItem]) {
        yippyHistory = YippyHistory(history: State.main.history, items: history)
        yippyHistoryView.reloadData(yippyHistory.items)
    }
    
    func onSelectedChange(_ previous: Int?, _ selected: Int?) {
        if let previous = previous {
            yippyHistoryView.deselectItem(previous)
            yippyHistoryView.reloadItem(previous)
        }
        if let selected = selected {
            let currentSelection = yippyHistoryView.selected
            if currentSelection == nil || currentSelection != selected {
                yippyHistoryView.selectItem(selected)
            }
            yippyHistoryView.reloadItem(selected)
            
            if isPreviewShowing {
                State.main.previewHistoryItem.accept(yippyHistory.items[selected])
            }
        }
    }
    
    func bindHotKeyToYippyWindow(_ hotKey: YippyHotKey, disposeBag: DisposeBag) {
        State.main.isHistoryPanelShown
            .distinctUntilChanged()
            .subscribe(onNext: { [] in
                hotKey.isPaused = !$0
            })
            .disposed(by: disposeBag)
    }
    
    func goToNextItem() {
        if let selected = yippyHistoryView.selected {
            if selected < yippyHistory.items.count - 1 {
                State.main.history.setSelected(selected + 1)
            }
        }
    }
    
    func goToPreviousItem() {
        if let selected = yippyHistoryView.selected {
            if selected > 0 {
                State.main.history.setSelected(selected - 1)
            }
        }
    }
    
    func pasteSelected() {
        if let selected = self.yippyHistoryView.selected {
            State.main.isHistoryPanelShown.accept(false)
            State.main.history.setSelected(nil)
            yippyHistory.paste(selected: selected)
        }
    }
    
    func deleteSelected() {
        if let selected = self.yippyHistoryView.selected {
            yippyHistory.delete(selected: selected)
        }
    }
    
    func close() {
        State.main.isHistoryPanelShown.accept(false)
        State.main.previewHistoryItem.accept(nil)
        isPreviewShowing = false
    }
    
    func shortcutPressed(key: Int) {
        State.main.history.setSelected(key)
        pasteSelected()
    }
    
    func togglePreview() {
        if let selected = yippyHistoryView.selected {
            isPreviewShowing = !isPreviewShowing
            if isPreviewShowing {
                State.main.previewHistoryItem.accept(yippyHistory.items[selected])
            }
            else {
                State.main.previewHistoryItem.accept(nil)
            }
        }
    }
}

extension YippyViewController: YippyTableViewDelegate {
    func yippyTableView(_ yippyTableView: YippyTableView, selectedDidChange selected: Int?) {
        State.main.history.setSelected(selected)
    }
}
