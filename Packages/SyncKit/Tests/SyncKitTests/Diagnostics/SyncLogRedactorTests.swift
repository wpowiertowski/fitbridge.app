// SyncLogRedactorTests.swift
//
// WP-18 (implementation-plan.md) "Tests:" line, verbatim: "log entry
// redaction (feed a fake error containing a token-like string; assert
// stored entry passes the redaction filter)." Exercises
// `SyncLogRedactor.redact(_:)` directly (this file) plus the full
// `SyncEngineLogRecorder` -> `SyncLogStore` round trip
// (SyncRunRecordingTests.swift) so both "the filter itself works" and "the
// filter is actually wired into what gets stored" are covered.
import Foundation
import Testing
@testable import SyncKit

@Suite struct SyncLogRedactorTests {
    @Test func googleAccessTokenShapedStringIsRedacted() {
        let raw = "Google 401: invalid token ya29.a0AfH6SMBx9pQ7z3kL8nR2vW1yD4tG6hJ0mN5oP8qR3sT7uV1wX2yZ3aB4cD5eF6gH7"
        let redacted = SyncLogRedactor.redact(raw)
        #expect(!redacted.contains("ya29"))
        #expect(redacted.contains(SyncLogRedactor.redactedMarker))
    }

    @Test func googleRefreshTokenShapedStringIsRedacted() {
        let raw = "refresh failed for 1//0gABCDEfghijKLMNOpqrstUVWXYZ0123456789abcdefghijklmnop"
        let redacted = SyncLogRedactor.redact(raw)
        #expect(!redacted.contains("1//0gABCDEfghijKLMNOpqrstUVWXYZ"))
        #expect(redacted.contains(SyncLogRedactor.redactedMarker))
    }

    @Test func anthropicKeyShapedStringIsRedacted() {
        let raw = "provider auth failed: sk-ant-api03-ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-abcdefghij"
        let redacted = SyncLogRedactor.redact(raw)
        #expect(!redacted.contains("sk-ant-"))
        #expect(redacted.contains(SyncLogRedactor.redactedMarker))
    }

    @Test func openAIKeyShapedStringIsRedacted() {
        let raw = "unauthorized: sk-ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let redacted = SyncLogRedactor.redact(raw)
        #expect(!redacted.contains("sk-ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"))
        #expect(redacted.contains(SyncLogRedactor.redactedMarker))
    }

    @Test func googleAPIKeyShapedStringIsRedacted() {
        let raw = "request failed with key AIzaSyABCDEFGHIJKLMNOPQRSTUVWXYZ0123456"
        let redacted = SyncLogRedactor.redact(raw)
        #expect(!redacted.contains("AIzaSy"))
        #expect(redacted.contains(SyncLogRedactor.redactedMarker))
    }

    @Test func bearerHeaderShapedStringIsRedacted() {
        let raw = "HTTP 401 -- header was Bearer abcDEF123456.ghiJKL789012.mnoPQR345678"
        let redacted = SyncLogRedactor.redact(raw)
        #expect(!redacted.contains("abcDEF123456.ghiJKL789012.mnoPQR345678"))
        #expect(redacted.contains(SyncLogRedactor.redactedMarker))
    }

    @Test func unknownButOpaqueLongTokenShapedRunIsRedactedByTheCatchAll() {
        // Doesn't match any *named* prefix above -- exercises the
        // "unaudited future error type" fallback this file's header
        // describes.
        let raw = "unexpected credential blob 9f8e7d6c5b4a3928170615243346576879a0b1c2d3e4f5"
        let redacted = SyncLogRedactor.redact(raw)
        #expect(!redacted.contains("9f8e7d6c5b4a3928170615243346576879a0b1c2d3e4f5"))
        #expect(redacted.contains(SyncLogRedactor.redactedMarker))
    }

    @Test func ordinaryErrorProseIsLeftUntouched() {
        // Realistic non-secret error text -- must NOT be mangled by the
        // catch-all (no run of 24+ token-alphabet characters appears here).
        let raw = "The request timed out. (NSURLErrorDomain -1001)"
        #expect(SyncLogRedactor.redact(raw) == raw)
    }

    @Test func multipleTokensInOneMessageAreAllRedacted() {
        let raw = "exchange failed: code ya29.a0AfH6SMBxABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789, retry key sk-ant-api03-ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let redacted = SyncLogRedactor.redact(raw)
        #expect(!redacted.contains("ya29"))
        #expect(!redacted.contains("sk-ant-"))
        #expect(redacted.components(separatedBy: SyncLogRedactor.redactedMarker).count - 1 == 2)
    }
}
