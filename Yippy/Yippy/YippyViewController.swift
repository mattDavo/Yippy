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
    
    @IBOutlet var collectionView: NSCollectionView!
    
    let sectionInset = NSEdgeInsets(top: 0.0, left: 20.0, bottom: 10.0, right: 20.0)
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.layer?.backgroundColor = .clear
        collectionView.allowsEmptySelection = false
        
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: 160.0, height: 140.0)
        flowLayout.sectionInset = sectionInset
        flowLayout.minimumLineSpacing = 5.0
        collectionView.collectionViewLayout = flowLayout
        view.wantsLayer = true
        collectionView.layer?.backgroundColor = NSColor.black.cgColor
        
        YippyHotKeys.downArrow.onDown(goToNextItem)
        YippyHotKeys.downArrow.onLong(goToNextItem)

        YippyHotKeys.upArrow.onDown(goToPreviousItem)
        YippyHotKeys.upArrow.onLong(goToPreviousItem)

        YippyHotKeys.escape.onDown {
            State.main.isHistoryPanelShown.accept(false)
        }
        
        YippyHotKeys.return.onDown {
            State.main.isHistoryPanelShown.accept(false)
            if State.main.selected != 0 {
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
                pasteboard.setString(State.main.history.value[State.main.selected], forType: NSPasteboard.PasteboardType.string)
                State.main.history.accept(State.main.history.value.without(elementAt: State.main.selected))
            }
            Helper.pressCommandV()
        }
        
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.downArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.upArrow, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.return, disposeBag: disposeBag)
        bindHotKeyToYippyWindow(yippyHotKey: YippyHotKeys.escape, disposeBag: disposeBag)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        collectionView.reloadData()
        if collectionView.numberOfItems(inSection: 0) > 0 {
            collectionView.selectItems(at: Set(arrayLiteral: IndexPath(item: 0, section: 0)), scrollPosition: .bottom)
        }
        State.main.selected = 0
    }
    
    func frameWillChange() {
        collectionView.reloadData()
    }
    
    func frameDidChange() {
        if collectionView.numberOfItems(inSection: 0) > 0 {
            collectionView.selectItems(at: Set(arrayLiteral: IndexPath(item: State.main.selected, section: 0)), scrollPosition: .bottom)
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
        if State.main.selected < State.main.history.value.count - 1 {
            collectionView.selectItems(at: Set(arrayLiteral: IndexPath(item: State.main.selected + 1, section: 0)), scrollPosition: .nearestHorizontalEdge)
            collectionView.deselectItems(at: Set(arrayLiteral: IndexPath(item: State.main.selected, section: 0)))
            State.main.selected += 1
        }
    }
    
    func goToPreviousItem() {
        if State.main.selected > 0 {
            collectionView.selectItems(at: Set(arrayLiteral: IndexPath(item: State.main.selected - 1, section: 0)), scrollPosition: .nearestHorizontalEdge)
            collectionView.deselectItems(at: Set(arrayLiteral: IndexPath(item: State.main.selected, section: 0)))
            State.main.selected -= 1
        }
    }
}

extension YippyViewController: NSCollectionViewDataSource {
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return State.main.history.value.count
    }
    
    func collectionView(_ itemForRepresentedObjectAtcollectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: YippyItem.identifier), for: indexPath)
        guard let cell = item as? YippyItem else {return item}
        
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
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        if let first = indexPaths.first {
            State.main.selected = first.item
        }
    }
}

extension YippyViewController: NSCollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {

        let width = floor(collectionView.frame.width - sectionInset.left - sectionInset.right)
        
        let attrStr = NSAttributedString(string: State.main.history.value[indexPath.item], attributes: [.font: YippyItem.font])
        
        let bRect = attrStr.boundingRect(with: NSSize(width: width - YippyItem.padding.left - YippyItem.padding.right, height: Constants.panel.maxCellHeight - YippyItem.padding.top - YippyItem.padding.bottom), options: .usesLineFragmentOrigin)
        
        let height = bRect.height + YippyItem.padding.top + YippyItem.padding.bottom

        return NSSize(width: width, height: ceil(height))
    }
}
