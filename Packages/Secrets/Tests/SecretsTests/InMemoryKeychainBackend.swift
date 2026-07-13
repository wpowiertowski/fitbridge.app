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
    private nonisolated(unsafe) var storage: [String: String] = [:]

    nonisolated func read(account: String) throws(SecretsError) -> String? {
        lock.withLock { storage[account] }
    }

    nonisolated func allAccounts() throws(SecretsError) -> [String] {
        lock.withLock { Array(storage.keys) }
    }

    nonisolated func write(account: String, value: String) throws(SecretsError) {
        lock.withLock { storage[account] = value }
    }

    nonisolated func erase(account: String) throws(SecretsError) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: account)
    }
}
