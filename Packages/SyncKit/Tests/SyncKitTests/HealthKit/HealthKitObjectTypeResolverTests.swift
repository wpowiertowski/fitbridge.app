// HealthKitObjectTypeResolverTests.swift
//
// WP-06 (implementation-plan.md): exercises the HealthKit-only resolution
// layer (HealthKitObjectTypeResolver) against every real GoogleDataType
// writability string, confirming each resolves to the concrete HKObjectType
// subclass its structural kind promises. Guarded with #if canImport(HealthKit)
// so this suite compiles away entirely on a platform without HealthKit; on
// this repo's macOS test host HealthKit happens to be importable and type
// lookups (HKObjectType.quantityType(for:) etc.) are safe without an
// entitlement (they only construct type-descriptor metadata — no health data,
// no authorization state), so this suite runs for real here too.

#if canImport(HealthKit)
import CoreModel
import HealthKit
import Testing
@testable import SyncKit

@Suite struct HealthKitObjectTypeResolverTests {
    /// Every `.healthKit` writability string across all `GoogleDataType` cases
    /// resolves without throwing, and to the HKObjectType subclass its
    /// classified kind promises.
    @Test func everyHealthKitWritabilityStringResolves() throws {
        for dataType in GoogleDataType.allCases {
            guard case .healthKit(let identifier) = dataType.writability else { continue }
            let kind = HealthKitIdentifierClassifier.classify(identifier)
            let resolved = try HealthKitObjectTypeResolver.sampleType(for: identifier)
            switch kind {
            case .quantity:
                #expect(resolved is HKQuantityType, "\(dataType) (\(identifier)) should resolve to HKQuantityType")
            case .category:
                #expect(resolved is HKCategoryType, "\(dataType) (\(identifier)) should resolve to HKCategoryType")
            case .workout:
                #expect(resolved is HKWorkoutType, "\(dataType) (\(identifier)) should resolve to HKWorkoutType")
            case .correlationFood:
                #expect(resolved is HKCorrelationType, "\(dataType) (\(identifier)) should resolve to HKCorrelationType")
            case nil:
                Issue.record("\(dataType) (\(identifier)) has no classification -- see classifier test suite")
            }
        }
    }

    /// Round-trip: the resolved type's own `identifier` string matches the one
    /// CoreModel supplied, for both quantity and category kinds.
    @Test func resolvedIdentifierRoundTripsForQuantityAndCategory() throws {
        let stepCount = try HealthKitObjectTypeResolver.sampleType(for: "HKQuantityTypeIdentifierStepCount")
        #expect(stepCount.identifier == "HKQuantityTypeIdentifierStepCount")

        let sleep = try HealthKitObjectTypeResolver.sampleType(for: "HKCategoryTypeIdentifierSleepAnalysis")
        #expect(sleep.identifier == "HKCategoryTypeIdentifierSleepAnalysis")
    }

    /// P0 write set resolves to the exact four concrete types the onboarding
    /// permission sheet needs (implementation-plan.md WP-06 step 2).
    @Test func p0WriteSetResolvesToConcreteTypes() throws {
        let stepCount = try HealthKitObjectTypeResolver.sampleType(for: "HKQuantityTypeIdentifierStepCount")
        let heartRate = try HealthKitObjectTypeResolver.sampleType(for: "HKQuantityTypeIdentifierHeartRate")
        let bodyMass = try HealthKitObjectTypeResolver.sampleType(for: "HKQuantityTypeIdentifierBodyMass")
        let sleepAnalysis = try HealthKitObjectTypeResolver.sampleType(for: "HKCategoryTypeIdentifierSleepAnalysis")

        #expect(stepCount == HKObjectType.quantityType(forIdentifier: .stepCount))
        #expect(heartRate == HKObjectType.quantityType(forIdentifier: .heartRate))
        #expect(bodyMass == HKObjectType.quantityType(forIdentifier: .bodyMass))
        #expect(sleepAnalysis == HKObjectType.categoryType(forIdentifier: .sleepAnalysis))
    }

    /// The workout sentinel resolves to the real workout object type.
    @Test func workoutSentinelResolvesToWorkoutType() throws {
        let resolved = try HealthKitObjectTypeResolver.sampleType(for: "HKWorkoutType")
        #expect(resolved == HKObjectType.workoutType())
    }

    /// The food correlation sentinel resolves to the real `.food` correlation
    /// type.
    @Test func correlationFoodSentinelResolvesToFoodCorrelationType() throws {
        let resolved = try HealthKitObjectTypeResolver.sampleType(for: "HKCorrelationTypeIdentifierFood")
        #expect(resolved == HKObjectType.correlationType(forIdentifier: .food))
    }

    /// Unknown identifier strings throw `UnresolvedHealthKitIdentifier` --
    /// never silently drop or crash.
    @Test func unknownIdentifierThrows() {
        #expect(throws: UnresolvedHealthKitIdentifier.self) {
            try HealthKitObjectTypeResolver.sampleType(for: "NotARealIdentifier")
        }
    }

    @Test func unknownIdentifierErrorCarriesTheOffendingString() {
        do {
            _ = try HealthKitObjectTypeResolver.sampleType(for: "NotARealIdentifier")
            Issue.record("expected a throw")
        } catch {
            #expect(error.identifier == "NotARealIdentifier")
        }
    }
}
#endif
