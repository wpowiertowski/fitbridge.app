// WatchPriorityPreference.swift
//
// WP-12b (implementation-plan.md) step 4 / architecture.md D13.5: the
// "Prefer Apple Watch during workouts" user preference, read by
// `WatchConflictResolver.beginRun` once per sync run. Default ON; OFF makes
// the resolver a pass-through identity for that run (Apple Health's own
// source-priority ordering then governs, D13.5) and skips retroactive
// cleanup. Toggling OFF does **not** retroactively restore previously
// suppressed samples (documented in the Settings UI copy); toggling back ON
// cleans up conflicts on the next sync via D13.4's retroactive pass --
// both behaviors fall straight out of "the preference is only ever read at
// the start of a run".
//
// The seam is a protocol (not a raw `UserDefaults` read inside the resolver)
// so tests drive both states without touching real defaults -- the same DI
// posture as `SyncClock`/`WatchCoverageProviding`.

import Foundation

nonisolated public protocol WatchPriorityPreferenceReading: Sendable {
    nonisolated func isWatchPriorityEnabled() -> Bool
}

/// Always-on conformer -- the sensible default for constructions that don't
/// wire a real preference store (and the "toggle ON" leg of tests).
nonisolated public struct AlwaysOnWatchPriorityPreference: WatchPriorityPreferenceReading {
    public init() {}
    public nonisolated func isWatchPriorityEnabled() -> Bool { true }
}

/// Production conformer: reads the shared `UserDefaults` key the app
/// target's Settings toggle writes (`WatchPriorityPreferences`,
/// HealthLoomApp/Settings). **Default ON when the key has never been set**
/// (D13.5: "default ON") -- which is why this reads `object(forKey:)` first
/// rather than `bool(forKey:)`'s false-when-absent behavior.
nonisolated public struct UserDefaultsWatchPriorityPreference: WatchPriorityPreferenceReading {
    /// Public so the app target's Settings toggle writes the exact same key
    /// this reads -- single source of truth for the key string, mirroring
    /// `SyncPreferences`' own single-key posture (HealthLoomApp/Settings/
    /// SyncPreferences.swift).
    public static let defaultsKey = "com.healthloom.settings.preferAppleWatchDuringWorkouts"

    /// `UserDefaults` is documented thread-safe by Apple; `nonisolated(unsafe)`
    /// (rather than fighting the package's MainActor default isolation with
    /// per-call suite lookups) matches the pattern the Xcode 27 beta
    /// conformance-isolation sweep established for lock-protected/thread-safe
    /// storage in this repo.
    nonisolated(unsafe) private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public nonisolated func isWatchPriorityEnabled() -> Bool {
        guard defaults.object(forKey: Self.defaultsKey) != nil else { return true }
        return defaults.bool(forKey: Self.defaultsKey)
    }
}
