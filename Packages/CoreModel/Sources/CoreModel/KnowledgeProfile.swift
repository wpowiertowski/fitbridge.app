// KnowledgeProfile.swift
// CoreModel
//
// The compact, human-readable profile CoachKit's KnowledgeStore derives (WP-19) and
// ContextAssembler reads from exclusively (architecture.md D7). See
// implementation-plan.md WP-02 step 2.

import Foundation
import SwiftData

@Model
public final class KnowledgeProfile {
    /// Derived facts + user goals/corrections, each independently excludable/clinical.
    public var sections: [ProfileField]

    public var updatedAt: Date

    public init(sections: [ProfileField] = [], updatedAt: Date = .now) {
        self.sections = sections
        self.updatedAt = updatedAt
    }
}
