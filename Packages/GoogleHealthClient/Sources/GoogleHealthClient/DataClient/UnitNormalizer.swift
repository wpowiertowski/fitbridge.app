// UnitNormalizer.swift
//
// WP-05 step 3 (implementation-plan.md) / base-knowledge.md §2 "odd base
// units": "e.g. distances in millimeters for precision. Normalize on
// ingest... document every conversion in one `UnitNormalizer` table."
//
// One row per known unit quirk, keyed by the *fully-qualified* wire field
// name (`"<dataType.filterName>.<field>"`) so the same unqualified field name
// in a different data type isn't accidentally converted. Applied while
// decoding a `GoogleDataPoint` (see `GoogleHealthClient.decodeDataPoint`),
// before the `<data_type>.` prefix is stripped from the key stored in
// `GoogleDataPoint.values`.

import CoreModel

nonisolated public enum UnitNormalizer {
    /// `field` is the fully-qualified wire key, e.g. `"distance.distance"`.
    static let conversions: [String: @Sendable (Double) -> Double] = [
        // Distance: millimeters -> meters (base-knowledge.md §2's one named
        // example of an "odd base unit"). WP-07's TypeMapper further converts
        // meters -> HealthKit's `HKUnit.meter()` (already the base unit, so
        // no further scaling there).
        "distance.distance": { millimeters in millimeters / 1000.0 },
    ]

    /// Returns `rawValue` converted per the table above, or unchanged if no
    /// conversion is documented for `dataType.field`.
    ///
    /// Takes `dataType.rawValue` (== `filterName`, base-knowledge §2's
    /// snake_case filter identifier) directly rather than the `GoogleDataType`
    /// computed property `filterName` itself: `filterName` is a user-declared
    /// computed property in CoreModel, which -- like this package -- opts
    /// into `.defaultIsolation(MainActor.self)` (architecture.md §3), so
    /// referencing it would make this synchronous, `nonisolated` table
    /// lookup require crossing onto the main actor for what is, in
    /// `GoogleDataType`, a one-line passthrough (`{ rawValue }`).
    /// `RawRepresentable`'s synthesized `rawValue` is not subject to that
    /// per-type default-isolation inference, so using it directly keeps this
    /// function (and everywhere that calls it, transitively) nonisolated.
    static func normalize(dataType: GoogleDataType, field: String, rawValue: Double) -> Double {
        let key = "\(dataType.rawValue).\(field)"
        guard let convert = conversions[key] else { return rawValue }
        return convert(rawValue)
    }
}
