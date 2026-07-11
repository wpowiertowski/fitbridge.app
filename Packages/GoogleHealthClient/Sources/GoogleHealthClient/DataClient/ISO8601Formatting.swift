// ISO8601Formatting.swift
//
// Shared RFC 3339 / ISO 8601 date (de)serialization for the Health API's
// `startTime`/`endTime` fields. Two formatters because fixtures/real
// responses may or may not include fractional seconds.

import Foundation

nonisolated enum ISO8601Formatting {
    // `nonisolated(unsafe)`: each formatter is configured once at first
    // access and never mutated afterward; only its (read-only, thread-safe
    // in practice) `string(from:)`/`date(from:)` methods are called after
    // that.
    nonisolated(unsafe) private static let basic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func string(from date: Date) -> String {
        basic.string(from: date)
    }

    static func date(from string: String) -> Date? {
        basic.date(from: string) ?? fractional.date(from: string)
    }
}
