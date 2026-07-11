// SyncLogRow.swift
//
// WP-18 (implementation-plan.md): one row of the Sync Log viewer --
// timestamp, type, status icon, item count, and (only when present) the
// already-redacted error text. `SyncLogView` never talks to `SyncLogStore`
// directly from this view, matching `SyncTypeRow`/`BackfillTypeRow`'s own
// "dumb row, smart container" split (`Dashboard/SyncTypeRow.swift`,
// `Backfill/BackfillTypeRow.swift`).
//
// Same "identifiers only on leaves" rule those files' own progress.md notes
// established (a container-level `.accessibilityIdentifier` was observed to
// clobber its children's more specific ones) -- every sub-value below
// carries its own `synclog.row.<id>.*` identifier, a namespace distinct from
// `dashboard.row.*`/`backfill.row.*`.

import CoreModel
import SwiftUI
import SyncKit

struct SyncLogRow: View {
    let entry: SyncLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .accessibilityIdentifier("synclog.row.\(entry.id).statusIcon")
                Text(displayName)
                    .font(.headline)
                    .accessibilityIdentifier("synclog.row.\(entry.id).name")
                Spacer()
                Text(entry.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("synclog.row.\(entry.id).timestamp")
            }
            Text("\(entry.itemCount) item\(entry.itemCount == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("synclog.row.\(entry.id).count")
            if let errorMessage = entry.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("synclog.row.\(entry.id).error")
            }
        }
        .padding(.vertical, 4)
    }

    private var displayName: String {
        entry.dataType.rawValue
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private var statusIcon: String {
        switch entry.status {
        case .ok: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch entry.status {
        case .ok: return .green
        case .error: return .red
        }
    }
}

#Preview {
    List {
        SyncLogRow(entry: SyncLogEntry(timestamp: Date().addingTimeInterval(-120), dataType: .steps, status: .ok, itemCount: 214))
        SyncLogRow(entry: SyncLogEntry(
            timestamp: Date().addingTimeInterval(-3600),
            dataType: .heartRate,
            status: .error,
            itemCount: 0,
            errorMessage: "The request timed out."
        ))
    }
}
