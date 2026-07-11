// ContextSnapshot.swift
// CoreModel
//
// The exact `HealthContext` sent to a `CoachProvider` for one turn, persisted verbatim
// so the "What did the coach see?" trace UI (architecture.md D7, WP-30) can render
// precisely what was shared — never a reconstruction. See implementation-plan.md WP-02
// step 2.

import Foundation
import SwiftData

@Model
public final class ContextSnapshot {
    /// Stable identifier `ChatTurn.contextSnapshotID` links back to.
    @Attribute(.unique) public var id: UUID

    /// The exact `HealthContext` sent, JSON-encoded verbatim (not re-derived at
    /// display time — that could drift from what was actually sent).
    public var json: Data

    public var createdAt: Date

    public init(id: UUID = UUID(), json: Data, createdAt: Date = .now) {
        self.id = id
        self.json = json
        self.createdAt = createdAt
    }
}
