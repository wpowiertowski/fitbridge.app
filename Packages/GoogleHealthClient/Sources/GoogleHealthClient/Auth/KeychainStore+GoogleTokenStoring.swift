// KeychainStore+GoogleTokenStoring.swift
//
// WP-04: the "thin adapter" the task brief asks for, making the existing
// `Secrets.KeychainStore` (WP-03) satisfy `GoogleTokenStoring`. Implemented
// as a protocol conformance rather than a wrapper type -- there is no state
// or behavior to add, just a mapping from this package's two token slots to
// `Secrets.SecretKey`'s two Google cases. This conformance is declared here
// (the module that owns the protocol) importing `Secrets` (the module that
// owns the type), which needs no `@retroactive` annotation since this is the
// protocol-owning module, not an unrelated third module.
//
// Not covered by a dedicated real-Keychain integration test in this package:
// `Packages/Secrets`' own WP-03 suite already proves `KeychainStore`'s
// get/set/delete round-trip against the real Keychain (where usable) and
// against an in-memory fake; re-deriving that here would mean touching the
// *production* Keychain service from this package's test process (KeychainStore's
// throwaway-service test initializer is intentionally `internal` to Secrets,
// not exported), which risks clobbering a real stored token on a developer
// machine for no additional coverage. `GoogleAuthManagerTests` verifies
// KeychainStore conforms to `GoogleTokenStoring` at compile time (no I/O);
// `GoogleAuthManager`'s actual token-handling behavior is fully covered
// against `FakeTokenStore`.

import Secrets

extension KeychainStore: GoogleTokenStoring {
    // No `await` on the calls below: these extension methods are members of
    // the `KeychainStore` actor itself (an extension of an actor type is
    // still that actor's isolation domain, regardless of which module
    // declares it), so calling `get`/`set`/`delete` -- also `KeychainStore`-
    // isolated -- never crosses an isolation boundary. Declared `async` only
    // to satisfy `GoogleTokenStoring`'s protocol requirement shape.
    public func refreshToken() async throws -> String? {
        try get(.googleRefreshToken)
    }

    public func setRefreshToken(_ value: String?) async throws {
        if let value {
            try set(value, for: .googleRefreshToken)
        } else {
            try delete(.googleRefreshToken)
        }
    }

    public func accessToken() async throws -> String? {
        try get(.googleAccessToken)
    }

    public func setAccessToken(_ value: String?) async throws {
        if let value {
            try set(value, for: .googleAccessToken)
        } else {
            try delete(.googleAccessToken)
        }
    }
}
