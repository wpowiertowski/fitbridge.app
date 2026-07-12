// GoogleOAuthScope.swift
//
// base-knowledge.md §2: "Scopes are HTTP URLs of the form
// https://www.googleapis.com/auth/googlehealth.{scope}.{readonly|writeonly}."
// `GoogleDataType.Scope` (CoreModel) names the scope *family*
// (`.activityAndFitness`, `.healthMetrics`, ...); this file owns the mapping
// from that family to the literal URL fragment Google's OAuth server expects,
// since that mapping is specific to *this* package's auth concern, not to
// CoreModel's vocabulary.

import CoreModel

nonisolated public enum GoogleOAuthScope {
    public enum AccessKind: String, Sendable {
        case readonly
        case writeonly
    }

    /// The `{scope}` fragment from base-knowledge §2's URL template, per
    /// `GoogleDataType.Scope` case. HealthLoom only ever reads (architecture.md
    /// D1/D2 -- Google is a read-only upstream for this app), so `.readonly`
    /// is the only access kind actually requested; `.writeonly` is modeled
    /// for completeness/documentation.
    private static func fragment(for scope: GoogleDataType.Scope) -> String {
        switch scope {
        case .activityAndFitness: return "activity_and_fitness"
        case .healthMetrics: return "health_metrics_and_measurements"
        case .sleep: return "sleep"
        case .nutrition: return "nutrition"
        case .ecg: return "ecg"
        case .irn: return "irn"
        }
    }

    /// Full scope URL, e.g.
    /// `https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly`.
    public static func urlString(for scope: GoogleDataType.Scope, access: AccessKind = .readonly) -> String {
        "https://www.googleapis.com/auth/googlehealth.\(fragment(for: scope)).\(access.rawValue)"
    }
}
