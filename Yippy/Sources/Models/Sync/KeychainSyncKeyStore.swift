//
//  KeychainSyncKeyStore.swift
//  Yippy
//
//  Keeps the sync key in the login keychain, so it isn't readable from the app's files.
//

import Foundation
import Security

@available(macOS 10.15, *)
final class KeychainSyncKeyStore: SyncKeyStore {
    
    private let service: String
    private let log: (String) -> Void
    private static let account = "sync-key"
    
    /// - Parameter service: The keychain item's service, unique to this app (its bundle id by default).
    init(service: String = (Bundle.main.bundleIdentifier ?? "clipboard") + ".sync", log: @escaping (String) -> Void) {
        self.service = service
        self.log = log
    }
    
    func load() -> SyncKey? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return SyncKey(bytes: data)
    }
    
    func save(_ key: SyncKey?) {
        SecItemDelete(baseQuery as CFDictionary)
        guard let key = key else {
            return
        }
        var item = baseQuery
        item[kSecValueData as String] = key.bytes
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        if status != errSecSuccess {
            log("Couldn't save the sync key to the keychain (\(status)).")
        }
    }
    
    private var baseQuery: [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.account,
        ]
    }
}
