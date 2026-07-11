// HealthKitIdentifierClassifierTests.swift
//
// WP-06 (implementation-plan.md) required test: "unit-test the
// GoogleDataType→HKType mapping table." This suite is the pure-layer half —
// no HealthKit import, so it always compiles and runs, including on this
// package's macOS test host (WP-06's platform constraint).
//
// The central assertion is *completeness*: every `GoogleDataType` whose
// `writability` is `.healthKit(identifier)` (CoreModel's single source of
// truth for these strings) must have its `identifier` recognized by
// `HealthKitIdentifierClassifier` — an unrecognized string must never be
// silently ignored.

import CoreModel
import Testing
@testable import SyncKit

@Suite struct HealthKitIdentifierClassifierTests {
    /// Every `.healthKit` writability string across all 39 `GoogleDataType`
    /// cases classifies to *something* — never `nil`. This is the completeness
    /// guarantee WP-06 asks for: CoreModel's writability table is the single
    /// source of truth, and this test walks every case CoreModel currently
    /// defines, so adding a new `.healthKit` case there without a matching
    /// classifier update fails this test immediately.
    @Test func everyHealthKitWritabilityStringClassifies() {
        for dataType in GoogleDataType.allCases {
            guard case .healthKit(let identifier) = dataType.writability else { continue }
            let kind = HealthKitIdentifierClassifier.classify(identifier)
            #expect(
                kind != nil,
                "GoogleDataType.\(dataType) writability string \"\(identifier)\" did not classify to any known HealthKitIdentifierKind — update HealthKitIdentifierClassifier."
            )
        }
    }

    /// At least one `.healthKit` case exists per structural kind this
    /// classifier knows about (quantity, category, the workout sentinel, the
    /// food correlation sentinel) — guards against the completeness test
    /// above passing vacuously if CoreModel ever stopped emitting one of these
    /// shapes entirely.
    @Test func allFourStructuralKindsAreExercisedByCoreModel() {
        var sawQuantity = false
        var sawCategory = false
        var sawWorkout = false
        var sawCorrelationFood = false
        for dataType in GoogleDataType.allCases {
            guard case .healthKit(let identifier) = dataType.writability else { continue }
            switch HealthKitIdentifierClassifier.classify(identifier) {
            case .quantity: sawQuantity = true
            case .category: sawCategory = true
            case .workout: sawWorkout = true
            case .correlationFood: sawCorrelationFood = true
            case nil: break
            }
        }
        #expect(sawQuantity)
        #expect(sawCategory)
        #expect(sawWorkout)
        #expect(sawCorrelationFood)
    }

    /// P0 write set (implementation-plan.md WP-06 step 2): steps, heart rate,
    /// and weight classify as quantities; sleep classifies as a category.
    @Test func p0WriteSetClassifiesAsExpected() {
        let expectations: [(GoogleDataType, HealthKitIdentifierKind)] = [
            (.steps, .quantity(identifier: "HKQuantityTypeIdentifierStepCount")),
            (.heartRate, .quantity(identifier: "HKQuantityTypeIdentifierHeartRate")),
            (.weight, .quantity(identifier: "HKQuantityTypeIdentifierBodyMass")),
            (.sleep, .category(identifier: "HKCategoryTypeIdentifierSleepAnalysis")),
        ]
        for (dataType, expectedKind) in expectations {
            guard case .healthKit(let identifier) = dataType.writability else {
                Issue.record("\(dataType) unexpectedly has no .healthKit writability")
                continue
            }
            #expect(HealthKitIdentifierClassifier.classify(identifier) == expectedKind)
        }
    }

    /// The two documented sentinels (Exercise → HKWorkoutType, Food/Nutrition
    /// Log → HKCorrelationTypeIdentifierFood; CoreModel's GoogleDataType.swift
    /// doc comments, progress.md WP-02 deviation note (4)) classify to the
    /// dedicated sentinel kinds, not to a quantity/category guess.
    @Test func sentinelStringsClassifyAsSentinels() {
        #expect(HealthKitIdentifierClassifier.classify("HKWorkoutType") == .workout)
        #expect(
            HealthKitIdentifierClassifier.classify("HKCorrelationTypeIdentifierFood") == .correlationFood
        )
        if case .healthKit(let exerciseID) = GoogleDataType.exercise.writability {
            #expect(exerciseID == HealthKitIdentifierClassifier.workoutSentinel)
        } else {
            Issue.record("GoogleDataType.exercise unexpectedly has no .healthKit writability")
        }
        for foodLike in [GoogleDataType.food, .nutritionLog] {
            if case .healthKit(let id) = foodLike.writability {
                #expect(id == HealthKitIdentifierClassifier.correlationFoodSentinel)
            } else {
                Issue.record("\(foodLike) unexpectedly has no .healthKit writability")
            }
        }
    }

    /// Unknown/malformed strings never silently classify to something — they
    /// must surface as `nil` so callers throw rather than mis-map.
    @Test func unknownStringsClassifyToNil() {
        #expect(HealthKitIdentifierClassifier.classify("") == nil)
        #expect(HealthKitIdentifierClassifier.classify("bogus") == nil)
        #expect(HealthKitIdentifierClassifier.classify("HKQuantityType") == nil) // missing "Identifier"
        #expect(HealthKitIdentifierClassifier.classify("HKWorkoutTypeIdentifier") == nil) // not the real sentinel
        #expect(HealthKitIdentifierClassifier.classify("HKCorrelationTypeIdentifierWorkout") == nil)
    }

    /// `.localOnly`/`.skip` types (which never carry a HealthKit identifier
    /// string at all) have nothing for this classifier to see — confirms the
    /// completeness test above isn't accidentally checking every case,
    /// only the `.healthKit` ones.
    @Test func nonHealthKitWritabilityTypesAreExcludedFromClassification() {
        let localOnlyOrSkip = GoogleDataType.allCases.filter {
            if case .healthKit = $0.writability { return false }
            return true
        }
        #expect(!localOnlyOrSkip.isEmpty)
        for dataType in localOnlyOrSkip {
            switch dataType.writability {
            case .healthKit:
                Issue.record("\(dataType) should have been filtered out")
            case .localOnly, .skip:
                continue
            }
        }
    }
}
