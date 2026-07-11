// HealthKitObjectTypeResolver.swift
//
// WP-06 (implementation-plan.md): the HealthKit-only half of the identifier
// string → concrete HKObjectType conversion (see HealthKitIdentifier.swift for
// the pure, always-compiled classification half this builds on).
//
// Guarded with #if canImport(HealthKit) per WP-06's platform constraint:
// HealthKit is not available on every platform `swift test` might run this
// package on, so anything that actually names an `HK*` type lives behind this
// guard. (On this repo's current macOS development host, HealthKit happens to
// be importable and its type-lookup APIs — HKObjectType.quantityType(for:) and
// friends — are safe to call without a HealthKit entitlement or Info.plist
// usage strings, since they only construct type-descriptor metadata and touch
// no health data or authorization state. The guard is kept anyway as the
// portable, forward-looking boundary WP-06 asks for.)

#if canImport(HealthKit)
import HealthKit

/// Resolves a HealthKit identifier string (as produced by CoreModel's
/// `GoogleDataType.writability` table) into the concrete `HKSampleType` used
/// to request authorization or build samples/workouts/correlations.
///
/// All four kinds `HealthKitIdentifierKind` distinguishes — quantity,
/// category, workout, and food correlation — are `HKSampleType` subclasses
/// (`HKQuantityType`, `HKCategoryType`, `HKWorkoutType`, `HKCorrelationType`),
/// so a single `HKSampleType` return type covers every case: it can be used
/// directly for `HKHealthStore.requestAuthorization(toShare:read:)`'s
/// `toShare` set, and widened to `HKObjectType` for the `read` set.
public enum HealthKitObjectTypeResolver {
    /// Resolve `identifier`. Throws `UnresolvedHealthKitIdentifier` — never
    /// returns a placeholder or drops the request — when the pure classifier
    /// doesn't recognize the string's shape, *or* when it recognizes the shape
    /// but the specific rawValue isn't a HealthKit type this SDK knows about
    /// (e.g. a typo'd or since-removed identifier constant).
    public static func sampleType(
        for identifier: String
    ) throws(UnresolvedHealthKitIdentifier) -> HKSampleType {
        guard let kind = HealthKitIdentifierClassifier.classify(identifier) else {
            throw UnresolvedHealthKitIdentifier(identifier: identifier)
        }
        switch kind {
        case .quantity(let raw):
            guard let type = HKObjectType.quantityType(
                forIdentifier: HKQuantityTypeIdentifier(rawValue: raw)
            ) else {
                throw UnresolvedHealthKitIdentifier(identifier: identifier)
            }
            return type
        case .category(let raw):
            guard let type = HKObjectType.categoryType(
                forIdentifier: HKCategoryTypeIdentifier(rawValue: raw)
            ) else {
                throw UnresolvedHealthKitIdentifier(identifier: identifier)
            }
            return type
        case .workout:
            return HKObjectType.workoutType()
        case .correlationFood:
            guard let type = HKObjectType.correlationType(
                forIdentifier: HKCorrelationTypeIdentifier(rawValue: HealthKitIdentifierClassifier.correlationFoodSentinel)
            ) else {
                throw UnresolvedHealthKitIdentifier(identifier: identifier)
            }
            return type
        }
    }
}
#endif
