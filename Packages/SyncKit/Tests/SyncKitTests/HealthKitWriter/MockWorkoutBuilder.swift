// MockWorkoutBuilder.swift
//
// WP-12 (implementation-plan.md) "Tests:" line: "a workout-builder
// integration test -- since a real HKWorkoutBuilder needs an authorized real
// store ... do a mock/protocol-seam test for the decision logic." This is
// that mock -- a `WorkoutBuilding`/`WorkoutBuilderFactory` conformer pair
// requiring no HealthKit entitlement, no simulator, no real `HKHealthStore`,
// mirroring `MockHealthStore.swift`'s own precedent for `HealthStoreProtocol`.

#if canImport(HealthKit)
import Foundation
import HealthKit
@testable import SyncKit

/// Records every call it receives, in order, so tests can assert
/// `HealthKitWriter.saveWorkout(_:)`'s orchestration follows the exact
/// `beginCollection -> addSamples -> addMetadata -> endCollection ->
/// finishWorkout` sequence WP-12 step 3 specifies.
final class MockWorkoutBuilder: WorkoutBuilding, @unchecked Sendable {
    enum Call: Equatable {
        case beginCollection(Date)
        case addSamples(Int)
        case addMetadata([String: String])
        case endCollection(Date)
        case finishWorkout
    }

    private(set) var calls: [Call] = []
    private(set) var lastAddedSamples: [HKSample] = []
    private(set) var lastMetadata: [String: Any] = [:]

    /// Set to make `finishWorkout()` throw instead of returning.
    var finishError: Error?
    /// The value `finishWorkout()` returns when `finishError` is nil --
    /// `nil` is itself a documented success case (see WorkoutBuilding.swift's
    /// header), so most tests never need to set this at all. Set via
    /// `makeFakeHKWorkoutForTesting` (below) only when a test specifically
    /// needs to prove the finished workout is discoverable via
    /// `existingExternalIDs` afterward.
    var finishResult: HKWorkout?
    /// If set, the finished workout (when non-nil) is also seeded into this
    /// store -- mirrors the real `HKWorkoutBuilder.finishWorkout()`'s
    /// documented behavior of saving directly into the health store itself,
    /// bypassing `HealthStoreProtocol.save(_:)` entirely (see
    /// HealthKitWriter.swift's `saveWorkout` doc comment). This is what lets
    /// a test prove workouts dedupe through the exact same
    /// `existingExternalIDs` mechanism as every other type, without a
    /// parallel path.
    var storeToSeedOnFinish: MockHealthStore?

    func beginCollection(at start: Date) async throws {
        calls.append(.beginCollection(start))
    }

    func addSamples(_ samples: [HKSample]) async throws {
        lastAddedSamples = samples
        calls.append(.addSamples(samples.count))
    }

    func addMetadata(_ metadata: [String: Any]) async throws {
        lastMetadata = metadata
        let stringly = metadata.compactMapValues { $0 as? String }
        calls.append(.addMetadata(stringly))
    }

    func endCollection(at end: Date) async throws {
        calls.append(.endCollection(end))
    }

    func finishWorkout() async throws -> HKWorkout? {
        calls.append(.finishWorkout)
        if let finishError {
            throw finishError
        }
        if let finishResult {
            storeToSeedOnFinish?.seed(finishResult, isAppWritten: true)
        }
        return finishResult
    }
}

/// Hands out the same `MockWorkoutBuilder` every time (a test wants to
/// inspect the one builder `saveWorkout` actually used) rather than a fresh
/// one per call, unlike the real `HealthKitWorkoutBuilderFactory` -- every
/// test in this file only ever calls `saveWorkout` once per assertion, so
/// this simplification is safe and keeps call-recording inspectable from the
/// test.
final class MockWorkoutBuilderFactory: WorkoutBuilderFactory, @unchecked Sendable {
    let builder: MockWorkoutBuilder
    private(set) var requestedActivityTypes: [HKWorkoutActivityType] = []

    init(builder: MockWorkoutBuilder = MockWorkoutBuilder()) {
        self.builder = builder
    }

    func makeBuilder(activityType: HKWorkoutActivityType, device: HKDevice?) -> WorkoutBuilding {
        requestedActivityTypes.append(activityType)
        return builder
    }
}

/// Test-only: constructs a real `HKWorkout` via its deprecated
/// `workoutWithActivityType:startDate:endDate:workoutEvents:totalEnergyBurned:totalDistance:metadata:`
/// initializer (bridged to `HKWorkout(activityType:start:end:workoutEvents:
/// totalEnergyBurned:totalDistance:metadata:)` in Swift). Production code
/// (`HealthKitWriter.saveWorkout(_:)`, HealthKitWriter.swift) never calls
/// this -- it exclusively uses `HKWorkoutBuilder`, per implementation-plan.md's
/// explicit "HKWorkout initializers are deprecated" note. This exists
/// *only* so a test can prove a workout `HKWorkoutBuilder.finishWorkout()`
/// produces is discoverable via `HealthKitWriter.existingExternalIDs(type:
/// .workoutType(), ...)` afterward -- there is no non-deprecated way to
/// construct a standalone `HKWorkout` value at all outside a live,
/// authorized `HKHealthStore` (that's the entire reason `HKWorkoutBuilder`
/// exists), so a test-only use of the deprecated initializer is the only
/// way to fabricate one.
///
/// Marking both this function *and* every call site
/// `@available(*, deprecated, ...)` silences the deprecation diagnostic
/// under this repo's `-warnings-as-errors` build -- confirmed empirically in
/// a disposable scratch SwiftPM package (`swift test -Xswiftc
/// -warnings-as-errors`, zero warnings) before writing this, per
/// progress.md's WP-12 entry.
@available(*, deprecated, message: "test-only fixture; production exclusively uses HKWorkoutBuilder, never a deprecated HKWorkout initializer")
func makeFakeHKWorkoutForTesting(
    activityType: HKWorkoutActivityType,
    start: Date,
    end: Date,
    metadata: [String: Any]
) -> HKWorkout {
    HKWorkout(
        activityType: activityType,
        start: start,
        end: end,
        workoutEvents: nil,
        totalEnergyBurned: nil,
        totalDistance: nil,
        metadata: metadata
    )
}
#endif
