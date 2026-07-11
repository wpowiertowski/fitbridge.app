// SyncState.swift
// CoreModel
//
// Per-data-type sync bookkeeping only — never sample values (architecture.md D2).
// See implementation-plan.md WP-02 step 2 and WP-09 (SyncEngine, which owns this model).

import Foundation
import SwiftData

/// One row per `GoogleDataType.filterName`, tracking incremental-sync and backfill
/// progress. Holds no health values — see architecture.md D2.
@Model
public final class SyncState {
    /// `GoogleDataType.filterName` (snake_case) — the unique key for this row.
    @Attribute(.unique) public var dataType: String

    /// High-water mark for incremental sync (architecture.md D3). `nil` = never synced.
    public var lastSyncedAt: Date?

    /// Historical-backfill cursor (WP-15, architecture.md D5): walks backward in chunks;
    /// `nil` means backfill hasn't started or has completed to the chosen horizon.
    public var backfillCursor: Date?

    /// `"idle" | "ok" | "error"` — kept as a plain string so SwiftData's schema doesn't
    /// need a migration every time a new status is added; `SyncKit` owns the enum this
    /// mirrors.
    public var lastStatus: String

    /// Redacted error message for the dashboard/sync log — never a raw token or health
    /// value (architecture.md D11).
    public var lastError: String?

    public var itemCount: Int

    public init(
        dataType: String,
        lastSyncedAt: Date? = nil,
        backfillCursor: Date? = nil,
        lastStatus: String = "idle",
        lastError: String? = nil,
        itemCount: Int = 0
    ) {
        self.dataType = dataType
        self.lastSyncedAt = lastSyncedAt
        self.backfillCursor = backfillCursor
        self.lastStatus = lastStatus
        self.lastError = lastError
        self.itemCount = itemCount
    }
}
