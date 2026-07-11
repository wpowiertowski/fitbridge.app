// GoogleTokenStoring.swift
//
// WP-04 (implementation-plan.md) / task brief: "Tokens go through the
// existing Secrets.KeychainStore... For tests, if KeychainStore can't run in
// the unsigned test process, define a small token-storage protocol in
// GoogleHealthClient that KeychainStore satisfies via a thin adapter, and
// test against a fake."
//
// `Packages/Secrets`' own WP-03 testing note confirms the real Keychain
// throws `errSecMissingEntitlement` (-34018) under an unsigned `swift test`
// process on this Mac. `GoogleAuthManager`'s required tests (refresh
// single-flight, expiry margin, invalid_grant, Workspace detection, token
// exchange encoding) are exercised against `GoogleTokenStoring`, using a
// fully in-memory fake in the test target -- never the real Keychain.

/// Storage seam for the two Google OAuth tokens `GoogleAuthManager` persists.
/// Deliberately narrower than `Secrets.SecretKey` (which also carries
/// AI-provider keys this package has no business touching).
public protocol GoogleTokenStoring: Sendable {
    nonisolated func refreshToken() async throws -> String?
    /// `nil` deletes the stored value (mirrors `KeychainStore.delete`'s
    /// idempotent-when-absent contract).
    nonisolated func setRefreshToken(_ value: String?) async throws

    nonisolated func accessToken() async throws -> String?
    nonisolated func setAccessToken(_ value: String?) async throws
}
