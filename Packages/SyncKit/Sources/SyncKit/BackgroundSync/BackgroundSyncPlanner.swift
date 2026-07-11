// BackgroundSyncPlanner.swift
//
// WP-16 (implementation-plan.md): the pure, HealthKit-and-BGTaskScheduler-free
// "due types + budget" planner the app target's `BGAppRefreshTask` handler
// consults before calling `SyncEngine.syncAll(types:)`. Follows the same
// pure/impure split every earlier SyncKit WP established (`MappedDecision`/
// `MappedObject`; `HealthKitIdentifierClassifier`/`HealthKitObjectTypeResolver`;
// `SyncEngineTypes.swift`/`SyncEngine.swift`) -- this file imports neither
// HealthKit nor BackgroundTasks (the app target is the only place that
// imports `BackgroundTasks` at all) so it compiles and runs under plain
// `swift test` on any platform, and is unit-testable with a fully virtual
// clock per WP-16's own "Tests" line ("unit-test the due types + budget
// planner as a pure function ... decoupled from actual BGTaskScheduler
// APIs").
//
// Concurrency: every declaration here is `nonisolated`, matching
// `SyncEngineTypes.swift`'s house style (`SyncConfiguration.lookback(for:)`,
// `SyncClock`, `ConflictFiltering`) -- these are plain value computations
// with no actor affinity of their own, so `nonisolated` lets any caller
// (SyncKit's own `SyncKitTests` target, another package, or a plain
// non-actor-isolated `Task` in the app target's BGTask launch handler) call
// them without an actor hop, and specifically without forcing a hop onto
// `SyncEngine`'s own actor or the app's `MainActor` just to plan which types
// are due.

import Foundation

// MARK: - Due-types planner (WP-16 step 2/3)

/// Plain, HealthKit-free snapshot of exactly the one `SyncState` field this
/// planner needs (`lastSyncedAt`) -- deliberately not the real `SyncState`
/// (a SwiftData `@Model` class that needs a live `ModelContext` even to read
/// a single field, and whose module, CoreModel, is MainActor-isolated by
/// default per architecture.md §3) so `dueTypes(...)` stays a plain,
/// synchronous, data-in/data-out function. The app target's BGTask handler
/// builds a `[GoogleDataType: SyncStateSnapshot]` from real `SyncState` rows
/// (via its own `ModelContext`, exactly like `SyncEngine.performSync`
/// already does) immediately before calling `dueTypes(...)`.
nonisolated public struct SyncStateSnapshot: Sendable, Equatable {
    /// `nil` = never synced (WP-16 step 2: "or never synced" is always due).
    public var lastSyncedAt: Date?

    public init(lastSyncedAt: Date? = nil) {
        self.lastSyncedAt = lastSyncedAt
    }
}

/// WP-16 step 2/3's required pure planner: "a type is 'due' if its
/// `SyncState.lastSyncedAt` is older than some interval, or never synced."
/// Returns the due subset of `allTypes`, ordered **most-overdue first**
/// (never-synced types first, then descending by staleness) so that if the
/// background handler's time budget (`BackgroundSyncBudget`) runs out before
/// every due type is attempted, the types that have gone longest without a
/// successful sync are the ones `SyncEngine.syncAll(types:)` reaches first.
/// Ties (e.g. two never-synced types) preserve `allTypes`' original relative
/// order (`Array.sorted(by:)` is a stable sort).
///
/// `minInterval` is this planner's own throttle, independent of whatever
/// cadence `BGTaskScheduler`/the OS actually wakes the app at (that's an
/// opportunistic hint the system may ignore) -- it exists so a background
/// wake that happens to land moments after a manual "Sync Now" (or a
/// previous background run) doesn't immediately re-mark every type due
/// again.
public nonisolated func dueTypes<Type: Hashable>(
    allTypes: [Type],
    syncStates: [Type: SyncStateSnapshot],
    now: Date,
    minInterval: TimeInterval
) -> [Type] {
    allTypes
        .filter { isDue(type: $0, syncStates: syncStates, now: now, minInterval: minInterval) }
        .sorted { staleness(of: $0, syncStates: syncStates, now: now) > staleness(of: $1, syncStates: syncStates, now: now) }
}

/// `true` when `type` has never synced, or its last successful sync is at
/// least `minInterval` old as of `now` (boundary is inclusive: exactly
/// `minInterval` old counts as due).
private nonisolated func isDue<Type: Hashable>(
    type: Type,
    syncStates: [Type: SyncStateSnapshot],
    now: Date,
    minInterval: TimeInterval
) -> Bool {
    guard let lastSyncedAt = syncStates[type]?.lastSyncedAt else { return true }
    return now.timeIntervalSince(lastSyncedAt) >= minInterval
}

/// Sort key for `dueTypes(...)`'s "most-overdue first" ordering. Never
/// synced sorts as `.infinity` so it always outranks any real elapsed
/// interval, however large.
private nonisolated func staleness<Type: Hashable>(
    of type: Type,
    syncStates: [Type: SyncStateSnapshot],
    now: Date
) -> TimeInterval {
    guard let lastSyncedAt = syncStates[type]?.lastSyncedAt else { return .infinity }
    return now.timeIntervalSince(lastSyncedAt)
}

// MARK: - Time budget (WP-16 step 2: "hard time budget (~20 s)")

/// A background task's real enforcement mechanism is `BGTask
/// .expirationHandler` (the system doesn't expose a "budget remaining" API
/// -- it just calls your expiration handler shortly before your allotted
/// background execution time runs out, per Apple's `BackgroundTasks`
/// documentation). This type exists so the *decision* "is there still
/// budget to start another unit of work" is a plain, pure function over an
/// elapsed-time value the app target measures however it likes
/// (`ContinuousClock`, `Date`, ...) -- unit-testable without a real
/// `BGTask`, exactly like `dueTypes(...)` above.
nonisolated public struct BackgroundSyncBudget: Sendable, Equatable {
    /// WP-16 step 2's "~20 s" figure -- deliberately below a `BGAppRefreshTask`'s
    /// typical real-world allotment (commonly quoted around 30 s) so there's
    /// margin to finish the in-flight type's write and call
    /// `task.setTaskCompleted(_:)` before the system would forcibly
    /// terminate the process.
    public var limit: TimeInterval

    public init(limit: TimeInterval = 20) {
        self.limit = limit
    }

    /// Whether there's still budget to *start* another type's sync, given
    /// how much wall-clock time has elapsed since the handler began work.
    /// Doesn't itself read a clock -- the caller supplies `elapsed` so this
    /// stays a pure function.
    public nonisolated func hasRemainingBudget(elapsed: TimeInterval) -> Bool {
        elapsed < limit
    }
}

// MARK: - Bundled configuration (mirrors SyncEngineTypes.swift's SyncConfiguration)

/// Bundles this file's tunable constants in one place, the same way
/// `SyncConfiguration` (SyncEngineTypes.swift) centralizes `SyncEngine`'s own
/// window sizing -- so `FitBridgeApp.swift`'s BGTask handler references one
/// documented default instead of re-declaring magic numbers at the call
/// site.
nonisolated public struct BackgroundSyncConfiguration: Sendable, Equatable {
    /// `dueTypes(...)`'s throttle (WP-16 step 2). Default 15 minutes,
    /// matching architecture.md §1's "~15 min" Google-side sync cadence --
    /// there's no point marking a type due again faster than upstream data
    /// could plausibly have changed.
    public var minInterval: TimeInterval
    /// The handler's time budget (WP-16 step 2: "~20 s").
    public var budget: BackgroundSyncBudget
    /// How far out to request the *next* `BGAppRefreshTaskRequest.earliestBeginDate`.
    /// 30 minutes is a hint, not a guarantee -- the system may run the task
    /// earlier or much later depending on battery, usage patterns, and Low
    /// Power Mode.
    public var reschedulingInterval: TimeInterval

    public init(
        minInterval: TimeInterval = 15 * 60,
        budget: BackgroundSyncBudget = BackgroundSyncBudget(),
        reschedulingInterval: TimeInterval = 30 * 60
    ) {
        self.minInterval = minInterval
        self.budget = budget
        self.reschedulingInterval = reschedulingInterval
    }
}

// MARK: - Reschedule invariant (WP-16 step 1: "always reschedule, even on failure")

/// WP-16 step 1's explicit, twice-stated requirement: "schedule next [BG
/// task occurrence] on every run and in the handler (always reschedule,
/// even on failure)". This package never imports `BackgroundTasks` (only
/// the app target does -- see `FitBridgeApp.swift`'s header), so the actual
/// `BGTaskScheduler.shared.submit(_:)` call can't be unit-tested here; what
/// *can* be pinned here, and regression-tested without any BGTaskScheduler
/// dependency, is the underlying reason the app target's handler reschedules
/// unconditionally rather than only on success: architecture.md D3's cursor
/// safety means there is no `SyncOutcome` combination -- including "every
/// type errored" -- for which skipping the next scheduled attempt would
/// ever be the correct call. Expressed as a function (not just a comment)
/// specifically so a future change can't silently special-case "don't
/// bother rescheduling if everything just failed" without a test noticing.
public nonisolated func shouldRescheduleBackgroundSync(after outcomes: [SyncOutcome]) -> Bool {
    true
}
