//
//  State.swift
//  Yippy
//
//  Created by Matthew Davidson on 7/8/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import RxRelay
import RxSwift
import LoginServiceKit

class State {
    
    // MARK: - Singleton
    static var main = State()
    
    
    // MARK: - Attributes
    // RxSwift
    var isHistoryPanelShown: BehaviorRelay<Bool>
    
    var panelPosition: BehaviorRelay<PanelPosition>
    
    var previewHistoryItem: BehaviorRelay<HistoryItem?>
    
    var launchAtLogin: BehaviorRelay<Bool>
    
    var disposeBag: DisposeBag
    
    // History
    var historyCache: HistoryCache!
    var history: History!
    
    /// Monitors the pasteboard, here it can be controlled in the future if needed.
    var pasteboardMonitor: PasteboardMonitor!
    
    
    // MARK: - Constructor
    init(settings: Settings = Settings.main, disposeBag: DisposeBag = DisposeBag()) {
        // Setup RxSwift attributes
        self.isHistoryPanelShown = BehaviorRelay<Bool>(value: false)
        self.panelPosition = BehaviorRelay<PanelPosition>(value: settings.panelPosition)
        self.previewHistoryItem = BehaviorRelay<HistoryItem?>(value: nil)
        self.launchAtLogin = BehaviorRelay<Bool>(value: LoginServiceKit.isExistLoginItems())
        self.disposeBag = disposeBag
        
        // Setup history
        self.historyCache = HistoryCache()
        self.history = History.load(cache: historyCache)
        self.history.recordPasteboardChange(withCount: settings.pasteboardChangeCount)
        
        // Bind settings to state
        Self.bind(settings: settings, toState: self, disposeBag: disposeBag)
        
        // Setup pasteboard monitor
        self.pasteboardMonitor = PasteboardMonitor(pasteboard: NSPasteboard.general, changeCount: settings.pasteboardChangeCount, delegate: self.history)
    }
    
    // MARK: - Constructor Helpers
    
    static func bind(settings: Settings, toState state: State, disposeBag: DisposeBag) {
        settings.bindPasteboardChangeCountTo(state: state.history!.observableLastRecordedChangeCount).disposed(by: disposeBag)
        settings.bindPanelPositionTo(state: state.panelPosition).disposed(by: disposeBag)
    }
}
