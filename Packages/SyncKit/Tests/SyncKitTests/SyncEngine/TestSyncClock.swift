// TestSyncClock.swift
//
// WP-09 (implementation-plan.md): a manually-advanced fake `SyncClock`
// (SyncEngineTypes.swift), mirroring `GoogleHealthClient`'s own virtual-clock
// test pattern for `TokenClock` (Networking/Clock.swift) -- window-boundary
// math (architecture.md D3) must be testable against an exact clock, never
// real wall-clock time.

import Foundation
@testable import SyncKit

final class TestSyncClock: SyncClock, @unchecked Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var current: Date

    init(_ date: Date) {
        self.current = date
    }

    nonisolated func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func set(_ date: Date) {
        lock.lock()
        current = date
        lock.unlock()
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        current = current.addingTimeInterval(interval)
        lock.unlock()
    }
}
