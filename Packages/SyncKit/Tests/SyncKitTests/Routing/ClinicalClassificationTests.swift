// ClinicalClassificationTests.swift
//
// WP-14 (implementation-plan.md) "Tests:" line: "clinical flag set." Covers
// `isClinicalType(_:)`/`isClinicalType(rawDataType:)`
// (Routing/ClinicalClassification.swift): true for ECG/IRN, false for the
// other two `.localOnly` types (Active Zone Minutes, Active Minutes) and for
// a representative sample of `.healthKit`/`.skip` types, so this table can
// never silently drift from architecture.md D8's "ECG, AFib/IRN" list.

import CoreModel
import Testing
@testable import SyncKit

@Suite struct ClinicalClassificationTests {
    @Test func ecgAndIRNAreClinical() {
        #expect(isClinicalType(.electrocardiogram))
        #expect(isClinicalType(.irregularRhythmNotification))
    }

    @Test func theOtherTwoLocalOnlyTypesAreNotClinical() {
        // Sanity: both really are `.localOnly` (architecture.md D2) --
        // clinical-ness is orthogonal to writability, not implied by it.
        #expect(GoogleDataType.activeZoneMinutes.writability == .localOnly)
        #expect(GoogleDataType.activeMinutes.writability == .localOnly)
        #expect(!isClinicalType(.activeZoneMinutes))
        #expect(!isClinicalType(.activeMinutes))
    }

    @Test func healthKitWritableTypesAreNotClinical() {
        for type: GoogleDataType in [.steps, .heartRate, .weight, .sleep, .bloodGlucose, .oxygenSaturation] {
            #expect(!isClinicalType(type))
        }
    }

    @Test func skipWritabilityTypesAreNotClinical() {
        for type: GoogleDataType in [.altitude, .sedentaryPeriod, .dailyVO2Max] {
            #expect(!isClinicalType(type))
        }
    }

    @Test func everyGoogleDataTypeExceptECGAndIRNIsNonClinical() {
        // Exhaustive tripwire: if a future `GoogleDataType` case is added and
        // this table isn't updated, this test still passes as long as the
        // new case isn't accidentally ECG/IRN -- but it does guarantee no
        // *existing* case besides those two is ever miscategorized.
        let clinical = GoogleDataType.allCases.filter(isClinicalType)
        #expect(Set(clinical) == [.electrocardiogram, .irregularRhythmNotification])
    }

    // MARK: - `rawDataType:` convenience overload

    @Test func rawDataTypeOverloadMatchesTheEnumOverloadForKnownStrings() {
        #expect(isClinicalType(rawDataType: GoogleDataType.electrocardiogram.rawValue))
        #expect(isClinicalType(rawDataType: GoogleDataType.irregularRhythmNotification.rawValue))
        #expect(!isClinicalType(rawDataType: GoogleDataType.activeZoneMinutes.rawValue))
        #expect(!isClinicalType(rawDataType: GoogleDataType.activeMinutes.rawValue))
        #expect(!isClinicalType(rawDataType: GoogleDataType.steps.rawValue))
    }

    @Test func rawDataTypeOverloadReturnsFalseForAnUnrecognizedString() {
        #expect(!isClinicalType(rawDataType: "some_future_unmapped_type"))
    }
}
