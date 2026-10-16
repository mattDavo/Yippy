//
//  LegacyMigration.swift
//  Yippy
//
//  Cairn used Yippy's bundle ids before it was renamed. On the first launch under a new bundle id, this copies the
//  history, favourites and settings the same build kept under its old one, so nothing is lost in the rename.
//

import Foundation

enum LegacyMigration {

    /// Each build's bundle id, mapped to the one it had before the rename.
    static let legacyBundleIds = [
        "com.hamzashewa.Cairn": "MatthewDavidson.Yippy",
        "com.hamzashewa.CairnBeta": "MatthewDavidson.YippyBeta"
    ]

    /// Copies the old app-support folder and settings, unless this build already has its own.
    /// - Returns: Whether anything was copied.
    @discardableResult
    static func run(bundleId: String? = Bundle.main.bundleIdentifier,
                    fileManager: FileManager = .default,
                    defaults: UserDefaults = .standard) -> Bool {
        guard let bundleId = bundleId,
              let legacyId = legacyBundleIds[bundleId],
              let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return false
        }
        let current = support.appendingPathComponent(bundleId, isDirectory: true)
        let legacy = support.appendingPathComponent(legacyId, isDirectory: true)
        guard !fileManager.fileExists(atPath: current.path), fileManager.fileExists(atPath: legacy.path) else {
            return false
        }
        do {
            try fileManager.copyItem(at: legacy, to: current)
        }
        catch {
            return false
        }
        if let settings = defaults.persistentDomain(forName: legacyId),
           defaults.persistentDomain(forName: bundleId)?.isEmpty ?? true {
            defaults.setPersistentDomain(settings, forName: bundleId)
        }
        return true
    }
}
