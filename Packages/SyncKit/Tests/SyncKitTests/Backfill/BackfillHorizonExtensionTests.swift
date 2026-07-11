// BackfillHorizonExtensionTests.swift
//
// WP-15 (implementation-plan.md) "Tests:" line: "horizon extension." Also
// architecture.md D5 / WP-15 step 3: "chosen horizon changeable (extending
// re-opens the walk)."

#if canImport(HealthKit)
import CoreModel
import Foundation
import GoogleHealthClient
import HealthKit
import SwiftData
import Testing
@testable import SyncKit

@Suite struct BackfillHorizonExtensionTests {
    static let fixedNow = BackfillTestFixtures.date("2026-07-10T12:00:00Z")
    static let day: TimeInterval = 24 * 3600

    @Test func completingA30DayHorizonThenExtendingTo90DaysResumesFromTheOldBoundaryRatherThanRestarting() async throws {
        let container = try CoreModel.makeContainer(inMemory: true)
        let horizonStore = InMemoryBackfillHorizonRecordStore()
        let clock = TestSyncClock(Self.fixedNow)
        let mock = MockGoogleReconcileClient()
        mock.setPage(type: .steps, pageToken: nil, page: Page(points: [], nextPageToken: nil))

        let coordinator = BackfillCoordinator(
            types: [.steps],
            client: mock,
            writer: HealthKitWriter(store: MockHealthStore()),
            modelContainer: container,
            clock: clock,
            horizonStore: horizonStore,
            horizon: .days30
        )

        // .days30 (30d) is an exact multiple of the 30d chunk size, so this
        // completes in exactly one chunk.
        let firstOutcome = await coordinator.runNextChunk(for: .steps)
        guard case .processedChunk(let firstWindow, _) = firstOutcome else {
            Issue.record("expected the first chunk to process, got \(firstOutcome)"); return
        }
        #expect(firstWindow.lowerBound == Self.fixedNow.addingTimeInterval(-30 * Self.day))

        let doneOutcome = await coordinator.runNextChunk(for: .steps)
        #expect(doneOutcome == .alreadyDone)
        #expect(try BackfillTestFixtures.syncState(container, type: .steps)?.backfillCursor == nil)
        #expect(await coordinator.completedHorizon(for: .steps) == .days30)

        // Extend: pick a strictly deeper horizon.
        await coordinator.setHorizon(.days90)

        let secondOutcome = await coordinator.runNextChunk(for: .steps)
        guard case .processedChunk(let secondWindow, _) = secondOutcome else {
            Issue.record("expected the walk to reopen and process a chunk, got \(secondOutcome)"); return
        }
        // Resumes from exactly the old (30d) horizon boundary -- continuing
        // the walk further back -- rather than restarting the whole walk
        // from `min(lastSyncedAt, now)` again (which would instead
        // re-request `[now-30d, now]`, identical to the very first chunk).
        #expect(secondWindow.upperBound == firstWindow.lowerBound)
        #expect(secondWindow.lowerBound == Self.fixedNow.addingTimeInterval(-60 * Self.day))

        let thirdOutcome = await coordinator.runNextChunk(for: .steps)
        guard case .processedChunk(let thirdWindow, _) = thirdOutcome else {
            Issue.record("expected a third (final) chunk to process, got \(thirdOutcome)"); return
        }
        #expect(thirdWindow.lowerBound == Self.fixedNow.addingTimeInterval(-90 * Self.day))

        let finalOutcome = await coordinator.runNextChunk(for: .steps)
        #expect(finalOutcome == .alreadyDone)
        #expect(await coordinator.completedHorizon(for: .steps) == .days90)

        // Never re-requested the already-covered [now-30d, now] window a
        // second time -- exactly 3 reconcile calls total (1 for the
        // original 30d completion + 2 for the 60d/90d extension), not 4.
        #expect(mock.calls.count == 3)
    }

    @Test func choosingAShallowerHorizonAfterADeeperOneIsCompleteIsANoOp() async throws {
        let container = try CoreModel.makeContainer(inMemory: true)
        let horizonStore = InMemoryBackfillHorizonRecordStore()
        let clock = TestSyncClock(Self.fixedNow)
        let mock = MockGoogleReconcileClient()
        mock.setPage(type: .steps, pageToken: nil, page: Page(points: [], nextPageToken: nil))

        let coordinator = BackfillCoordinator(
            types: [.steps],
            client: mock,
            writer: HealthKitWriter(store: MockHealthStore()),
            modelContainer: container,
            clock: clock,
            horizonStore: horizonStore,
            horizon: .days90
        )

        // Run to completion at 90d (3 chunks).
        for _ in 0..<3 {
            let outcome = await coordinator.runNextChunk(for: .steps)
            guard case .processedChunk = outcome else {
                Issue.record("expected a chunk to process, got \(outcome)"); return
            }
        }
        #expect(await coordinator.runNextChunk(for: .steps) == .alreadyDone)
        let callsAfter90d = mock.calls.count

        // Narrowing to 30d is satisfied by the already-completed 90d --
        // no-op, no new reconcile calls, no cursor reopened.
        await coordinator.setHorizon(.days30)
        #expect(await coordinator.runNextChunk(for: .steps) == .alreadyDone)
        #expect(mock.calls.count == callsAfter90d)
        #expect(try BackfillTestFixtures.syncState(container, type: .steps)?.backfillCursor == nil)
    }
}
#endif
