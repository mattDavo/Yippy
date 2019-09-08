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
    
    var panelPosition: PanelPosition = .right
    
    static var main: Settings! {
        get {
            return Settings.read(forKey: "settings")
        }
        set (main) {
            main.write(withKey: "settings")
        }
    }
}


struct new {
    
    var panelPosition = BehaviorRelay<PanelPosition>(value: .right)
}

