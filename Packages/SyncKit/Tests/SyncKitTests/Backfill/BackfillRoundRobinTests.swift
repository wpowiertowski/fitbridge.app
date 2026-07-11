// BackfillRoundRobinTests.swift
//
// WP-15 (implementation-plan.md) "Tests:" line: "round-robin fairness
// (virtual clock)." Step 1: "process types round-robin so one huge type
// doesn't starve others."

#if canImport(HealthKit)
import CoreModel
import Foundation
import GoogleHealthClient
import HealthKit
import SwiftData
import Testing
@testable import SyncKit

@Suite struct BackfillRoundRobinTests {
    static let fixedNow = BackfillTestFixtures.date("2026-07-10T12:00:00Z")

    /// `.steps` (a "huge" type, `.year1` needs 13 chunks) and `.weight` (a
    /// "small" type, `.days30` needs exactly 1) share one coordinator and
    /// one horizon -- but the coordinator's `horizon` is global (WP-15's
    /// single horizon picker applying to every type), so both types walk to
    /// the *same* `.year1` horizon here; `.weight`'s "small" property in
    /// this test instead comes from giving it a `lastSyncedAt` already very
    /// close to the horizon (so it only needs 1 chunk to catch up), while
    /// `.steps` starts completely unsynced (13 chunks needed) -- exercising
    /// "one huge type" via chunk *count*, not via a different horizon.
    @Test func noTypeIsStarvedWhileAnotherFinishesRoundRobinAdvancesBothEveryRound() async throws {
        let container = try CoreModel.makeContainer(inMemory: true)
        let clock = TestSyncClock(Self.fixedNow)
        let mock = MockGoogleReconcileClient()
        mock.setPage(type: .steps, pageToken: nil, page: Page(points: [], nextPageToken: nil))
        mock.setPage(type: .weight, pageToken: nil, page: Page(points: [], nextPageToken: nil))

        // Seed .weight's SyncState so its walk-start is only one chunk away
        // from the (shared) horizon.
        let horizonDate = Self.fixedNow.addingTimeInterval(-365 * 24 * 3600)
        let seedContext = ModelContext(container)
        seedContext.insert(SyncState(
            dataType: GoogleDataType.weight.rawValue,
            lastSyncedAt: horizonDate.addingTimeInterval(20 * 24 * 3600)
        ))
        try seedContext.save()

        let coordinator = BackfillCoordinator(
            types: [.steps, .weight],
            client: mock,
            writer: HealthKitWriter(store: MockHealthStore()),
            modelContainer: container,
            clock: clock,
            horizonStore: InMemoryBackfillHorizonRecordStore(),
            horizon: .year1
        )

        // Round 1: both types must get a turn -- .weight must not be
        // starved by .steps needing many more chunks, and .steps must not
        // be blocked behind .weight finishing first.
        let round1 = await coordinator.runRound()
        guard case .processedChunk = round1[.steps] else {
            Issue.record(".steps should have processed a chunk in round 1, got \(String(describing: round1[.steps]))")
            return
        }
        guard case .processedChunk = round1[.weight] else {
            Issue.record(".weight should have processed a chunk in round 1, got \(String(describing: round1[.weight]))")
            return
        }

        // .weight finishes after its one chunk; keep running rounds and
        // confirm .weight reports (legitimately) done every round from here
        // on -- never re-processed, never blocking -- while .steps keeps
        // making steady forward progress, one chunk per round, until it too
        // finishes. This is round-robin fairness made concrete: neither
        // type's outcome ever depends on the other's remaining workload.
        var stepsChunksProcessed = 1
        var rounds = 1
        while true {
            let round = await coordinator.runRound()
            rounds += 1
            #expect(round[.weight] == .alreadyDone, "round \(rounds): .weight should stay done, not be touched again")
            switch round[.steps] {
            case .processedChunk:
                stepsChunksProcessed += 1
            case .alreadyDone:
                break
            default:
                Issue.record("round \(rounds): unexpected .steps outcome \(String(describing: round[.steps]))")
                return
            }
            if round[.steps] == .alreadyDone { break }
            if rounds > 20 {
                Issue.record("round-robin did not converge within 20 rounds")
                return
            }
        }

        // .year1 (365d) / 30d chunks = 13 chunks (12 full + 1 partial, per
        // BackfillChunkingTests' own boundary-math test).
        #expect(stepsChunksProcessed == 13)
        // Exactly one *extra* round beyond the 13 chunks -- the final round
        // is the one that discovers `.steps` has reached `.alreadyDone`
        // (the chunk before it was the 13th and last one actually pulled).
        // 14, not more: confirms "one chunk per type per round" -- no round
        // was skipped/wasted and no chunk was ever pulled twice.
        #expect(rounds == 14)
    }
}
#endif
