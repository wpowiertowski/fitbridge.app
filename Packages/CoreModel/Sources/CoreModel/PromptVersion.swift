// PromptVersion.swift
// CoreModel
//
// History of the user-editable base system prompt (WP-21 PromptManager, WP-26 Prompt
// Editor). See implementation-plan.md WP-02 step 2 and architecture.md D10 — the
// immutable SafetyLayer suffix is never stored here; only the user-editable base.

import Foundation
import SwiftData

@Model
public final class PromptVersion {
    /// The user-editable base prompt text (SafetyLayer.text is appended at use time,
    /// never persisted as part of this string — architecture.md D10).
    public var body: String

    public var createdAt: Date

    /// Whether this version is FitBridge's shipped default (vs. a user edit/history
    /// entry) — lets the Prompt Editor's "reset to default" and diff-vs-default
    /// (WP-26) find the baseline without hardcoding it twice.
    public var isDefault: Bool

    public init(body: String, createdAt: Date = .now, isDefault: Bool = false) {
        self.body = body
        self.createdAt = createdAt
        self.isDefault = isDefault
    }
}
