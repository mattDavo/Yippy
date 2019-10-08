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

let sectionInset = NSEdgeInsets(top: 0.0, left: 20.0, bottom: 0.0, right: 20.0)

class YippyViewController: NSViewController {
    
    @IBOutlet var yippyHistoryView: YippyHistoryView!
    
    var yippyHistory: YippyHistory!
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        yippyHistoryView.dataSource = self
        yippyHistoryView.delegate = self
        view.wantsLayer = true
        
        State.main.history.subscribe(onNext: onHistoryChange).disposed(by: disposeBag)
        State.main.selected.subscribe(onNext: onSelectedChange).disposed(by: disposeBag)
        
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
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        if yippyHistory.history.count > 0 {
            State.main.selected.accept(0)
        }
        else {
            State.main.selected.accept(nil)
        }
    }
    
    func onHistoryChange(_ history: [String]) {
        yippyHistory = YippyHistory(history: history)
        yippyHistoryView.reloadData()
        view.displayIfNeeded()
    }
    
    func onSelectedChange(_ selected: Int?) {
        if let selected = selected {
            let currentSelection = self.yippyHistoryView.selected
            if currentSelection == nil || currentSelection != selected {
                self.yippyHistoryView.selectItem(selected)
            }
        }
    }
    
    func frameWillChange() {
        yippyHistoryView.collectionViewLayout?.invalidateLayout()
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
        yippyHistoryView.moveDown(self)
    }
    
    func goToPreviousItem() {
        yippyHistoryView.moveUp(self)
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
    }
    
    func shortcutPressed(key: Int) {
        State.main.selected.accept(key)
        pasteSelected()
    }
}

extension YippyViewController: NSCollectionViewDataSource {
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return yippyHistory.history.count
    }
    
    func collectionView(_ itemForRepresentedObjectAtcollectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        let item = yippyHistoryView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: YippyItem.identifier), for: indexPath)
        guard let cell = item as? YippyItem else { return item }
        
        let itemStr = NSAttributedString(string: yippyHistory.history[indexPath.item], attributes: YippyItem.itemStringAttributes)
        cell.itemTextView.textStorage?.setAttributedString(itemStr)
        
        let shortcutStr = NSAttributedString(string: indexPath.item < 10 ? "⌘ + \(indexPath.item)" : "", attributes: YippyItem.shortcutStringAttributes)
        cell.shortcutTextView.textStorage?.setAttributedString(shortcutStr)
        cell.shortcutTextView.isHidden = indexPath.item >= 10
        cell.updateShortcutTextViewContraints()
        
        return cell
    }
}

extension YippyViewController: NSCollectionViewDelegate {
    
    func collectionView(_ collectionView: NSCollectionView, willDisplay item: NSCollectionViewItem, forRepresentedObjectAt indexPath: IndexPath) {
        if let item = item as? YippyItem {
            item.setHighlight()
        }
    }
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        State.main.selected.accept(indexPaths.first?.item)
    }
}

extension YippyViewController: NSCollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {

        // Calculate the width of the cell
        let cellWidth = floor(collectionView.frame.width - sectionInset.left - sectionInset.right)
        
        // Calculate the width of the text container
        let width = cellWidth - YippyItem.padding.left - YippyItem.padding.right - YippyItem.textInset.xTotal
        
        // Create an attributed string of the text
        let attrStr = NSAttributedString(string: yippyHistory.history[indexPath.item], attributes: [.font: YippyItem.font])
        
        // Get the max height of the text view
        let maxTextViewHeight = Constants.panel.maxCellHeight - YippyItem.padding.top - YippyItem.padding.bottom - YippyItem.textInset.yTotal
        
        // Determine the height of the text view (capping the cell height)
        let bRect = attrStr.boundingRect(with: NSSize(width: width, height: maxTextViewHeight), options: NSString.DrawingOptions.usesLineFragmentOrigin.union(.usesFontLeading))
        
        // Add the padding back to get the height of the cell
        let height = min(bRect.height, maxTextViewHeight) + YippyItem.padding.top + YippyItem.padding.bottom + YippyItem.textInset.yTotal
        
        return NSSize(width: cellWidth, height: ceil(height))
    }
}
