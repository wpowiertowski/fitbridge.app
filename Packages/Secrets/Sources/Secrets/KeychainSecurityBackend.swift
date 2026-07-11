// KeychainSecurityBackend.swift
//
// WP-03 (implementation-plan.md) / architecture.md D11: the real Keychain
// implementation of `KeychainBackend`, backing `KeychainStore` in production.
//
// Every item is written with:
//   - kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly (D11: tokens/keys
//     readable only after first unlock post-boot, and never migrate to a
//     new device via backup/restore).
//   - kSecAttrSynchronizable = false (no iCloud Keychain sync, explicit).
//   - kSecUseDataProtectionKeychain = true, so behavior is consistent between
//     iOS (where this is the only Keychain) and macOS (where `swift test`
//     runs on this repo's Mac — see WP-03 testing note / progress.md). On iOS
//     this flag is a no-op (already the only Keychain available); on macOS it
//     opts into the same data-protection-keychain semantics instead of the
//     legacy file-based Keychain, avoiding cross-platform surprises around
//     the `kSecAttrAccessible` value.
//
// All items live under one generic-password service so a single
// `SecItemCopyMatching` with `kSecMatchLimitAll` enumerates every FitBridge
// secret for `allAccounts()` (used by `KeychainStore.deleteAll(matching:)`).

import Foundation
import Security

nonisolated struct KeychainSecurityBackend: KeychainBackend {
    /// Kept internal + parameterized (rather than a hardcoded constant) so
    /// the integration-style test in `KeychainStoreTests` can point at a
    /// throwaway service name instead of whatever service the real app uses,
    /// so a test run can never read, overwrite, or delete a real secret.
    let service: String

    init(service: String = "com.fitbridge.secrets") {
        self.service = service
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    func read(account: String) throws(SecretsError) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
                throw SecretsError.undecodableValue
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw SecretsError.keychain(status: status)
        }
    }

    func allAccounts() throws(SecretsError) -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecUseDataProtectionKeychain as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        var items: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &items)

        switch status {
        case errSecSuccess:
            guard let attributeDicts = items as? [[String: Any]] else { return [] }
            return attributeDicts.compactMap { $0[kSecAttrAccount as String] as? String }
        case errSecItemNotFound:
            return []
        default:
            throw SecretsError.keychain(status: status)
        }
    }

    func write(account: String, value: String) throws(SecretsError) {
        let data = Data(value.utf8)

        var addQuery = baseQuery(account: account)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        addQuery[kSecAttrSynchronizable as String] = false

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return
        }
        guard addStatus == errSecDuplicateItem else {
            throw SecretsError.keychain(status: addStatus)
        }

        // Item already exists: update in place rather than delete+re-add, so
        // we don't churn the Keychain item's creation date / metadata.
        let matchQuery = baseQuery(account: account)
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(matchQuery as CFDictionary, attributesToUpdate as CFDictionary)
        guard updateStatus == errSecSuccess else {
            throw SecretsError.keychain(status: updateStatus)
        }
    }

    func erase(account: String) throws(SecretsError) {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecretsError.keychain(status: status)
        }
    }
}
