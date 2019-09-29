//
//  AccessControlHelping.swift
//  Yippy
//
//  Created by Matthew Davidson on 28/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation

protocol AccessControlHelping {
    
    func isControlGranted() -> Bool
    func isControlGranted(showPopup: Bool) -> Bool
}
