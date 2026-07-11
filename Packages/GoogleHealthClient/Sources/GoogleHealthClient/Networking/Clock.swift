// Clock.swift
//
// WP-04 step 3 (implementation-plan.md): `validAccessToken()`'s expiry-margin
// check ("cached token if >60s from expiry") must be testable without
// depending on wall-clock time. `TokenClock` is the seam: production uses
// `SystemTokenClock`; tests inject a manually-advanced fake so the expiry
// margin can be tested at an exact boundary.

import Foundation

/// Supplies "now" to `GoogleAuthManager`. Synchronous and non-throwing so it
/// can be called from actor-isolated code without a suspension point.
public protocol TokenClock: Sendable {
    nonisolated func now() -> Date
}

/// Production clock: wall-clock time.
nonisolated public struct SystemTokenClock: TokenClock {
    public init() {}
    public func now() -> Date { Date() }
}
