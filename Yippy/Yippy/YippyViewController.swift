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
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        yippyHistoryView.dataSource = self
        yippyHistoryView.delegate = self
        view.wantsLayer = true
        
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
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        yippyHistoryView.reloadData()
        if yippyHistoryView.numberOfItems(inSection: 0) > 0 {
            yippyHistoryView.selectItem(0)
        }
    }
    
    func frameWillChange() -> Int? {
        // Must get the selected item before data is reloaded and it is reset
        let selected = yippyHistoryView.selected
        yippyHistoryView.reloadData()
        return selected
    }
    
    func frameDidChange(selected: Int?) {
        if let selected = selected {
            yippyHistoryView.selectItem(selected)
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
        yippyHistoryView.moveDown(self)
    }
    
    func goToPreviousItem() {
        yippyHistoryView.moveUp(self)
    }
    
    func pasteSelected() {
        State.main.isHistoryPanelShown.accept(false)
        if let selected = self.yippyHistoryView.selected {
            if selected != 0 {
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
                pasteboard.setString(State.main.history.value[selected], forType: NSPasteboard.PasteboardType.string)
                State.main.history.accept(State.main.history.value.without(elementAt: selected))
            }
            Helper.pressCommandV()
        }
    }
    
    func close() {
        State.main.isHistoryPanelShown.accept(false)
    }
}

extension YippyViewController: NSCollectionViewDataSource {
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return State.main.history.value.count
    }
    
    func collectionView(_ itemForRepresentedObjectAtcollectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        let item = yippyHistoryView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: YippyItem.identifier), for: indexPath)
        guard let cell = item as? YippyItem else { return item }
        
        cell.textView.string = State.main.history.value[indexPath.item]
        cell.textView.setFont(YippyItem.font, range: NSRange(location: 0, length: State.main.history.value[indexPath.item].count))
        
        return cell
    }
}

extension YippyViewController: NSCollectionViewDelegate {
    
    func collectionView(_ collectionView: NSCollectionView, willDisplay item: NSCollectionViewItem, forRepresentedObjectAt indexPath: IndexPath) {
        if let item = item as? YippyItem {
            item.setHighlight()
        }
    }
}

extension YippyViewController: NSCollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {

        // Calculate the width of the cell
        let width = floor(collectionView.frame.width - sectionInset.left - sectionInset.right)
        
        // Create an attributed string of the text
        let attrStr = NSAttributedString(string: State.main.history.value[indexPath.item], attributes: [.font: YippyItem.font])
        
        // Determine the height of the text view (capping the cell height)
        let bRect = attrStr.boundingRect(with: NSSize(width: width - YippyItem.padding.left - YippyItem.padding.right, height: Constants.panel.maxCellHeight - YippyItem.padding.top - YippyItem.padding.bottom), options: .usesLineFragmentOrigin)
        
        // Add the padding back to get the height of the cell
        let height = bRect.height + YippyItem.padding.top + YippyItem.padding.bottom
        
        return NSSize(width: width, height: ceil(height))
    }
}
