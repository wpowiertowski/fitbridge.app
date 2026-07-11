// ChatTurn.swift
// CoreModel
//
// One message in the Coach conversation (WP-25 Chat UI). See implementation-plan.md
// WP-02 step 2.

import Foundation
import SwiftData

@Model
public final class ChatTurn {
    /// `"user" | "assistant"`.
    public var role: String

    public var content: String

    /// `ProviderID.rawValue` of whichever `CoachProvider` produced this turn (empty/
    /// irrelevant for user turns).
    public var provider: String

    /// Links to the `ContextSnapshot` sent for this turn (assistant turns only —
    /// `nil` for user turns, which don't have a context sent *to* them).
    public var contextSnapshotID: UUID?

    public var createdAt: Date

    public init(
        role: String,
        content: String,
        provider: String = "",
        contextSnapshotID: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.role = role
        self.content = content
        self.provider = provider
        self.contextSnapshotID = contextSnapshotID
        self.createdAt = createdAt
    }
}
