// SyncTypeRow.swift
//
// WP-10 (implementation-plan.md step 2): one row per P0 type -- status icon,
// last-sync time ("synced 9m ago" framing, architecture.md §1), item count,
// and error text. `state` is `nil` only if `SyncEngine` has literally never
// created a `SyncState` row for this type yet (fresh install, before any
// sync attempt); `SyncState.lastStatus` itself defaults to `"idle"`
// (CoreModel's `SyncState.init`), so both cases render identically here.
//
// Every sub-value carries its own accessibility identifier
// (`dashboard.row.<GoogleDataType.rawValue>.*`) rather than relying on
// `.accessibilityElement(children: .combine)`, specifically so the WP-10 UI
// test can assert on each piece independently (implementation-plan.md
// WP-10's "Tests" line: "verified via view/accessibility identifiers"). No
// row-level container identifier is set: applying `.accessibilityIdentifier`
// to the enclosing `VStack` was observed (via a real `xcodebuild test` run
// against the simulator's accessibility snapshot) to cascade that one
// identifier onto every descendant accessibility element, clobbering the
// per-field identifiers below rather than coexisting with them -- so
// `.name` on the display-name `Text` doubles as "does this row exist" for
// callers that just need row-level presence.
//
// `itemCountText`/`Text(itemCountText)`: deliberately a `String` *variable*,
// not `Text("\(state?.itemCount ?? 0)")` -- that literal-interpolation form
// resolves to `Text(LocalizedStringKey)`, whose interpolation applies
// locale-aware grouping separators to interpolated numbers by default
// (observed producing "4,213" instead of "4213" against the real simulator
// run), which is both undesirable here and non-deterministic for the UI
// test asserting on this label's exact text.

import CoreModel
import SwiftUI

struct SyncTypeRow: View {
    let type: GoogleDataType
    let state: SyncState?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .accessibilityIdentifier("dashboard.row.\(type.rawValue).statusIcon")
                Text(displayName)
                    .font(.headline)
                    .accessibilityIdentifier("dashboard.row.\(type.rawValue).name")
                Spacer()
                Text(itemCountText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("dashboard.row.\(type.rawValue).itemCount")
            }
            Text(lastSyncedText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("dashboard.row.\(type.rawValue).lastSynced")
            if let error = state?.lastError, state?.lastStatus == "error" {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("dashboard.row.\(type.rawValue).error")
            }
        }
        .padding(.vertical, 4)
    }

    private var displayName: String {
        switch type {
        case .steps: return "Steps"
        case .heartRate: return "Heart Rate"
        case .weight: return "Weight"
        case .sleep: return "Sleep"
        default: return type.rawValue
        }
    }

    private var statusIcon: String {
        switch state?.lastStatus {
        case "ok": return "checkmark.circle.fill"
        case "error": return "exclamationmark.triangle.fill"
        default: return "circle.dashed"
        }
    }

    private var itemCountText: String {
        String(state?.itemCount ?? 0)
    }

    private var statusColor: Color {
        switch state?.lastStatus {
        case "ok": return .green
        case "error": return .red
        default: return .secondary
        }
    }

    private var lastSyncedText: String {
        guard let last = state?.lastSyncedAt else { return "Never synced" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Synced \(formatter.localizedString(for: last, relativeTo: Date()))"
    }
}

#Preview {
    List {
        SyncTypeRow(type: .steps, state: SyncState(dataType: "steps", lastSyncedAt: Date(), lastStatus: "ok", itemCount: 4213))
        SyncTypeRow(type: .weight, state: nil)
        SyncTypeRow(type: .sleep, state: SyncState(dataType: "sleep", lastStatus: "error", lastError: "Google 429: rate limited"))
    }
}
