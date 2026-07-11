// WorkoutBuilding.swift
//
// WP-12 (implementation-plan.md): the injectable seam around
// `HKWorkoutBuilder` -- a concrete class, not itself protocol-based -- so
// `HealthKitWriter.saveWorkout(_:)` (HealthKitWriter.swift) can be driven by
// a mock in unit tests (`Tests/SyncKitTests/HealthKitWriter/MockWorkoutBuilder.swift`)
// exactly as `HealthStoreProtocol` already lets `save`/`existingExternalIDs`/
// etc. run against `MockHealthStore` without a HealthKit entitlement -- see
// HealthStoreProtocol.swift's header ("Why this protocol does *not* pass raw
// NSPredicate/HKQuery through") for the established precedent this mirrors.
//
// `HKWorkoutBuilder`'s real API (verified against the real iOS 26.4
// simulator SDK header, `HealthKit.framework/Headers/HKWorkoutBuilder.h`,
// and against a scratch `swiftc -typecheck` run with this repo's exact
// Package.swift flags -- see progress.md's WP-12 entry) is:
// `beginCollection(at:)`, `addSamples(_:)`, `addMetadata(_:)`,
// `endCollection(at:)`, `finishWorkout()` -- all completion-handler methods
// the Swift overlay bridges to `async throws`
// (`NS_SWIFT_ASYNC_NAME`/`NS_SWIFT_ASYNC_THROWS_ON_FALSE` in the header).
// `finishWorkout()`'s own doc comment: "If the returned workout is nil, an
// error may have occurred... If both workout and error are nil then
// finishing the workout succeeded but the workout sample is not available
// because the device is locked" -- i.e. a `nil`, non-throwing result is a
// **valid success**, not a failure. `WorkoutBuilding.finishWorkout()` mirrors
// that contract exactly (`throws -> HKWorkout?`); callers (`HealthKitWriter
// .saveWorkout(_:)`) must never treat a thrown-free `nil` as an error.
#if canImport(HealthKit)
import HealthKit

/// Abstracts the handful of `HKWorkoutBuilder` operations
/// `HealthKitWriter.saveWorkout(_:)` needs. Conforming types:
/// `HKWorkoutBuilderAdapter` (below -- the real `HKWorkoutBuilder` adapter)
/// for production, and `MockWorkoutBuilder` (test target only) for unit
/// tests that must run without a HealthKit entitlement or an authorized
/// store.
public protocol WorkoutBuilding: Sendable {
    func beginCollection(at start: Date) async throws
    func addSamples(_ samples: [HKSample]) async throws
    func addMetadata(_ metadata: [String: Any]) async throws
    func endCollection(at end: Date) async throws
    /// `nil` without throwing is a documented success case (see this file's
    /// header) -- never treat it as an error.
    func finishWorkout() async throws -> HKWorkout?
}

/// Creates a fresh `WorkoutBuilding` for one workout. A new builder per
/// workout mirrors `HKWorkoutBuilder`'s own single-use lifecycle (it becomes
/// unusable after `finishWorkout()`/`discardWorkout()`).
public protocol WorkoutBuilderFactory: Sendable {
    func makeBuilder(activityType: HKWorkoutActivityType, device: HKDevice?) -> WorkoutBuilding
}

/// The real `WorkoutBuilding` adapter -- a thin, direct translation into
/// `HKWorkoutBuilder`'s real async methods, with zero business logic of its
/// own (that lives in `HealthKitWriter.saveWorkout(_:)`, which orchestrates
/// this protocol's methods in the right order and builds the attached
/// distance/energy samples).
public final class HKWorkoutBuilderAdapter: WorkoutBuilding, Sendable {
    private let builder: HKWorkoutBuilder

    public init(builder: HKWorkoutBuilder) {
        self.builder = builder
    }

    public func beginCollection(at start: Date) async throws {
        try await builder.beginCollection(at: start)
    }

    public func addSamples(_ samples: [HKSample]) async throws {
        try await builder.addSamples(samples)
    }

    public func addMetadata(_ metadata: [String: Any]) async throws {
        try await builder.addMetadata(metadata)
    }

    public func endCollection(at end: Date) async throws {
        try await builder.endCollection(at: end)
    }

    public func finishWorkout() async throws -> HKWorkout? {
        try await builder.finishWorkout()
    }
}

/// The real `WorkoutBuilderFactory` -- wraps a shared `HKHealthStore` (same
/// "one store per app" posture as `HealthKitStore`/`HealthKitAuth`,
/// HealthStoreProtocol.swift/HealthKitAuth.swift).
public final class HealthKitWorkoutBuilderFactory: WorkoutBuilderFactory, Sendable {
    private let healthStore: HKHealthStore

    public init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    public func makeBuilder(activityType: HKWorkoutActivityType, device: HKDevice?) -> WorkoutBuilding {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: device)
        return HKWorkoutBuilderAdapter(builder: builder)
    }
}
#endif
