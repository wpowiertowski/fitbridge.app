// TodayHeaderModel.swift
//
// WP-33 (implementation-plan.md) step 1 + 4: the header's sync-status line
// ("Fitbit Air · synced 9m ago" -- bound to real `SyncState`, architecture
// .md D12's mockup line) including the mandated stale-data state (">24 h")
// and the pre-first-sync empty state, plus the greeting line. Pure value
// logic, unit-tested in `TodayHeaderModelTests` -- the view feeds it
// `@Query` results and a clock value.

import Foundation

/// The header's sync-status line.
struct TodaySyncStatus: Equatable {
    enum Freshness: Equatable {
        /// Synced within the last 24 h -- live rust dot.
        case fresh
        /// Synced, but more than 24 h ago (WP-33 step 4's "stale data
        /// (>24 h)" state) -- gray dot, explicit wording.
        case stale
        /// No successful sync yet (pre-first-sync empty state).
        case never
    }

    var freshness: Freshness
    var text: String

    static let staleThreshold: TimeInterval = 24 * 3600

    /// `lastSyncedAt` = the newest `SyncState.lastSyncedAt` across all
    /// types; `deviceLabel` = a human source name when one is known (the
    /// newest `LocalSample.source`), else the line renders without one.
    static func make(lastSyncedAt: Date?, deviceLabel: String?, now: Date) -> TodaySyncStatus {
        guard let lastSyncedAt else {
            return TodaySyncStatus(freshness: .never, text: "Not synced yet")
        }
        let age = now.timeIntervalSince(lastSyncedAt)
        let relative = relativeAge(age)
        let prefix = deviceLabel.map { "\($0) \u{00B7} " } ?? ""
        if age > staleThreshold {
            return TodaySyncStatus(freshness: .stale, text: "\(prefix)last synced \(relative) ago")
        }
        return TodaySyncStatus(freshness: .fresh, text: "\(prefix)synced \(relative) ago")
    }

    /// Coarse, calm relative age -- "just now" / "9m" / "3h" / "2d". A
    /// bespoke formatter (not `RelativeDateTimeFormatter`) so the string
    /// stays as terse as the mockup's "synced 9m ago".
    static func relativeAge(_ age: TimeInterval) -> String {
        let clamped = max(age, 0)
        if clamped < 60 { return "moments" }
        let minutes = Int(clamped / 60)
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}

enum TodayGreeting {
    /// "Good morning" / "Good afternoon" / "Good evening" by local hour.
    /// No user name -- none is collected anywhere in the app (the mockup's
    /// "Sam" is sample copy, not a data contract).
    static func text(hour: Int) -> String {
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }
}
