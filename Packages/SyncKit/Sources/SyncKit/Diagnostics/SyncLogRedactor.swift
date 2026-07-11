// SyncLogRedactor.swift
//
// WP-18 (implementation-plan.md): redaction strategy for the one free-text
// field a `SyncLogEntry` carries, `errorMessage`. architecture.md §4 D11:
// "Logs / analytics / crash reports carry counts, types, and timestamps --
// never health values, never tokens."
//
// **Strategy decision, and why (the WP explicitly asks for this to be
// decided and justified): denylist-of-token-shaped-patterns, not
// allowlist-of-safe-fields.**
//
// An allowlist ("only ever persist fields drawn from a known-safe set") *is*
// the strategy for every other field on `SyncLogEntry`
// (`dataType`/`status`/`itemCount`/`timestamp`, SyncLogEntry.swift) -- each
// is a structured, non-free-text type (an enum case, an `Int`, a `Date`)
// that is structurally incapable of carrying a token or a health value, so
// no filter is even applicable to them; there is nothing to allowlist
// *within* a `GoogleDataType` case or an `Int` count.
//
// `errorMessage`, though, is arbitrary text: `SyncEngine.performSync`
// (SyncEngine.swift) builds it via `String(describing: error)` over
// whatever error surfaced from the entire pull -> map -> write pipeline --
// `GoogleHealthClientError` (GoogleHealthClient, already redaction-tested
// per its own WP-05 "redaction tripwire" -- a fake refresh token/auth code
// asserted absent from every `GoogleAuthError.description`),
// `HealthKitWriterError`, a SwiftData error, a plain `URLError`, or anything
// a future error type adds -- there is no fixed, enumerable "safe shape" to
// allowlist for free text. So this file pattern-matches *known token
// shapes* (Google OAuth access/refresh tokens, common LLM-provider API key
// prefixes, generic bearer-auth headers) plus a conservative
// long-opaque-run fallback for anything token-shaped this list doesn't name
// yet, and replaces every match with a fixed `[REDACTED]` marker -- a
// denylist, chosen specifically because it is the only strategy that can
// even apply to unstructured text, and because over-redacting a benign long
// identifier is an acceptable false positive where under-redacting a real
// secret is not.
//
// This is defense-in-depth, not the primary safeguard: `GoogleAuthManager`
// (GoogleHealthClient, WP-04/05) already builds its own `GoogleAuthError`
// descriptions without ever interpolating a raw token in the first place
// (verified by WP-05's own redaction tripwire test, progress.md's WP-05
// entry) -- this filter exists for the *unaudited* remainder of the error
// surface (SwiftData, HealthKit, URLSession, and any error type added
// later) where no such guarantee has been established, and for genuine
// defense-in-depth even where it has.
import Foundation

/// Pure, deterministic, no I/O -- safe to call from any isolation domain.
nonisolated public enum SyncLogRedactor {
    /// Fixed replacement text for any matched token-shaped substring.
    public static let redactedMarker = "[REDACTED]"

    /// Known token/secret prefixes, matched against their real-world shapes:
    ///   - `ya29.`   Google OAuth2 access tokens.
    ///   - `1//`     Google OAuth2 refresh tokens.
    ///   - `AIza`    Google API keys.
    ///   - `sk-ant-` Anthropic API keys.
    ///   - `sk-`     OpenAI-style API keys (generic "sk-" + long suffix).
    ///   - `Bearer ` generic bearer-auth header values.
    private static let knownPrefixPatterns: [String] = [
        #"ya29\.[A-Za-z0-9_\-]+"#,
        #"1//[A-Za-z0-9_\-]+"#,
        #"AIza[A-Za-z0-9_\-]{10,}"#,
        #"sk-ant-[A-Za-z0-9_\-]+"#,
        #"sk-[A-Za-z0-9]{16,}"#,
        #"(?i)bearer\s+[A-Za-z0-9._\-]+"#,
    ]

    /// Catch-all fallback: any run of 24+ characters drawn from the
    /// alphabet real tokens/keys/JWTs are built from
    /// (`[A-Za-z0-9._\-]`) is redacted even if it doesn't match one of the
    /// named prefixes above -- covers unknown/future token shapes at the
    /// cost of occasionally redacting a long benign identifier, which is
    /// the acceptable direction for this trade-off (see this file's
    /// header). Ordinary English error prose (short words, spaces) never
    /// hits this threshold.
    private static let opaqueRunPattern = #"[A-Za-z0-9._\-]{24,}"#

    private static let compiledPatterns: [NSRegularExpression] = {
        (knownPrefixPatterns + [opaqueRunPattern]).compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    /// Replaces every token-shaped substring of `raw` with
    /// `redactedMarker`.
    public static func redact(_ raw: String) -> String {
        var result = raw
        for pattern in compiledPatterns {
            result = pattern.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: redactedMarker
            )
        }
        return result
    }
}
