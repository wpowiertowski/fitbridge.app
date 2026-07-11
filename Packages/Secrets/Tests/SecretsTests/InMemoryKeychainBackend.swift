// InMemoryKeychainBackend.swift
//
// WP-03 (implementation-plan.md) testing note: macOS's file-based Keychain
// and iOS's data-protection Keychain diverge, and unsigned `swift test`
// binaries can hit `errSecMissingEntitlement` (-34018) against the real
// Keychain. The required round-trip / missing-key / prefix-delete tests
// (KeychainStoreTests) run against this in-memory fake instead, so they are
// deterministic and environment-independent; `KeychainSecurityBackendTests`
// separately exercises the real Keychain and skips itself gracefully where
// the real thing is unavailable.

import Foundation
@testable import Secrets

/// A trivial, lock-protected in-memory stand-in for `KeychainBackend`.
/// Reachable only because `SecretsTests` uses `@testable import Secrets`.
final class InMemoryKeychainBackend: KeychainBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: String] = [:]

    func read(account: String) throws(SecretsError) -> String? {
        lock.withLock { storage[account] }
    }

    func allAccounts() throws(SecretsError) -> [String] {
        lock.withLock { Array(storage.keys) }
    }

    func write(account: String, value: String) throws(SecretsError) {
        lock.withLock { storage[account] = value }
    }

    func erase(account: String) throws(SecretsError) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: account)
    }
}
