// WatchPriorityPreferencesTests.swift
//
// WP-12b (implementation-plan.md) step 4 / architecture.md D13.5: the
// "Prefer Apple Watch during workouts" preference -- default ON when never
// set, round-trips through `UserDefaults`, and stays in lockstep with the
// SyncKit-side reader (`UserDefaultsWatchPriorityPreference`) the sync
// pipelines' resolver consults, since both sides use the same key by
// construction. Throwaway `UserDefaults(suiteName:)` per test, mirroring
// `SyncPreferencesTests`' own convention -- never touches `.standard`.

import Foundation
import SyncKit
import Testing
@testable import HealthLoom

@Suite("WatchPriorityPreferences")
struct WatchPriorityPreferencesTests {
    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "WatchPriorityPreferencesTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func defaultsToOnWhenNeverSet() async throws {
        let defaults = try makeDefaults()

        #expect(WatchPriorityPreferences(defaults: defaults).isEnabled)
        #expect(UserDefaultsWatchPriorityPreference(defaults: defaults).isWatchPriorityEnabled())
    }

    @Test func turningOffPersistsAndIsSeenByTheSyncKitReader() async throws {
        let defaults = try makeDefaults()
        let preferences = WatchPriorityPreferences(defaults: defaults)

        preferences.setEnabled(false)

        #expect(!preferences.isEnabled)
        // The exact reader the sync pipelines' WatchConflictResolver
        // consults at the start of every run (D13.5's OFF = identity).
        #expect(!UserDefaultsWatchPriorityPreference(defaults: defaults).isWatchPriorityEnabled())
        // A fresh UI-side instance re-reads the stored value.
        #expect(!WatchPriorityPreferences(defaults: defaults).isEnabled)
    }

    @Test func turningBackOnPersists() async throws {
        let defaults = try makeDefaults()
        let preferences = WatchPriorityPreferences(defaults: defaults)

        preferences.setEnabled(false)
        preferences.setEnabled(true)

        #expect(preferences.isEnabled)
        #expect(UserDefaultsWatchPriorityPreference(defaults: defaults).isWatchPriorityEnabled())
    }
}
