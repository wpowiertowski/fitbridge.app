// DerivedInsight.swift
// CoreModel
//
// A generated coach insight (e.g. the morning `DailyInsight`, WP-23), persisted so it
// can be shown again and traced back to the fields that produced it. See
// implementation-plan.md WP-02 step 2.

import Foundation
import SwiftData

@Model
public final class DerivedInsight {
    public var text: String
    public var createdAt: Date

    /// `ProviderID.rawValue` of whichever `CoachProvider` generated this insight.
    public var sourceProvider: String

    /// `ProfileField.key`s that fed this insight — supports the "What did the coach
    /// see?" trace UI (architecture.md D7) without re-deriving.
    public var sourceFields: [String]

    public init(
        text: String,
        createdAt: Date = .now,
        sourceProvider: String,
        sourceFields: [String] = []
    ) {
        self.text = text
        self.createdAt = createdAt
        self.sourceProvider = sourceProvider
        self.sourceFields = sourceFields
    }
}
