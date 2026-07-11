// HealthKitIdentifier.swift
//
// WP-06 (implementation-plan.md): "a pure, unit-testable function that
// converts a HealthKit identifier string from CoreModel's writability table
// into the concrete HKObjectType." This file is the pure half of that split
// (see HealthKitObjectTypeResolver.swift for the HealthKit-only half).
//
// Deliberately imports neither HealthKit nor CoreModel: classifying the
// *shape* of an identifier string ("this looks like a quantity type", "this is
// the workout sentinel") is just string matching against a documented set of
// prefixes/sentinels, so it needs no framework at all. That keeps this table's
// completeness testable on every platform `swift test` runs on — including
// macOS, where HealthKit is either unavailable or unsafe to exercise for real
// inside a plain SPM test binary (no HealthKit entitlement, no Info.plist
// usage-description strings) — without instantiating a single HK type.
//
// The two sentinel cases exist because Exercise and Food/Nutrition Log don't
// correspond to a single `HKQuantityTypeIdentifier`/`HKCategoryTypeIdentifier`
// string. CoreModel's `GoogleDataType.Writability.healthKit` doc comments
// document exactly these two literal strings for `.exercise` and
// `.food`/`.nutritionLog` (see also progress.md's WP-02 deviation note (4)):
// `"HKWorkoutType"` (there is no `HKWorkoutTypeIdentifier` constant — workouts
// are addressed via `HKObjectType.workoutType()`) and
// `"HKCorrelationTypeIdentifierFood"` (the real `HKCorrelationTypeIdentifier`
// rawValue for `HKObjectType.correlationType(forIdentifier: .food)`).

/// The structural kind of a HealthKit identifier string, classified without
/// importing HealthKit. See this file's header for why the split exists.
public enum HealthKitIdentifierKind: Sendable, Hashable {
    /// `identifier` is an `HKQuantityTypeIdentifier` rawValue, e.g.
    /// `"HKQuantityTypeIdentifierStepCount"`.
    case quantity(identifier: String)
    /// `identifier` is an `HKCategoryTypeIdentifier` rawValue, e.g.
    /// `"HKCategoryTypeIdentifierSleepAnalysis"`.
    case category(identifier: String)
    /// The `"HKWorkoutType"` sentinel — resolves to
    /// `HKObjectType.workoutType()`.
    case workout
    /// The `"HKCorrelationTypeIdentifierFood"` sentinel — resolves to
    /// `HKObjectType.correlationType(forIdentifier: .food)`.
    case correlationFood
}

/// Thrown (by `HealthKitObjectTypeResolver`, the HealthKit-only layer built on
/// top of this classifier) when a HealthKit identifier string has no known
/// resolution. Per WP-06: unknown/unresolvable strings must be surfaced, never
/// silently dropped from a requested set.
public struct UnresolvedHealthKitIdentifier: Error, Sendable, Hashable, CustomStringConvertible {
    public let identifier: String

    public init(identifier: String) {
        self.identifier = identifier
    }

    public var description: String {
        "Unresolvable HealthKit identifier string: \"\(identifier)\" — no known " +
        "HKQuantityType/HKCategoryType/HKWorkoutType/HKCorrelationType mapping. " +
        "If CoreModel's GoogleDataType.Writability just added a new .healthKit " +
        "string, HealthKitIdentifierClassifier needs updating to recognize it."
    }
}

/// Pure classifier: HealthKit identifier string (as produced by CoreModel's
/// `GoogleDataType.writability` table, the single source of truth for these
/// strings — this classifier never duplicates that table, it only recognizes
/// the *shape* of whatever string it's handed) → structural kind.
public enum HealthKitIdentifierClassifier {
    /// Sentinel for Exercise → `HKWorkoutType` (see this file's header).
    public static let workoutSentinel = "HKWorkoutType"
    /// Sentinel for Food/Nutrition Log → `HKCorrelationTypeIdentifierFood`
    /// (see this file's header).
    public static let correlationFoodSentinel = "HKCorrelationTypeIdentifierFood"

    private static let quantityPrefix = "HKQuantityTypeIdentifier"
    private static let categoryPrefix = "HKCategoryTypeIdentifier"

    /// Classify `identifier`. Returns `nil` for a string this classifier
    /// doesn't recognize as any known HealthKit shape — callers must treat
    /// `nil` as "throw" (see `UnresolvedHealthKitIdentifier`), per WP-06:
    /// unknown strings are surfaced, never silently dropped.
    ///
    /// Order matters only cosmetically here: the two sentinels never share a
    /// prefix with the two `HK*TypeIdentifier` families, so sentinel checks
    /// and prefix checks can't both match the same string.
    public static func classify(_ identifier: String) -> HealthKitIdentifierKind? {
        switch identifier {
        case workoutSentinel:
            return .workout
        case correlationFoodSentinel:
            return .correlationFood
        default:
            if identifier.hasPrefix(quantityPrefix) {
                return .quantity(identifier: identifier)
            }
            if identifier.hasPrefix(categoryPrefix) {
                return .category(identifier: identifier)
            }
            return nil
        }
    }
}
