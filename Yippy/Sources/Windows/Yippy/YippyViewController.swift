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

struct Results {
    /// The history (clipboard or favourites) the items come from.
    let history: History
    let items: [HistoryItem]
    let isSearchResult: Bool
}

/// The lists shown by the buttons above the history panel, in button order.
enum ItemGroup: Int {
    case clipboard = 0
    case favourites = 1
    
    var history: History {
        switch self {
        case .clipboard: return State.main.history
        case .favourites: return State.main.favourites
        }
    }
}

class YippyViewController: NSViewController {
    
    @IBOutlet var yippyHistoryView: YippyTableView!
    
    @IBOutlet var itemGroupScrollView: HorizontalButtonsView!
    @IBOutlet var itemCountLabel: NSTextField!
    
    @IBOutlet var searchBar: NSTextField!
    
    var yippyHistory = YippyHistory(history: State.main.history, items: [])
    
    let searchEngine = SearchEngine()
    
    let disposeBag = DisposeBag()
    
    var isPreviewShowing = false
    
    var itemGroups = BehaviorRelay<[String]>(value: ["Clipboard", "Favourites"])
    let selectedGroup = BehaviorRelay<ItemGroup>(value: .clipboard)
    
    var isRichText = Settings.main.showsRichText
    
    let results = BehaviorRelay(value: Results(history: State.main.history, items: [], isSearchResult: false))
    let selected = BehaviorRelay<Int?>(value: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        yippyHistoryView.yippyDelegate = self
        
        State.main.history.subscribe(onNext: onHistoryChange)
        State.main.favourites.subscribe(onNext: onFavouritesChange)
        
        State.main.showsRichText.distinctUntilChanged().subscribe(onNext: onShowsRichText).disposed(by: disposeBag)
        
        itemGroupScrollView.delegate = self
        itemGroupScrollView.bind(toData: itemGroups.asObservable()).disposed(by: disposeBag)
        itemGroupScrollView.bind(toSelected: selectedGroup.map({ $0.rawValue })).disposed(by: disposeBag)
        
        Observable.combineLatest(
            results,
            selected.distinctUntilChanged().withPrevious(startWith: nil)
        )
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: onAllChange)
            .disposed(by: disposeBag)
        
        searchBar.delegate = self
        searchBar.placeholderString = "Search (􀆔\\)  ·  /img /link /file @app"
        
        // TODO: Fix hack to make onAllChange run initially
        selected.accept(1)
        resetSelected()
        
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
        YippyHotKeys.shiftReturn.onDown(pasteSelectedAsPlainText)
        YippyHotKeys.ctrlAltCmdLeftArrow.onDown { State.main.panelPosition.accept(.left) }
        YippyHotKeys.ctrlAltCmdRightArrow.onDown { State.main.panelPosition.accept(.right) }
        YippyHotKeys.ctrlAltCmdDownArrow.onDown { State.main.panelPosition.accept(.bottom) }
        YippyHotKeys.ctrlAltCmdUpArrow.onDown { State.main.panelPosition.accept(.top) }
        YippyHotKeys.ctrlDelete.onDown(deleteSelected)
        YippyHotKeys.ctrlSpace.onDown(togglePreview)
        YippyHotKeys.cmdBackslash.onDown(focusSearchBar)
        YippyHotKeys.ctrlF.onDown(toggleFavourite)
        
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
        
        for hotKey in YippyHotKeys.inPanel {
            bindHotKeyToYippyWindow(hotKey, disposeBag: disposeBag)
        }
        
        searchBar.resignFirstResponder()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        isPreviewShowing = false
        resetSelected()
        // "5 min ago" has moved on since the rows were drawn
        yippyHistoryView.refreshRowControls()
    }
    
    func resetSelected() {
        if yippyHistory.items.count > 0 {
            selected.accept(0)
        }
        else {
            selected.accept(nil)
        }
    }
    
    func onHistoryChange(_ history: [HistoryItem], change: History.Change) {
        guard selectedGroup.value == .clipboard else {
            return
        }
        if !searchBar.stringValue.isEmpty {
            runSearch()
        }
        else {
            results.accept(Results(history: State.main.history, items: history, isSearchResult: false))
            switch change {
            case .insert(let i):
                if i == 0 {
                    incrementSelected()
                }
                break;
            default: break;
            }
        }
        if case .update = change {
            yippyHistoryView.refreshRowControls()
        }
    }
    
    func onFavouritesChange(_ favourites: [HistoryItem], change: History.Change) {
        // The button title shows how many there are
        itemGroups.accept(["Clipboard", favourites.isEmpty ? "Favourites" : "Favourites (\(favourites.count))"])
        // Rebuilding the buttons clears their state
        selectedGroup.accept(selectedGroup.value)
        
        if selectedGroup.value == .favourites {
            refreshResults()
        }
        else {
            // The hearts in the clipboard list may have changed
            yippyHistoryView.refreshRowControls()
        }
        if case .update = change {
            yippyHistoryView.refreshRowControls()
        }
    }
    
    /// Shows the selected group's items, filtered by the search if there is one.
    func refreshResults() {
        if !searchBar.stringValue.isEmpty {
            runSearch()
        }
        else {
            let history = selectedGroup.value.history
            results.accept(Results(history: history, items: history.items, isSearchResult: false))
        }
    }
    
    func onAllChange(_ results: Results, _ selected: (Int?, Int?)) {
        if results.items != self.yippyHistory.items || results.history !== self.yippyHistory.history {
                if results.isSearchResult {
                    self.itemCountLabel.stringValue = "\(results.items.count) matches"
                }
                else {
                    self.itemCountLabel.stringValue = "\(results.items.count) items"
                }
                
                // Favourites keep their order when pasted
                self.yippyHistory = YippyHistory(history: results.history, items: results.items, movesPastedItemToTop: results.history === State.main.history)
                self.yippyHistoryView.reloadData(self.yippyHistory.items, isRichText: self.isRichText)
            }
        
        if let previous = selected.0 {
            self.yippyHistoryView.deselectItem(previous)
            self.yippyHistoryView.reloadItem(previous)
        }
        if let selected = selected.1 {
            let currentSelection = self.yippyHistoryView.selected
            if currentSelection == nil || currentSelection != selected {
                self.yippyHistoryView.selectItem(selected)
            }
            self.yippyHistoryView.reloadItem(selected)
            
            if self.isPreviewShowing {
                State.main.previewHistoryItem.accept(self.yippyHistory.items[selected])
            }
        }
    }
    
    func onShowsRichText(_ showsRichText: Bool) {
        isRichText = showsRichText
        yippyHistoryView.reloadData(yippyHistory.items, isRichText: isRichText)
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
        incrementSelected()
    }
    
    func goToPreviousItem() {
        decrementSelected()
    }
    
    func pasteSelected() {
        if let selected = self.yippyHistoryView.selected {
            paste(selected: selected)
        }
    }
    
    /// Pastes the selected item's text without any styling, for when the copied text carries formatting that shouldn't come along.
    func pasteSelectedAsPlainText() {
        if let selected = self.yippyHistoryView.selected {
            paste(selected: selected, plainText: true)
        }
    }
    
    func deleteSelected() {
        if let selected = self.yippyHistoryView.selected {
            self.selected.accept(yippyHistory.delete(selected: selected))
        }
    }
    
    func close() {
        isPreviewShowing = false
        State.main.isHistoryPanelShown.accept(false)
        State.main.previewHistoryItem.accept(nil)
        resetSelected()
    }
    
    func shortcutPressed(key: Int) {
        // ⌘0-9 are registered whether or not there are that many items.
        guard yippyHistory.items.indices.contains(key) else {
            return
        }
        paste(selected: key)
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
    
    /// Adds the selected clipboard item to the favourites, or removes it if it's already there. In the favourites, removes the selected item.
    func toggleFavourite() {
        guard let row = yippyHistoryView.selected, yippyHistory.items.indices.contains(row) else {
            return
        }
        toggleFavourite(of: yippyHistory.items[row])
    }
    
    /// Like `toggleFavourite()`, for any item shown rather than the selected one.
    func toggleFavourite(of item: HistoryItem) {
        if yippyHistory.history === State.main.favourites {
            guard let row = yippyHistory.items.firstIndex(where: { $0.fsId == item.fsId }) else {
                return
            }
            self.selected.accept(yippyHistory.delete(selected: row))
        }
        else {
            State.main.favourites.toggleFavourite(item)
        }
    }
    
    /// Whether the item is one of the favourites.
    func isFavourite(_ item: HistoryItem) -> Bool {
        // Everything in the favourites list is one
        if yippyHistory.history === State.main.favourites {
            return true
        }
        return State.main.favourites.containsItem(withSameContentAs: item)
    }
    
    // MARK: - Editing favourites
    
    /// Asks for a new name for the favourite, shown in its info bar and found by search. An empty name removes it.
    func rename(_ item: HistoryItem) {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = item.metadata.title ?? ""
        field.placeholderString = "Name"
        
        guard let title = runEditAlert(message: "Rename Favourite", informativeText: "The name is shown under the item and found by search.", accessoryView: field, firstResponder: field) else {
            return
        }
        State.main.favourites.renameFavourite(withId: item.fsId, to: title)
    }
    
    /// Lets the favourite's text be edited. The edited favourite is plain text, without any styling it had.
    func edit(_ item: HistoryItem) {
        guard let text = item.getUnstyledText() else {
            return
        }
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 380, height: 200))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        let textView = NSTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize))
        textView.autoresizingMask = [.width]
        textView.isRichText = false
        textView.font = Constants.fonts.yippyPlainText
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.string = text
        scrollView.documentView = textView
        
        guard let newText = runEditAlert(message: "Edit Favourite", informativeText: "Saving keeps the text only, without any styling.", accessoryView: scrollView, firstResponder: textView, result: { textView.string }) else {
            return
        }
        guard newText != text, !newText.isEmpty else {
            return
        }
        State.main.favourites.editFavourite(withId: item.fsId, text: newText)
    }
    
    /// Closes the panel and shows an alert with Save and Cancel buttons around `accessoryView`.
    ///
    /// The panel has to close first: while it's open, Return, Escape and the arrow keys are taken by its hot keys.
    ///
    /// - Returns: The text from `result` (by default the text field's), or nil if cancelled.
    private func runEditAlert(message: String, informativeText: String, accessoryView: NSView, firstResponder: NSView, result: (() -> String)? = nil) -> String? {
        close()
        NSApp.activate(ignoringOtherApps: true)
        
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText
        alert.accessoryView = accessoryView
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = firstResponder
        let response = alert.runModal()
        // Give the app that was in front before the panel opened its focus back
        NSApp.hide(nil)
        
        guard response == .alertFirstButtonReturn else {
            return nil
        }
        if let result = result {
            return result()
        }
        return (accessoryView as? NSTextField)?.stringValue ?? ""
    }
    
    func selectGroup(_ group: ItemGroup) {
        guard group != selectedGroup.value else {
            return
        }
        selectedGroup.accept(group)
        refreshResults()
        resetSelected()
    }
    
    func focusSearchBar() {
        NSApp.activate(ignoringOtherApps: true)
        self.searchBar.becomeFirstResponder()
    }
    
    func runSearch() {
        let query = searchBar.stringValue
        let history = selectedGroup.value.history
        if query.isEmpty {
            searchEngine.cancel()
            results.accept(Results(history: history, items: history.items, isSearchResult: false))
            return
        }
        
        searchEngine.search(query: query, in: history.items, completion: { matches in
            self.results.accept(Results(history: history, items: matches, isSearchResult: true))
        })
    }
    
    private func incrementSelected() {
        guard let s = selected.value else {
            if yippyHistory.items.count > 0 {
                selected.accept(0)
            }
            return
        }
        if s < yippyHistory.items.count - 1 {
            selected.accept(s + 1)
        }
    }
    
    private func decrementSelected() {
        guard let s = selected.value else {
            if yippyHistory.items.count > 0 {
                selected.accept(0)
            }
            return
        }
        if s > 0 {
            selected.accept(s - 1)
        }
    }
    
    private func paste(selected: Int, plainText: Bool = false) {
        self.close()
        yippyHistory.paste(selected: selected, plainText: plainText)
    }
}

extension YippyViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        runSearch()
    }
}

extension YippyViewController: YippyTableViewDelegate {
    func yippyTableView(_ yippyTableView: YippyTableView, selectedDidChange selected: Int?) {
        self.selected.accept(selected)
    }
    
    func yippyTableView(_ yippyTableView: YippyTableView, didMoveItem from: Int, to: Int) {
        yippyHistory.move(from: from, to: to)
        selected.accept(to)
    }
    
    func yippyTableView(_ yippyTableView: YippyTableView, isFavourite item: HistoryItem) -> Bool {
        return isFavourite(item)
    }
    
    func yippyTableView(_ yippyTableView: YippyTableView, didToggleFavouriteOf item: HistoryItem) {
        toggleFavourite(of: item)
    }
    
    func yippyTableView(_ yippyTableView: YippyTableView, didRequestPasteOf item: HistoryItem, plainText: Bool) {
        // The item may not be the selected one, and may be gone by the time the menu item is chosen
        guard let row = yippyHistory.items.firstIndex(where: { $0.fsId == item.fsId }) else {
            return
        }
        paste(selected: row, plainText: plainText)
    }
    
    func yippyTableView(_ yippyTableView: YippyTableView, didRequestPasteOf item: HistoryItem, text: String) {
        guard let row = yippyHistory.items.firstIndex(where: { $0.fsId == item.fsId }) else {
            return
        }
        close()
        yippyHistory.paste(selected: row, text: text)
    }
    
    func yippyTableView(_ yippyTableView: YippyTableView, canEdit item: HistoryItem) -> Bool {
        return yippyHistory.history === State.main.favourites
    }
    
    func yippyTableView(_ yippyTableView: YippyTableView, didRequestRenameOf item: HistoryItem) {
        rename(item)
    }
    
    func yippyTableView(_ yippyTableView: YippyTableView, didRequestEditOf item: HistoryItem) {
        edit(item)
    }
    
    func yippyTableView(_ yippyTableView: YippyTableView, didRequestItemsFromApp bundleId: String) {
        searchBar.stringValue = SearchQuery.appFilter(forAppName: AppInfo.name(forBundleId: bundleId))
        runSearch()
    }
}

extension YippyViewController: HorizontalButtonsViewDelegate {
    func horizontalButtonsView(_ horizontalButtonsView: HorizontalButtonsView, didClickButtonAt i: Int) {
        if let group = ItemGroup(rawValue: i) {
            selectGroup(group)
        }
    }
}
