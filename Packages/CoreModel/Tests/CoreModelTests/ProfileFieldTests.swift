// ProfileFieldTests.swift
// CoreModelTests
//
// Covers implementation-plan.md WP-02's required test: "clinical fields
// default-excluded" (architecture.md D8).

import Foundation
import Testing
@testable import CoreModel

@Suite("ProfileField clinical default exclusion (D8)")
struct ProfileFieldClinicalTests {
    @Test("isClinical: true defaults excludedFromAI to true")
    func clinicalFieldDefaultsToExcluded() {
        let field = ProfileField(
            key: "ecg.latestReading",
            displayText: "Sinus rhythm",
            source: "HealthKit",
            asOf: .now,
            isClinical: true
        )
        #expect(field.excludedFromAI == true)
    }

    @Test("isClinical: false defaults excludedFromAI to false")
    func nonClinicalFieldDefaultsToIncluded() {
        let field = ProfileField(
            key: "steps.dailyAverage30d",
            displayText: "~8,200 steps/day (30-day avg)",
            source: "HealthKit · Fitbit Air",
            asOf: .now,
            isClinical: false
        )
        #expect(field.excludedFromAI == false)
    }

    @Test("omitting isClinical also defaults excludedFromAI to false")
    func defaultInitDefaultsToIncluded() {
        let field = ProfileField(key: "k", displayText: "d", source: "s", asOf: .now)
        #expect(field.isClinical == false)
        #expect(field.excludedFromAI == false)
    }

    @Test("explicit excludedFromAI overrides the isClinical-derived default")
    func explicitOverrideWins() {
        // architecture.md D8: "Users can opt clinical fields in, but the safety
        // suffix still applies."
        let optedIn = ProfileField(
            key: "irn.count30d",
            displayText: "0 notifications (30d)",
            source: "LocalSample",
            asOf: .now,
            excludedFromAI: false,
            isClinical: true
        )
        #expect(optedIn.isClinical == true)
        #expect(optedIn.excludedFromAI == false)

        let forcedOut = ProfileField(
            key: "steps.dailyAverage30d",
            displayText: "~8,200 steps/day (30-day avg)",
            source: "HealthKit",
            asOf: .now,
            excludedFromAI: true,
            isClinical: false
        )
        #expect(forcedOut.isClinical == false)
        #expect(forcedOut.excludedFromAI == true)
    }
}

@Suite("HealthContext / ProfileField Codable round trip")
struct HealthContextCodableTests {
    @Test("HealthContext encodes and decodes losslessly")
    func roundTrips() throws {
        let field = ProfileField(
            key: "sleep.duration14d",
            displayText: "7h 12m avg (14 nights)",
            source: "HealthKit · Fitbit Air",
            asOf: .now,
            isClinical: false
        )
        let context = HealthContext(
            fields: [field],
            localeIdentifier: "en_US",
            unitSystem: .imperial,
            today: .now
        )

        let data = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(HealthContext.self, from: data)

        #expect(decoded == context)
    }
}
