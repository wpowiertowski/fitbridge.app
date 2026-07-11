// KeychainBackend.swift
//
// WP-03 (implementation-plan.md), testing note: macOS's file-based Keychain
// and iOS's data-protection Keychain behave differently, and unsigned/ad-hoc
// `swift test` runs can hit `errSecMissingEntitlement` (-34018) against the
// real Keychain. `KeychainBackend` is the minimal seam that isolates every
// `SecItem*` call so `KeychainStoreTests` can run the required round-trip /
// prefix-delete tests against an in-memory fake, while `KeychainStore` itself
// (the public API) still talks to the real Keychain by default in the app.
//
// Intentionally internal: it is a test seam, not public API surface.

/// Storage primitive `KeychainStore` is built on: get/set/delete/enumerate by
/// a plain string account name. `KeychainStore` maps `SecretKey` to account
/// strings; this protocol never sees anything richer than that.
protocol KeychainBackend: Sendable {
    /// Returns the UTF-8 string stored for `account`, or `nil` if absent.
    nonisolated func read(account: String) throws(SecretsError) -> String?

    /// All account names currently present (used for prefix-matched delete).
    nonisolated func allAccounts() throws(SecretsError) -> [String]

    /// Upserts `value` for `account` (adds if absent, updates in place if present).
    nonisolated func write(account: String, value: String) throws(SecretsError)

    /// Removes `account` if present. Not an error if it was already absent
    /// (delete is idempotent, matching `KeychainStore.delete`'s contract).
    nonisolated func erase(account: String) throws(SecretsError)
}
