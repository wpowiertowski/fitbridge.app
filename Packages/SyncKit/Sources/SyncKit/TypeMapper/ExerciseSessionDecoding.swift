// ExerciseSessionDecoding.swift
//
// WP-12 (implementation-plan.md): decodes the wire shape of a Google Exercise
// session's nested payload, as preserved verbatim in
// `GoogleDataPoint.sessionPayload`. Exercise is a Session (Se) record type
// per base-knowledge.md §3 -- exactly like Sleep -- so this file follows
// WP-07's `SleepSessionDecoding.swift` pattern precisely: a `nonisolated`
// wire struct decoded by a plain `JSONDecoder`, HealthKit-free, always
// compiles regardless of platform.
//
// base-knowledge.md documents neither Google's exact field names for
// Exercise's session payload nor an enumerated list of activity-type wire
// values -- §5's mapping-table row only says "~13 Google types are coarse";
// it doesn't name them. The wire shape below is therefore an invented,
// documented assumption (same posture WP-11 took for every field name it
// couldn't confirm -- weight's `mass`, height's `meters`, etc.), flagged
// here and in progress.md as needing reconciliation once real API access
// exists (still gated on P-1.3, the outstanding Google Cloud OAuth client).
//
// Assumed shape (mirrors the `<data_type>.<field>` nesting convention,
// base-knowledge.md §2):
//   {
//     "exercise.activity_type": "run",
//     "exercise.distance": 5000.0,
//     "exercise.energy": 350.0
//   }
//
// Why the *whole* payload -- including the numeric distance/energy fields,
// not just the non-numeric activity-type string -- is read from
// `sessionPayload` rather than `GoogleDataPoint.values`: GoogleHealthClient's
// `decodeDataPoint` (WP-05) puts a numeric wire field into `values` and
// *also* re-serializes the **entire** `value` object onto `sessionPayload`
// as soon as *any* field in it is non-numeric (`hasNestedFields`) -- which
// Exercise's activity-type string always triggers. Rather than reading
// distance/energy from `values` and the activity type from `sessionPayload`
// (two different places for one session), this decoder reads all three from
// `sessionPayload` alone, mirroring Sleep's precedent (which also never
// touches `.values`) and keeping one session's data in one place.
//
// Duration is deliberately **not** a separate wire field decoded here: the
// session's own outer `startTime`/`endTime` (`GoogleDataPoint.start`/`.end`)
// already bound the whole workout -- exactly what `HKWorkoutBuilder` needs
// for `beginCollection`/`endCollection` (HealthKitWriter.swift) -- so
// deriving duration from those two dates rather than decoding a redundant
// third field is a design decision, not an unconfirmed assumption.
//
// Distance unit: base-knowledge.md's *only* confirmed odd-base-unit example
// is the standalone "Distance" Google data type's own field (millimeters,
// per §2, normalized by GoogleHealthClient's `UnitNormalizer` -- keyed
// specifically to the wire key `"distance.distance"`). That normalizer does
// not cover Exercise's nested session payload at all: `sessionPayload` is
// preserved by `GoogleHealthClient.decodeDataPoint` **before** any unit
// normalization runs (it's the raw re-serialized `value` object), so any
// conversion for fields nested inside it is this decoder's own
// responsibility. This decoder assumes Exercise's nested distance field
// arrives already in **meters** (matching WP-11's "height already in
// meters" precedent, not the millimeter convention) -- flagged as an
// assumption to reconcile once a real payload is available; if it turns out
// to be millimeters like the standalone Distance type, only this file needs
// updating.

import Foundation

nonisolated struct ExerciseSessionWire: Decodable {
    let activityType: String
    let distanceMeters: Double?
    let energyKilocalories: Double?

    private enum CodingKeys: String, CodingKey {
        case activityType = "exercise.activity_type"
        case distanceMeters = "exercise.distance"
        case energyKilocalories = "exercise.energy"
    }
}

nonisolated enum ExerciseSessionDecoding {
    /// Decodes `payload` into `ExerciseSessionWire`, returning `nil` (never
    /// throwing) on any malformed shape or a missing/non-string activity
    /// type -- callers treat that identically to "no session data," i.e.
    /// `.skip` (WP-07 step 5's "never crash" rule, followed here too).
    static func decode(_ payload: Data) -> ExerciseSessionWire? {
        try? JSONDecoder().decode(ExerciseSessionWire.self, from: payload)
    }
}
