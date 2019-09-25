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
    
    private init() {}
    
    static var main: Settings! {
        get {
            let settings = Settings.read(forKey: "settings")
            if settings != nil {
                return settings
            }
            return Settings()
        }
        set (main) {
            main.write(withKey: "settings")
        }
    }
    
    
    // MARK: - Settings
    
    var panelPosition: PanelPosition = .right
    
    var pasteboardChangeCount: Int = -1
    
    var history = [String]()
    
    
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
    
    func bindHistoryTo(state: BehaviorRelay<[String]>) -> Disposable {
        return state.bind { (x) in
            Settings.main.history = x
        }
    }
}
