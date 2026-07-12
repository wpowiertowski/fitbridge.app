// KeychainStore.swift
//
// WP-03 (implementation-plan.md) / architecture.md §2, D11.
//
// The one place HealthLoom touches the Keychain. Callers only ever see
// `SecretKey` (never a raw string) and `SecretsError` (never a raw
// `OSStatus` sprinkled through call sites). Values themselves are never
// logged anywhere in this package.

/// Actor-isolated Keychain wrapper. All access is serialized through this
/// actor, matching the concurrency posture of `GoogleAuthManager` /
/// `SyncEngine` elsewhere in the app (architecture.md §3).
public actor KeychainStore {
    private let backend: any KeychainBackend

    /// Production initializer: backed by the real Keychain via the Security
    /// framework, namespaced under one generic-password service.
    public init() {
        self.backend = KeychainSecurityBackend()
    }

    /// Test/internal seam: inject an arbitrary `KeychainBackend` (e.g. an
    /// in-memory fake, or a real backend pointed at a throwaway service
    /// name). Not public API — only reachable from within this module or via
    /// `@testable import Secrets`.
    init(backend: any KeychainBackend) {
        self.backend = backend
    }

    /// Returns the stored value for `key`, or `nil` if nothing is stored.
    public func get(_ key: SecretKey) throws(SecretsError) -> String? {
        try backend.read(account: key.rawValue)
    }

    /// Stores `value` for `key`, overwriting any existing value.
    public func set(_ value: String, for key: SecretKey) throws(SecretsError) {
        try backend.write(account: key.rawValue, value: value)
    }

    /// Removes `key`. Safe to call when nothing is stored for it.
    public func delete(_ key: SecretKey) throws(SecretsError) {
        try backend.erase(account: key.rawValue)
    }

    /// Removes every stored key whose raw string value starts with `prefix`.
    ///
    /// `SecretKey`'s raw values are dot-namespaced (`"google.*"`,
    /// `"provider.*"`), so `deleteAll(matching: "provider.")` removes exactly
    /// the three cloud-provider API keys and leaves the two Google OAuth
    /// tokens untouched (and vice versa for `"google."`).
    public func deleteAll(matching prefix: String) throws(SecretsError) {
        for account in try backend.allAccounts() where account.hasPrefix(prefix) {
            try backend.erase(account: account)
        }
    }
}
