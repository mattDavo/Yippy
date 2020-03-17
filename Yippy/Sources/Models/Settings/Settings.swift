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
import HotKey

struct Settings: Codable, DefaultStorable {
    
    // MARK: - Singleton
    
    private init(panelPosition: PanelPosition, pasteboardChangeCount: Int, toggleHotKey: KeyCombo) {
        self.panelPosition = panelPosition
        self.pasteboardChangeCount = pasteboardChangeCount
        self.toggleHotKey = toggleHotKey
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
        toggleHotKey: KeyCombo(key: .v, modifiers: [.command, .shift])
    )
    
    // MARK: - Settings
    
    var panelPosition: PanelPosition
    
    var pasteboardChangeCount: Int
    
    var toggleHotKey: KeyCombo
    
    
    // MARK: - State Binding Methods
    
    func bindPanelPositionTo(state: BehaviorRelay<PanelPosition>) -> Disposable {
        return state.bind { (x) in
            Settings.main.panelPosition = x
        }
    }
    
    func bindPasteboardChangeCountTo(state: Observable<Int>) -> Disposable {
        return state.bind { (x) in
            Settings.main.pasteboardChangeCount = x
        }
    }
}

extension Settings {
    
    struct testData {
        static var a: Settings {
            var settings = Settings.default
            settings.panelPosition = .left
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
