//
//  UserDefaults+Blank.swift
//  Yippy
//
//  Created by Matthew Davidson on 26/9/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation

extension UserDefaults {
    
    /**
     Allows execution of the handler with a fresh user defaults. Designed for testing.
     
     Adapted from: [http://www.figure.ink/blog/2016/10/15/testing-userdefaults](http://www.figure.ink/blog/2016/10/15/testing-userdefaults)
     
     - Parameter handler: Code to execute under a clean user defaults.
     */
    func blankWhile(handler: @escaping () -> Void) {
        guard let name = Bundle.main.bundleIdentifier else {
            fatalError("Couldn't find bundle ID.")
        }
        let old = self.persistentDomain(forName: name)
        defer {
            self.setPersistentDomain(old ?? [:], forName: name)
        }
        
        self.removePersistentDomain(forName: name)
        handler()
    }
    
    /**
     Blanks a user defaults until it is restored again.
     
     - Returns: A dictionary of the original content of the user defaults. This should be passed to `restore(:)` to restore the user defaults back to normal.
     */
    func blank() -> [String: Any] {
        guard let name = Bundle.main.bundleIdentifier else {
            fatalError("Couldn't find bundle ID.")
        }
        let old = self.persistentDomain(forName: name)
        self.removePersistentDomain(forName: name)
        return old ?? [:]
    }
    
    /**
     Restores a user defaults from a given dictionary.
     
     - Parameter old: A dictionary of the original content of the user defaults. This should be the dictionary returned from `blank()` to restore the user defaults back to normal.
     */
    func restore(from old: [String: Any]) {
        guard let name = Bundle.main.bundleIdentifier else {
            fatalError("Couldn't find bundle ID.")
        }
        
        self.setPersistentDomain(old, forName: name)
    }
}
