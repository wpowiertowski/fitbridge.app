// TypeMapperOutOfRangeTests.swift
//
// WP-07 (implementation-plan.md) "Tests:" line: "out-of-range values
// (negative steps, HR 0 / 400) -- decide and pin behavior (drop + count)."
// Pinned decision (documented in TypeMapper.swift's `decideSteps`/
// `decideHeartRate`/`heartRateValidRange`): **drop** -- route to `.skip`, the
// same outcome as any other unmappable data point, so downstream (WP-09's
// `SyncEngine`) doesn't need a second "rejected" channel. **Count** is
// deferred to that same downstream consumer, which already has a per-type
// counter (`CoreModel.SyncState.itemCount`) -- `TypeMapper` itself is a pure
// function with no side channel to count through.

import CoreModel
import Foundation
import GoogleHealthClient
import Testing
@testable import SyncKit

@Suite struct TypeMapperOutOfRangeTests {
    @Test func negativeStepsAreDropped() {
        let point = TypeMapperFixtures.stepsPoint(count: -1)
        #expect(TypeMapper.decide(point) == .skip)
    }

    /// Zero steps is a perfectly ordinary reading (an inactive hour) -- only
    /// *negative* counts are the sensor/data error this rule targets.
    @Test func zeroStepsIsAccepted() {
        let point = TypeMapperFixtures.stepsPoint(count: 0)
        #expect(TypeMapper.decide(point).isQuantity)
    }

    @Test func heartRateZeroIsDropped() {
        let point = TypeMapperFixtures.heartRatePoint(bpm: 0)
        #expect(TypeMapper.decide(point) == .skip)
    }

    @Test func heartRateFourHundredIsDropped() {
        let point = TypeMapperFixtures.heartRatePoint(bpm: 400)
        #expect(TypeMapper.decide(point) == .skip)
    }

    @Test func heartRateNegativeIsDropped() {
        let point = TypeMapperFixtures.heartRatePoint(bpm: -10)
        #expect(TypeMapper.decide(point) == .skip)
    }

    /// A plausible max-effort heart rate is comfortably inside the accepted
    /// range and must not be dropped by the same guard that rejects 400.
    @Test func heartRateAtPlausibleMaxEffortIsAccepted() {
        let point = TypeMapperFixtures.heartRatePoint(bpm: 190)
        #expect(TypeMapper.decide(point).isQuantity)
    }

    /// The boundary itself (300) is inclusive -- confirms the range's upper
    /// edge is deliberate, not off-by-one.
    @Test func heartRateAtUpperBoundaryIsAccepted() {
        let point = TypeMapperFixtures.heartRatePoint(bpm: 300)
        #expect(TypeMapper.decide(point).isQuantity)
    }

    @Test func heartRateJustAboveUpperBoundaryIsDropped() {
        let point = TypeMapperFixtures.heartRatePoint(bpm: 300.01)
        #expect(TypeMapper.decide(point) == .skip)
    }

    @Test func nonPositiveWeightIsDropped() {
        #expect(TypeMapper.decide(TypeMapperFixtures.weightPoint(mass: 0)) == .skip)
        #expect(TypeMapper.decide(TypeMapperFixtures.weightPoint(mass: -5)) == .skip)
    }

    // MARK: - WP-11 additions

    @Test func negativeDistanceIsDropped() {
        #expect(TypeMapper.decide(TypeMapperFixtures.distancePoint(meters: -1)) == .skip)
    }

    /// Zero distance is ordinary (no movement in the interval) -- only
    /// *negative* distance is the sensor/data error this guard targets.
    @Test func zeroDistanceIsAccepted() {
        #expect(TypeMapper.decide(TypeMapperFixtures.distancePoint(meters: 0)).isQuantity)
    }

    @Test func negativeFloorsIsDropped() {
        #expect(TypeMapper.decide(TypeMapperFixtures.floorsPoint(count: -1)) == .skip)
    }

    @Test func negativeActiveEnergyBurnedIsDropped() {
        #expect(TypeMapper.decide(TypeMapperFixtures.activeEnergyBurnedPoint(kcal: -1)) == .skip)
    }

    @Test func restingHeartRateFourHundredIsDropped() {
        #expect(TypeMapper.decide(TypeMapperFixtures.restingHeartRatePoint(bpm: 400)) == .skip)
    }

    @Test func negativeRespiratoryRateIsDropped() {
        #expect(TypeMapper.decide(TypeMapperFixtures.respiratoryRatePoint(breathsPerMinute: -1)) == .skip)
    }

    @Test func implausiblyHighRespiratoryRateIsDropped() {
        #expect(TypeMapper.decide(TypeMapperFixtures.respiratoryRatePoint(breathsPerMinute: 90)) == .skip)
    }

    @Test func nonPositiveVO2MaxIsDropped() {
        #expect(TypeMapper.decide(TypeMapperFixtures.vo2MaxPoint(value: 0)) == .skip)
        #expect(TypeMapper.decide(TypeMapperFixtures.vo2MaxPoint(value: -1)) == .skip)
    }

    @Test func implausibleHeightIsDropped() {
        // Comfortably outside any real human height -- catches an obvious
        // unit mismatch (e.g. centimeters mistaken for meters) rather than
        // a real child/adult height.
        #expect(TypeMapper.decide(TypeMapperFixtures.heightPoint(meters: 12.0)) == .skip)
        #expect(TypeMapper.decide(TypeMapperFixtures.heightPoint(meters: -1)) == .skip)
    }

    @Test func nonPositiveBloodGlucoseIsDropped() {
        #expect(TypeMapper.decide(TypeMapperFixtures.bloodGlucoseMgDLPoint(mgPerDL: 0)) == .skip)
        #expect(TypeMapper.decide(TypeMapperFixtures.bloodGlucoseMgDLPoint(mgPerDL: -1)) == .skip)
        #expect(TypeMapper.decide(TypeMapperFixtures.bloodGlucoseMmolLPoint(mmolPerL: 0)) == .skip)
        #expect(TypeMapper.decide(TypeMapperFixtures.bloodGlucoseMmolLPoint(mmolPerL: -1)) == .skip)
    }

    @Test func implausibleCoreBodyTemperatureIsDropped() {
        #expect(TypeMapper.decide(TypeMapperFixtures.coreBodyTemperaturePoint(celsius: 10)) == .skip)
        #expect(TypeMapper.decide(TypeMapperFixtures.coreBodyTemperaturePoint(celsius: 60)) == .skip)
    }

    @Test func negativeHydrationIsDropped() {
        #expect(TypeMapper.decide(TypeMapperFixtures.hydrationPoint(liters: -0.1)) == .skip)
    }

    /// Zero hydration logged is ordinary (an empty log entry, or a
    /// correction) -- only *negative* volume is the data error this guard
    /// targets.
    @Test func zeroHydrationIsAccepted() {
        #expect(TypeMapper.decide(TypeMapperFixtures.hydrationPoint(liters: 0)).isQuantity)
    }

    /// Missing both the mg/dL and the mmol/L field is treated identically
    /// to any other missing-expected-field case -- drop, never crash.
    @Test func bloodGlucoseWithNeitherUnitFieldIsDropped() {
        let point = GoogleDataPoint(
            id: "bg-missing", dataType: .bloodGlucose,
            start: TypeMapperFixtures.date("2026-07-01T12:00:00Z"),
            end: TypeMapperFixtures.date("2026-07-01T12:00:00Z"),
            source: DataSource(platform: nil, deviceDisplayName: nil, recordingMethod: nil),
            values: [:]
        )
        #expect(TypeMapper.decide(point) == .skip)
    }
}
