// ManualClock.swift
//
// Settable `TokenClock` fake so the expiry-margin test can position "now"
// at an exact boundary relative to a cached token's expiry, without any
// real waiting. `TokenClock.now()` is synchronous/non-throwing (so
// `GoogleAuthManager` can call it without a suspension point), so this fake
// uses a lock rather than an actor.

import Foundation
import GoogleHealthClient

final class ManualClock: TokenClock, @unchecked Sendable {
    private let lock = NSLock()
    private var currentDate: Date

    init(_ date: Date = Date(timeIntervalSince1970: 1_750_000_000)) {
        self.currentDate = date
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return currentDate
    }

    func advance(by seconds: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        currentDate = currentDate.addingTimeInterval(seconds)
    }

    func set(_ date: Date) {
        lock.lock()
        defer { lock.unlock() }
        currentDate = date
    }
}
