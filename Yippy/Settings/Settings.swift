//
//  Settings.swift
//  Yippy
//
//  Created by Matthew Davidson on 6/8/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Default
import RxSwift
import RxRelay

struct Settings: Codable, DefaultStorable {
    
    // MARK: - Singleton
    
    private init(panelPosition: PanelPosition, pasteboardChangeCount: Int, history: [HistoryItem]) {
        self.panelPosition = panelPosition
        self.pasteboardChangeCount = pasteboardChangeCount
        self.history = history
    }
    
    static var main: Settings! {
        get {
            let settings = Settings.read(forKey: "settings")
            if settings != nil {
                return settings
            }
            return Settings.default
        }
        set (main) {
            main.write(withKey: "settings")
        }
    }
    
    // MARK: - Default
    
    static let `default` = Settings(
        panelPosition: .right,
        pasteboardChangeCount: -1,
        history: []
    )
    
    // MARK: - Settings
    
    var panelPosition: PanelPosition
    
    var pasteboardChangeCount: Int
    
    var history: [HistoryItem]
    
    
    // MARK: - State Binding Methods
    
    func bindPanelPositionTo(state: BehaviorRelay<PanelPosition>) -> Disposable {
        return state.bind { (x) in
            Settings.main.panelPosition = x
        }
    }
    
    func bindPasteboardChangeCountTo(state: BehaviorRelay<Int>) -> Disposable {
        return state.bind { (x) in
            Settings.main.pasteboardChangeCount = x
        }
    }
    
    func bindHistoryTo(state: BehaviorRelay<[HistoryItem]>) -> Disposable {
        return state.bind { (x) in
            Settings.main.history = x
        }
    }
}

extension Settings {
    
    struct testData {
        static var a: Settings {
            var settings = Settings.default
            settings.panelPosition = .left
            settings.history = UITesting.testHistory.a
            return settings
        }
        
        static func from(_ str: String) -> Settings? {
            switch str {
            case "--Settings.testData=a":
                return a
            default:
                return nil
            }
        }
    }
}

extension Settings: Equatable {
    
}
