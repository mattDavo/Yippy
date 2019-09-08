//
//  State.swift
//  Yippy
//
//  Created by Matthew Davidson on 7/8/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import RxRelay

struct State {
    
    var isHistoryPanelShown = BehaviorRelay<Bool>(value: false)
    
    var isPasteboardPaused = BehaviorRelay<Bool>(value: false)
    
    var panelPosition = BehaviorRelay<PanelPosition>(value: .right)
    
    var history = [String]()
    
    static var main = State()
}
