// UnitNormalizerTests.swift
//
// WP-05 required test: "mm→m normalization." Exercises the `UnitNormalizer`
// table directly (in addition to the fixture-level golden test in
// GoogleDataPointDecodingTests) so the conversion math itself -- not just
// one fixture's specific numbers -- is pinned.

import CoreModel
import Testing
@testable import GoogleHealthClient

@Suite("UnitNormalizer")
struct UnitNormalizerTests {
    @Test("distance.distance converts millimeters to meters")
    func distanceMillimetersToMeters() {
        #expect(UnitNormalizer.normalize(dataType: .distance, field: "distance", rawValue: 1000) == 1.0)
        #expect(UnitNormalizer.normalize(dataType: .distance, field: "distance", rawValue: 15000) == 15.0)
        #expect(UnitNormalizer.normalize(dataType: .distance, field: "distance", rawValue: 0) == 0.0)
    }

    @Test("fields with no documented conversion pass through unchanged")
    func undocumentedFieldsPassThrough() {
        #expect(UnitNormalizer.normalize(dataType: .steps, field: "count", rawValue: 482) == 482)
        #expect(UnitNormalizer.normalize(dataType: .heartRate, field: "bpm", rawValue: 61) == 61)
        #expect(UnitNormalizer.normalize(dataType: .weight, field: "mass", rawValue: 70.5) == 70.5)
    }

    @Test("the same unqualified field name in a different data type is not accidentally converted")
    func conversionIsScopedToExactDataType() {
        // "distance" is only special-cased for GoogleDataType.distance, not
        // for some hypothetical other type that happened to reuse the field
        // name "distance".
        #expect(UnitNormalizer.normalize(dataType: .altitude, field: "distance", rawValue: 5000) == 5000)
    }
}
