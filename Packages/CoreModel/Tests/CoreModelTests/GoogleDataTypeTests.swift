// GoogleDataTypeTests.swift
// CoreModelTests
//
// Covers implementation-plan.md WP-02's required tests:
// "GoogleDataType casing (body-fat vs body_fat); writability table matches
// base-knowledge §5 for all rows (table-driven test)."

import Foundation
import Testing
@testable import CoreModel

@Suite("GoogleDataType casing")
struct GoogleDataTypeCasingTests {
    @Test("body-fat / body_fat matches base-knowledge §2's literal example")
    func bodyFatMatchesBaseKnowledgeExample() {
        #expect(GoogleDataType.bodyFat.filterName == "body_fat")
        #expect(GoogleDataType.bodyFat.endpointName == "body-fat")
    }

    @Test("every case round-trips between kebab-case endpointName and snake_case filterName")
    func everyCaseRoundTripsBetweenCasings() {
        for type in GoogleDataType.allCases {
            let filter = type.filterName
            let endpoint = type.endpointName
            #expect(endpoint == filter.replacingOccurrences(of: "_", with: "-"), "\(type)")
            #expect(filter == endpoint.replacingOccurrences(of: "-", with: "_"), "\(type)")
            #expect(!filter.contains("-"), "\(type) filterName must be snake_case only")
            #expect(!endpoint.contains("_"), "\(type) endpointName must be kebab-case only")
        }
    }

    @Test("covers every row of base-knowledge §3 (39 data types)")
    func allCasesCoverEveryBaseKnowledgeRow() {
        #expect(GoogleDataType.allCases.count == 39)
    }
}

@Suite("GoogleDataType writability matches base-knowledge §5")
struct GoogleDataTypeWritabilityTests {
    /// Table-driven expectation transcribed from base-knowledge §5 (plus the
    /// deviations documented in GoogleDataType.swift and progress.md, where §5's
    /// naming doesn't exactly match a §3 row name).
    static let expected: [GoogleDataType: GoogleDataType.Writability] = [
        // ✅ writable
        .steps: .healthKit("HKQuantityTypeIdentifierStepCount"),
        .distance: .healthKit("HKQuantityTypeIdentifierDistanceWalkingRunning"),
        .floors: .healthKit("HKQuantityTypeIdentifierFlightsClimbed"),
        .activeEnergyBurned: .healthKit("HKQuantityTypeIdentifierActiveEnergyBurned"),
        .totalCalories: .healthKit("HKQuantityTypeIdentifierBasalEnergyBurned"),
        .heartRate: .healthKit("HKQuantityTypeIdentifierHeartRate"),
        .dailyRestingHeartRate: .healthKit("HKQuantityTypeIdentifierRestingHeartRate"),
        .heartRateVariability: .healthKit("HKQuantityTypeIdentifierHeartRateVariabilitySDNN"),
        .oxygenSaturation: .healthKit("HKQuantityTypeIdentifierOxygenSaturation"),
        .respiratoryRateSleepSummary: .healthKit("HKQuantityTypeIdentifierRespiratoryRate"),
        .vo2Max: .healthKit("HKQuantityTypeIdentifierVO2Max"),
        .runVO2Max: .healthKit("HKQuantityTypeIdentifierVO2Max"),
        .weight: .healthKit("HKQuantityTypeIdentifierBodyMass"),
        .height: .healthKit("HKQuantityTypeIdentifierHeight"),
        .bodyFat: .healthKit("HKQuantityTypeIdentifierBodyFatPercentage"),
        .bloodGlucose: .healthKit("HKQuantityTypeIdentifierBloodGlucose"),
        .coreBodyTemperature: .healthKit("HKQuantityTypeIdentifierBodyTemperature"),
        .sleep: .healthKit("HKCategoryTypeIdentifierSleepAnalysis"),
        .exercise: .healthKit("HKWorkoutType"),
        .hydrationLog: .healthKit("HKQuantityTypeIdentifierDietaryWater"),
        .food: .healthKit("HKCorrelationTypeIdentifierFood"),
        .nutritionLog: .healthKit("HKCorrelationTypeIdentifierFood"),

        // ⚠️/❌ local-only (base-knowledge §5; WP-14 persists all four to LocalSample)
        .activeMinutes: .localOnly,
        .activeZoneMinutes: .localOnly,
        .electrocardiogram: .localOnly,
        .irregularRhythmNotification: .localOnly,

        // unmapped / redundant daily-rollup duplicates → skip
        .activityLevel: .skip,
        .altitude: .skip,
        .caloriesInHeartRateZone: .skip,
        .dailyHeartRateVariability: .skip,
        .dailyHeartRateZones: .skip,
        .dailyOxygenSaturation: .skip,
        .dailyRespiratoryRate: .skip,
        .dailySleepTemperatureDerivations: .skip,
        .dailyVO2Max: .skip,
        .foodMeasurementUnit: .skip,
        .sedentaryPeriod: .skip,
        .swimLengthsData: .skip,
        .timeInHeartRateZone: .skip,
    ]

    @Test("expectation table itself covers every GoogleDataType exactly once")
    func expectationTableIsComplete() {
        #expect(Self.expected.count == GoogleDataType.allCases.count)
    }

    @Test("writability matches base-knowledge §5", arguments: GoogleDataType.allCases)
    func matchesTable(_ type: GoogleDataType) {
        guard let want = Self.expected[type] else {
            Issue.record("No expected writability entry for \(type)")
            return
        }
        #expect(type.writability == want, "\(type)")
    }

    @Test("every ✅ row resolves to a non-empty HealthKit identifier string")
    func healthKitIdentifiersAreNonEmpty() {
        for type in GoogleDataType.allCases {
            if case .healthKit(let identifier) = type.writability {
                #expect(!identifier.isEmpty, "\(type)")
            }
        }
    }
}
