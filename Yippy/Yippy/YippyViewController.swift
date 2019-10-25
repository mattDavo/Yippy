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
    
    @IBOutlet var yippyHistoryView: YippyHistoryView!
    
    var yippyHistory = YippyHistory(history: [])
    
    let disposeBag = DisposeBag()
    
    var isPreviewShowing = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        yippyHistoryView.dataSource = self
        yippyHistoryView.delegate = self
        
        State.main.history.subscribe(onNext: onHistoryChange)
        State.main.selected.withPrevious(startWith: nil).subscribe(onNext: onSelectedChange).disposed(by: disposeBag)
        
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
        
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.downArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.upArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.return, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.escape, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.pageDown, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.pageUp, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.cmdLeftArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.cmdRightArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.cmdDownArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.cmdUpArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.cmd0, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.cmd1, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.cmd2, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.cmd3, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.cmd4, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.cmd5, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.cmd6, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.cmd7, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.cmd8, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.cmd9, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.cmdDelete, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.space, disposeBag: disposeBag)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        isPreviewShowing = false
        yippyHistoryView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<yippyHistory.history.count))
        if yippyHistory.history.count > 0 {
            State.main.selected.accept(0)
        }
        else {
            State.main.selected.accept(nil)
        }
    }
    
    func onHistoryChange(_ history: [HistoryItem]) {
        yippyHistory = YippyHistory(history: history)
        yippyHistoryView.reloadData()
        view.displayIfNeeded()
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
                State.main.previewHistoryItem.accept(yippyHistory.history[selected])
            }
        }
    }
    
    func bindHotKeyToYippyWindow(yippyHotKey: YippyHotKey, disposeBag: DisposeBag) {
        State.main.isHistoryPanelShown
            .distinctUntilChanged()
            .subscribe(onNext: { [] in
                yippyHotKey.isPaused = !$0
            })
            .disposed(by: disposeBag)
    }
    
    func goToNextItem() {
        if let selected = yippyHistoryView.selected {
            if selected < yippyHistory.history.count - 1 {
                State.main.selected.accept(selected + 1)
            }
        }
    }
    
    func goToPreviousItem() {
        if let selected = yippyHistoryView.selected {
            if selected > 0 {
                State.main.selected.accept(selected - 1)
            }
        }
    }
    
    func pasteSelected() {
        if let selected = self.yippyHistoryView.selected {
            State.main.isHistoryPanelShown.accept(false)
            State.main.selected.accept(nil)
            yippyHistory.paste(selected: selected)
        }
    }
    
    func deleteSelected() {
        if let selected = self.yippyHistoryView.selected {
            yippyHistory.delete(selected: selected)
            
            // Assume no selection
            var select: Int? = nil
            // If the deleted item is not the last in the list then keep the selection index the same.
            if selected < yippyHistory.history.count {
                select = selected
            }
            // Otherwise if there is any items left, select the previous item
            else if selected > 0 {
                select = selected - 1
            }
            // No items, select nothing
            else {
                select = nil
            }
            State.main.selected.accept(select)
        }
    }
    
    func close() {
        State.main.isHistoryPanelShown.accept(false)
        State.main.previewHistoryItem.accept(nil)
        isPreviewShowing = false
    }
    
    func shortcutPressed(key: Int) {
        State.main.selected.accept(key)
        pasteSelected()
    }
    
    func togglePreview() {
        if let selected = yippyHistoryView.selected {
            isPreviewShowing = !isPreviewShowing
            if isPreviewShowing {
                State.main.previewHistoryItem.accept(yippyHistory.history[selected])
            }
            else {
                State.main.previewHistoryItem.accept(nil)
            }
        }
    }
}

extension YippyViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return yippyHistory.history.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let historyItem = yippyHistory.history[row]
        let itemType = historyItem.getTableViewItemType()
        let cell = tableView.makeView(withIdentifier: itemType.identifier, owner: nil) as? YippyItem ?? itemType.makeItem()
        cell.setupCell(withTableView: tableView, forHistoryItem: historyItem, atIndexPath: IndexPath(item: row, section: 0))
        if let cell = cell as? NSTableCellView {
            cell.setAccessibilityLabel(itemType.identifier.rawValue)
        }
        
        return cell as? NSView
    }
    
    func tableViewSelectionIsChanging(_ notification: Notification) {
        State.main.selected.accept(yippyHistoryView.selected)
    }
    
    func tableViewColumnDidResize(_ notification: Notification) {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        yippyHistoryView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<yippyHistory.history.count))
        NSAnimationContext.endGrouping()
        yippyHistoryView.redisplayVisible(yippyHistory: yippyHistory)
    }
}

extension YippyViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let historyItem = yippyHistory.history[row]
        return historyItem.getTableViewItemType().getItemHeight(withTableView: tableView, forHistoryItem: historyItem)
    }
}
