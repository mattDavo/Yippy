//
//  YippyTableViewDelegate.swift
//  Yippy
//
//  Created by Matthew Davidson on 27/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation

protocol YippyTableViewDelegate {
    
    func yippyTableView(_ yippyTableView: YippyTableView, selectedDidChange selected: Int?)
}
