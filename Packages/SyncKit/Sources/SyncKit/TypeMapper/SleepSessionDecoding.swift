// SleepSessionDecoding.swift
//
// WP-07 step 3 (implementation-plan.md): decodes the wire shape of a Google
// sleep session's nested stage breakdown, as preserved verbatim in
// `GoogleDataPoint.sessionPayload` (WP-05's `sleep.json` fixture assumes this
// shape -- a `"sleep.segment"` array of `{startTime, endTime, stage}`
// objects; see that fixture's own `_comment` for the reasoning, since
// base-knowledge.md documents the `<data_type>.<field>` nesting convention
// but not a session's exact internal shape).
//
// Deliberately its own file / HealthKit-free, same rationale as
// GoogleHealthClient's `ISO8601Formatting.swift` (which this mirrors but
// cannot reuse directly -- that type is package-internal, not `public`):
// two `ISO8601DateFormatter`s (with/without fractional seconds) because
// fixtures or real responses may or may not include them.

import Foundation

nonisolated struct SleepSessionWire: Decodable {
    nonisolated struct Segment: Decodable {
        let startTime: Date
        let endTime: Date
        let stage: String
    }

    let segments: [Segment]

    private enum CodingKeys: String, CodingKey {
        case segments = "sleep.segment"
    }
}

nonisolated enum SleepSessionDecoding {
    // `nonisolated(unsafe)`: each formatter is configured once at first
    // access and never mutated afterward; only its (read-only, thread-safe
    // in practice) `date(from:)` method is called after that -- same
    // rationale/precedent as GoogleHealthClient's `ISO8601Formatting.swift`.
    nonisolated(unsafe) private static let basicFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated(unsafe) private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func date(from string: String) -> Date? {
        basicFormatter.date(from: string) ?? fractionalFormatter.date(from: string)
    }

    /// Decodes `payload` into `SleepSessionWire`, returning `nil` (never
    /// throwing) on any malformed shape -- callers treat that identically to
    /// "no session data," i.e. `.skip` (WP-07 step 5: never crash).
    static func decode(_ payload: Data) -> SleepSessionWire? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder throws -> Date in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = SleepSessionDecoding.date(from: string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unparseable ISO 8601 date: \"\(string)\""
                )
            }
            return date
        }
        return try? decoder.decode(SleepSessionWire.self, from: payload)
    }
}
