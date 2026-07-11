// SyncRunRecordingTests.swift
//
// WP-18 (implementation-plan.md): covers (1) the redaction round trip --
// `SyncEngineLogRecorder` must never let a token-shaped `SyncOutcome
// .errorMessage` reach `SyncLogStore` un-redacted (the WP's required "log
// entry redaction" test, exercised here end-to-end rather than just against
// `SyncLogRedactor` in isolation -- see SyncLogRedactorTests.swift for the
// unit-level coverage of the filter itself); and (2) that the one additive
// hook this WP put in `SyncEngine.swift` (the optional `runRecorder:`
// parameter) is actually invoked, exactly once per completed run, on both
// the success and the failure path.
#if canImport(HealthKit)
import CoreModel
import Foundation
import GoogleHealthClient
import HealthKit
import SwiftData
import Testing
@testable import SyncKit

@Suite struct SyncRunRecordingTests {
    // MARK: - SyncEngineLogRecorder redaction round trip

    @Test func recorderRedactsATokenShapedErrorMessageBeforeItReachesTheStore() async throws {
        let store = SyncLogStore(capacity: 10, persistence: NullSyncLogPersistence())
        let clock = TestSyncClock(Date(timeIntervalSince1970: 1_800_000_000))
        let recorder = SyncEngineLogRecorder(store: store, clock: clock)

        let outcome = SyncOutcome(
            dataType: .heartRate,
            status: .error,
            itemCount: 3,
            errorMessage: "Google 401: invalid token ya29.a0AfH6SMBxABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        )
        await recorder.record(outcome)

        let entries = await store.recentEntries()
        #expect(entries.count == 1)
        let stored = try #require(entries.first)
        #expect(stored.dataType == .heartRate)
        #expect(stored.status == .error)
        #expect(stored.itemCount == 3)
        #expect(stored.timestamp == clock.now())
        let message = try #require(stored.errorMessage)
        #expect(!message.contains("ya29"))
        #expect(message.contains(SyncLogRedactor.redactedMarker))
    }

    @Test func recorderStoresAPlainErrorMessageUnchangedWhenNothingTokenShapedIsPresent() async {
        let store = SyncLogStore(capacity: 10, persistence: NullSyncLogPersistence())
        let recorder = SyncEngineLogRecorder(store: store, clock: TestSyncClock(Date()))
        let outcome = SyncOutcome(dataType: .sleep, status: .error, itemCount: 0, errorMessage: "The request timed out.")
        await recorder.record(outcome)
        let entries = await store.recentEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.errorMessage == "The request timed out.")
    }

    @Test func recorderStoresASuccessfulOutcomeWithNoErrorMessage() async {
        let store = SyncLogStore(capacity: 10, persistence: NullSyncLogPersistence())
        let recorder = SyncEngineLogRecorder(store: store, clock: TestSyncClock(Date()))
        await recorder.record(SyncOutcome(dataType: .steps, status: .ok, itemCount: 42))
        let entries = await store.recentEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.errorMessage == nil)
        #expect(entries.first?.itemCount == 42)
        #expect(entries.first?.status == .ok)
    }

    // MARK: - SyncEngine wiring: the additive `runRecorder:` hook fires exactly once per run

    @Test func syncEngineRecordsExactlyOneEntryPerSuccessfulRun() async throws {
        let container = try CoreModel.makeContainer(inMemory: true)
        let client = MockGoogleReconcileClient()
        let now = TypeMapperFixtures.date("2026-07-10T12:00:00Z")
        client.setPage(
            type: .steps,
            pageToken: nil,
            page: Page(
                points: [
                    GoogleDataPoint(
                        id: "steps-1",
                        dataType: .steps,
                        start: now.addingTimeInterval(-60),
                        end: now,
                        source: DataSource(platform: "IOS", deviceDisplayName: "Fitbit Air", recordingMethod: nil),
                        values: ["steps.count": 120]
                    ),
                ],
                nextPageToken: nil
            )
        )

        let store = SyncLogStore(capacity: 10, persistence: NullSyncLogPersistence())
        let recorder = SyncEngineLogRecorder(store: store, clock: TestSyncClock(now))
        let engine = SyncEngine(
            client: client,
            writer: HealthKitWriter(store: MockHealthStore()),
            modelContainer: container,
            clock: TestSyncClock(now),
            runRecorder: recorder
        )

        let outcome = await engine.sync(type: .steps)
        #expect(outcome.status == .ok)

        let entries = await store.recentEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.dataType == .steps)
        #expect(entries.first?.status == .ok)
        #expect(entries.first?.itemCount == outcome.itemCount)
    }

    @Test func syncEngineRecordsARedactedEntryOnAFailedRun() async throws {
        let container = try CoreModel.makeContainer(inMemory: true)
        let client = MockGoogleReconcileClient()
        let now = TypeMapperFixtures.date("2026-07-10T12:00:00Z")
        client.setScript(
            type: .heartRate,
            pageToken: nil,
            results: [.failure(.decodingFailed("Bearer ya29.a0AfH6SMBxABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 rejected"))]
        )

        let store = SyncLogStore(capacity: 10, persistence: NullSyncLogPersistence())
        let recorder = SyncEngineLogRecorder(store: store, clock: TestSyncClock(now))
        let engine = SyncEngine(
            client: client,
            writer: HealthKitWriter(store: MockHealthStore()),
            modelContainer: container,
            clock: TestSyncClock(now),
            runRecorder: recorder
        )

        let outcome = await engine.sync(type: .heartRate)
        #expect(outcome.status == .error)

        let entries = await store.recentEntries()
        #expect(entries.count == 1)
        let stored = try #require(entries.first)
        #expect(stored.dataType == .heartRate)
        #expect(stored.status == .error)
        let message = try #require(stored.errorMessage)
        #expect(!message.contains("ya29"))
        #expect(message.contains(SyncLogRedactor.redactedMarker))
    }

    @Test func syncEngineWithNoRecorderInjectedBehavesExactlyAsBefore() async throws {
        // Default `runRecorder: nil` (SyncEngine.swift): every pre-existing
        // call site (every WP-09..17 test, and any future one that doesn't
        // pass this parameter) must keep working unchanged.
        let container = try CoreModel.makeContainer(inMemory: true)
        let client = MockGoogleReconcileClient()
        let now = TypeMapperFixtures.date("2026-07-10T12:00:00Z")
        client.setPage(type: .weight, pageToken: nil, page: Page(points: [], nextPageToken: nil))

        let engine = SyncEngine(
            client: client,
            writer: HealthKitWriter(store: MockHealthStore()),
            modelContainer: container,
            clock: TestSyncClock(now)
        )
        let outcome = await engine.sync(type: .weight)
        #expect(outcome.status == .ok)
    }
}
#endif
