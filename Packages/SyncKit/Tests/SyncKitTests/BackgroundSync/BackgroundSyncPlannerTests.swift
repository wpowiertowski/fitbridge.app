// BackgroundSyncPlannerTests.swift
//
// WP-16 (implementation-plan.md) required tests: "unit-test the 'due types +
// budget' planner as a pure function (various states: never synced,
// recently synced, stale, mix)". Runs against `dueTypes(...)`,
// `BackgroundSyncBudget`, and `shouldRescheduleBackgroundSync(after:)` from
// `Sources/SyncKit/BackgroundSync/BackgroundSyncPlanner.swift` -- none of
// which import HealthKit or BackgroundTasks, so (unlike most of this
// package's `#if canImport(HealthKit)`-guarded suites) these tests need no
// platform guard at all and run identically everywhere `swift test` does.
// The one thing genuinely untestable here, by design (WP-16's own "Tests"
// line): the real `BGTaskScheduler` register/submit/simulate-launch flow --
// that's a manual lldb verification, documented in progress.md, not faked
// with a mock scheduler in this file.

import CoreModel
import Foundation
import Testing
@testable import SyncKit

@Suite("BackgroundSyncPlanner - dueTypes")
struct BackgroundSyncPlannerDueTypesTests {
    // Fixed reference instant so every test's "now" is deterministic --
    // this suite never calls `Date()` directly, matching this package's
    // existing virtual-clock convention (SyncEngineTests' `TestSyncClock`).
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let minInterval: TimeInterval = 900 // 15 minutes, matching BackgroundSyncConfiguration's default.

    @Test("never-synced type is always due")
    func neverSyncedIsDue() {
        let result = dueTypes(
            allTypes: [GoogleDataType.steps],
            syncStates: [:], // no entry at all == never synced
            now: now,
            minInterval: minInterval
        )
        #expect(result == [.steps])
    }

    @Test("explicit nil lastSyncedAt is also always due")
    func explicitNilLastSyncedAtIsDue() {
        let result = dueTypes(
            allTypes: [GoogleDataType.weight],
            syncStates: [.weight: SyncStateSnapshot(lastSyncedAt: nil)],
            now: now,
            minInterval: minInterval
        )
        #expect(result == [.weight])
    }

    @Test("recently synced type (well within minInterval) is not due")
    func recentlySyncedIsNotDue() {
        let result = dueTypes(
            allTypes: [GoogleDataType.heartRate],
            syncStates: [.heartRate: SyncStateSnapshot(lastSyncedAt: now.addingTimeInterval(-60))],
            now: now,
            minInterval: minInterval
        )
        #expect(result.isEmpty)
    }

    @Test("stale type (older than minInterval) is due")
    func staleIsDue() {
        let result = dueTypes(
            allTypes: [GoogleDataType.sleep],
            syncStates: [.sleep: SyncStateSnapshot(lastSyncedAt: now.addingTimeInterval(-3600))],
            now: now,
            minInterval: minInterval
        )
        #expect(result == [.sleep])
    }

    @Test("boundary: exactly minInterval old counts as due (inclusive)")
    func exactBoundaryIsDue() {
        let result = dueTypes(
            allTypes: [GoogleDataType.steps],
            syncStates: [.steps: SyncStateSnapshot(lastSyncedAt: now.addingTimeInterval(-minInterval))],
            now: now,
            minInterval: minInterval
        )
        #expect(result == [.steps])
    }

    @Test("boundary: one second inside minInterval is not due")
    func justInsideBoundaryIsNotDue() {
        let result = dueTypes(
            allTypes: [GoogleDataType.steps],
            syncStates: [.steps: SyncStateSnapshot(lastSyncedAt: now.addingTimeInterval(-minInterval + 1))],
            now: now,
            minInterval: minInterval
        )
        #expect(result.isEmpty)
    }

    @Test("mixed states: never-synced, recently-synced, and stale types filter and order correctly")
    func mixedStatesFilterAndOrder() {
        // .weight: never synced -> due, sorts first (infinite staleness).
        // .heartRate: synced 1 minute ago -> not due.
        // .sleep: synced 10 hours ago -> due, staler than .steps.
        // .steps: synced 2 hours ago -> due, less stale than .sleep.
        let syncStates: [GoogleDataType: SyncStateSnapshot] = [
            .heartRate: SyncStateSnapshot(lastSyncedAt: now.addingTimeInterval(-60)),
            .sleep: SyncStateSnapshot(lastSyncedAt: now.addingTimeInterval(-10 * 3600)),
            .steps: SyncStateSnapshot(lastSyncedAt: now.addingTimeInterval(-2 * 3600)),
        ]
        let result = dueTypes(
            allTypes: [.heartRate, .sleep, .steps, .weight],
            syncStates: syncStates,
            now: now,
            minInterval: minInterval
        )
        #expect(result == [.weight, .sleep, .steps])
    }

    @Test("ties (equal staleness) preserve allTypes' original relative order")
    func tiesPreserveOriginalOrder() {
        // Both never-synced -> tie on staleness (.infinity); stable sort
        // must preserve .bodyFat before .height (their order in allTypes).
        let result = dueTypes(
            allTypes: [GoogleDataType.bodyFat, GoogleDataType.height],
            syncStates: [:],
            now: now,
            minInterval: minInterval
        )
        #expect(result == [.bodyFat, .height])
    }

    @Test("empty allTypes returns empty")
    func emptyAllTypesReturnsEmpty() {
        let result = dueTypes(
            allTypes: [GoogleDataType](),
            syncStates: [:],
            now: now,
            minInterval: minInterval
        )
        #expect(result.isEmpty)
    }

    @Test("no due types returns empty, not every type")
    func noDueTypesReturnsEmpty() {
        let syncStates: [GoogleDataType: SyncStateSnapshot] = [
            .steps: SyncStateSnapshot(lastSyncedAt: now.addingTimeInterval(-1)),
            .heartRate: SyncStateSnapshot(lastSyncedAt: now),
        ]
        let result = dueTypes(
            allTypes: [.steps, .heartRate],
            syncStates: syncStates,
            now: now,
            minInterval: minInterval
        )
        #expect(result.isEmpty)
    }
}

@Suite("BackgroundSyncPlanner - BackgroundSyncBudget")
struct BackgroundSyncBudgetTests {
    @Test("elapsed well within limit has remaining budget")
    func withinLimitHasBudget() {
        let budget = BackgroundSyncBudget(limit: 20)
        #expect(budget.hasRemainingBudget(elapsed: 5) == true)
    }

    @Test("elapsed exactly at limit has no remaining budget (exclusive upper bound)")
    func atLimitHasNoBudget() {
        let budget = BackgroundSyncBudget(limit: 20)
        #expect(budget.hasRemainingBudget(elapsed: 20) == false)
    }

    @Test("elapsed beyond limit has no remaining budget")
    func beyondLimitHasNoBudget() {
        let budget = BackgroundSyncBudget(limit: 20)
        #expect(budget.hasRemainingBudget(elapsed: 45) == false)
    }

    @Test("default limit is 20 seconds per WP-16 step 2")
    func defaultLimitIsTwentySeconds() {
        #expect(BackgroundSyncBudget().limit == 20)
    }
}

@Suite("BackgroundSyncPlanner - BackgroundSyncConfiguration")
struct BackgroundSyncConfigurationTests {
    @Test("defaults match WP-16's documented figures")
    func defaultsMatchDocumentedFigures() {
        let config = BackgroundSyncConfiguration()
        #expect(config.minInterval == 15 * 60)
        #expect(config.budget.limit == 20)
        #expect(config.reschedulingInterval == 30 * 60)
    }
}

@Suite("BackgroundSyncPlanner - shouldRescheduleBackgroundSync")
struct ShouldRescheduleBackgroundSyncTests {
    @Test("empty outcomes still reschedules")
    func emptyOutcomesReschedules() {
        #expect(shouldRescheduleBackgroundSync(after: []) == true)
    }

    @Test("all-success outcomes reschedule")
    func allSuccessReschedules() {
        let outcomes = [
            SyncOutcome(dataType: .steps, status: .ok, itemCount: 10),
            SyncOutcome(dataType: .heartRate, status: .ok, itemCount: 3),
        ]
        #expect(shouldRescheduleBackgroundSync(after: outcomes) == true)
    }

    @Test("all-failure outcomes still reschedule (WP-16: 'always reschedule, even on failure')")
    func allFailureStillReschedules() {
        let outcomes = [
            SyncOutcome(dataType: .steps, status: .error, itemCount: 0, errorMessage: "boom"),
            SyncOutcome(dataType: .heartRate, status: .error, itemCount: 0, errorMessage: "boom"),
        ]
        #expect(shouldRescheduleBackgroundSync(after: outcomes) == true)
    }

    @Test("mixed success/failure outcomes reschedule")
    func mixedOutcomesReschedule() {
        let outcomes = [
            SyncOutcome(dataType: .steps, status: .ok, itemCount: 10),
            SyncOutcome(dataType: .heartRate, status: .error, itemCount: 0, errorMessage: "boom"),
        ]
        #expect(shouldRescheduleBackgroundSync(after: outcomes) == true)
    }
}
