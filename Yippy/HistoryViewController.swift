//
//  HistoryViewController.swift
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

class HistoryViewController: NSViewController {
    
    @IBOutlet var collectionView: NSCollectionView!
    
    let sectionInset = NSEdgeInsets(top: 0.0, left: 20.0, bottom: 10.0, right: 20.0)
    
    let disposeBag = DisposeBag()
    
    var enterHotKey: HotKey!
    var escHotKey: HotKey!
    var downHotKey: HotKey!
    var upHotKey: HotKey!
    var downLongHotKey: LongHotKey!
    
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
        
        downHotKey = HotKey(keyCombo: KeyCombo(key: .downArrow, modifiers: []))
        downHotKey.keyDownHandler = { [weak self] in
            if let self = self {
                if selected < State.main.history.endIndex {
                    self.collectionView.selectItems(at: Set(arrayLiteral: IndexPath(item: selected + 1, section: 0)), scrollPosition: .nearestHorizontalEdge)
                    self.collectionView.deselectItems(at: Set(arrayLiteral: IndexPath(item: selected, section: 0)))
                    selected += 1
                }
            }
        }
        downHotKey.isPaused = true
        bindHotKeyToToggle(hotKey: downHotKey, disposeBag: disposeBag)
        
        upHotKey = HotKey(keyCombo: KeyCombo(key: .upArrow, modifiers: []))
        upHotKey.keyDownHandler = { [weak self] in
            if let self = self {
                if selected > 0 {
                    self.collectionView.selectItems(at: Set(arrayLiteral: IndexPath(item: selected - 1, section: 0)), scrollPosition: .nearestHorizontalEdge)
                    self.collectionView.deselectItems(at: Set(arrayLiteral: IndexPath(item: selected, section: 0)))
                    selected -= 1
                }
            }
        }
        upHotKey.isPaused = true
        bindHotKeyToToggle(hotKey: upHotKey, disposeBag: disposeBag)
        
        escHotKey = HotKey(keyCombo: KeyCombo(key: .escape, modifiers: []))
        escHotKey.keyDownHandler = { () in
            State.main.isHistoryPanelShown.accept(false)
        }
        escHotKey.isPaused = true
        bindHotKeyToToggle(hotKey: escHotKey, disposeBag: disposeBag)
        
        enterHotKey = HotKey(keyCombo: KeyCombo(key: .return, modifiers: []))
        enterHotKey.keyDownHandler = { [weak self] in
            if let _ = self {
                State.main.isPasteboardPaused.accept(true)
                State.main.isHistoryPanelShown.accept(false)
                if selected != 0 {
                    let pasteboard = NSPasteboard.general
                    pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
                    pasteboard.setString(State.main.history[selected], forType: NSPasteboard.PasteboardType.string)
                    State.main.history.remove(at: selected)
                }
                pasteEventMonitor.start()
                send(9, useCommandFlag: true)
            }
            
        }
        enterHotKey.isPaused = true
        bindHotKeyToToggle(hotKey: enterHotKey, disposeBag: disposeBag)
        
        downLongHotKey = LongHotKey(keyCombo: KeyCombo(key: .downArrow, modifiers: []))
        downLongHotKey.isPaused = true
        State.main.isHistoryPanelShown
            .subscribe(onNext: { [unowned self] in
                self.downLongHotKey.isPaused = !$0
            })
            .disposed(by: disposeBag)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        collectionView.reloadData()
        collectionView.selectItems(at: Set(arrayLiteral: IndexPath(item: 0, section: 0)), scrollPosition: .bottom)
        selected = 0
    }
    
    func frameWillChange() {
        collectionView.reloadData()
    }
    
    func frameDidChange() {
        collectionView.selectItems(at: Set(arrayLiteral: IndexPath(item: selected, section: 0)), scrollPosition: .bottom)
    }
}

extension HistoryViewController: NSCollectionViewDataSource {
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return State.main.history.count
    }
    
    func collectionView(_ itemForRepresentedObjectAtcollectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CollectionViewItem.identifier), for: indexPath)
        guard let cell = item as? CollectionViewItem else {return item}
        
        cell.textView.string = State.main.history[indexPath.item]
        cell.textView.setFont(CollectionViewItem.font, range: NSRange(location: 0, length: State.main.history[indexPath.item].count))
        
        return cell
    }
}

extension HistoryViewController: NSCollectionViewDelegate {
    
    func collectionView(_ collectionView: NSCollectionView, willDisplay item: NSCollectionViewItem, forRepresentedObjectAt indexPath: IndexPath) {
        if let item = item as? CollectionViewItem {
            item.setHighlight()
        }
    }
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        if let first = indexPaths.first {
            selected = first.item
        }
    }
}

extension HistoryViewController: NSCollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {

        let width = floor(collectionView.frame.width - sectionInset.left - sectionInset.right)
        
        let attrStr = NSAttributedString(string: State.main.history[indexPath.item], attributes: [.font: CollectionViewItem.font])
        
        let bRect = attrStr.boundingRect(with: NSSize(width: width - CollectionViewItem.padding.left - CollectionViewItem.padding.right, height: Constants.panel.maxCellHeight - CollectionViewItem.padding.top - CollectionViewItem.padding.bottom), options: .usesLineFragmentOrigin)
        
        let height = bRect.height + CollectionViewItem.padding.top + CollectionViewItem.padding.bottom

        return NSSize(width: width, height: ceil(height))
    }
}

extension HistoryViewController {
    // MARK: Storyboard instantiation
    static func freshController() -> HistoryViewController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier(stringLiteral: "QuotesViewController")
        guard let viewcontroller = storyboard.instantiateController(withIdentifier: identifier) as? HistoryViewController else {
            fatalError("Why cant i find QuotesViewController? - Check Main.storyboard")
        }
        return viewcontroller
    }
}


class LongHotKey {
    
    // MARK: - Types
    
    typealias Handler = () -> Void
    
    
    // MARK: - Properties
    
    let identifier = UUID()
    
    public var handler: Handler?
    public var isPaused = false {
        didSet {
            self.hotKey.isPaused = self.isPaused
            if self.isPaused {
                self.timer = nil
            }
        }
    }
    
    private var hotKey: HotKey
    
    private var timer: Timer?
    
    init(keyCombo: KeyCombo, handler: Handler? = nil) {
        self.handler = handler
        
        self.hotKey = HotKey(keyCombo: keyCombo)
        
        self.hotKey.keyDownHandler = { [weak self] in
            guard let self = self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { (t) in
                print("Aye")
            }
        }
        
        self.hotKey.keyUpHandler = { [weak self] in
            guard let self = self else { return }
            self.timer = nil
        }
        
        
    }
}
