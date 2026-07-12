// BackfillTypeRow.swift
//
// WP-15 (implementation-plan.md) step 3: "progress per type ('Mar 2026 …
// done' style)." One row per type `BackfillView` walks, driven entirely by
// a `BackfillTypeStatus` snapshot (SyncKit, `Backfill/BackfillTypes.swift`)
// -- this view never talks to `BackfillCoordinator` directly, matching
// `SyncTypeRow`/`LocalOnlyTypeRow`'s own "dumb row, smart container" split
// (`Dashboard/SyncTypeRow.swift`, `Dashboard/LocalOnlyTypeRow.swift`).
//
// Same "identifiers only on leaves" rule those two files' own progress.md
// notes established (a container-level `.accessibilityIdentifier` was
// observed, via a real `xcodebuild test` accessibility snapshot, to
// clobber its children's more specific ones) -- every sub-value below
// carries its own `backfill.row.<type>.*` identifier, a namespace distinct
// from both `dashboard.row.*` and `dashboard.localRow.*`.

import CoreModel
import SwiftUI
import SyncKit

struct BackfillTypeRow: View {
    let status: BackfillTypeStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .accessibilityIdentifier("backfill.row.\(status.dataType.rawValue).statusIcon")
                Text(displayName)
                    .font(.headline)
                    .accessibilityIdentifier("backfill.row.\(status.dataType.rawValue).name")
                Spacer()
            }
            Text(progressText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("backfill.row.\(status.dataType.rawValue).progress")
            if let lastError = status.lastError {
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("backfill.row.\(status.dataType.rawValue).error")
            }
        }
        .padding(.vertical, 4)
    }

    private var displayName: String {
        switch status.dataType {
        case .steps: return "Steps"
        case .heartRate: return "Heart Rate"
        case .weight: return "Weight"
        case .sleep: return "Sleep"
        case .distance: return "Distance"
        case .floors: return "Floors"
        case .activeEnergyBurned: return "Active Energy"
        case .dailyRestingHeartRate: return "Resting Heart Rate"
        case .exercise: return "Exercise"
        case .nutritionLog: return "Nutrition"
        default: return status.dataType.rawValue
        }
    }

    private var statusIcon: String {
        if status.lastError != nil { return "exclamationmark.triangle.fill" }
        if status.isComplete { return "checkmark.circle.fill" }
        if status.reachedDate == nil { return "circle.dashed" }
        return "arrow.down.circle"
    }

    private var statusColor: Color {
        if status.lastError != nil { return .red }
        if status.isComplete { return .green }
        return .secondary
    }

    /// WP-15 step 3's own illustrative style: "Mar 2026 … done" once the
    /// horizon is reached; "Reached Mar 2026" mid-walk; "Not started yet"
    /// before the very first chunk.
    private var progressText: String {
        guard let reached = status.reachedDate else { return "Not started yet" }
        let label = Self.monthYearFormatter.string(from: reached)
        return status.isComplete ? "\(label) … done" : "Reached \(label)"
    }

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM yyyy")
        return formatter
    }()
}

#Preview {
    List {
        BackfillTypeRow(status: BackfillTypeStatus(
            dataType: .steps,
            reachedDate: Date().addingTimeInterval(-200 * 24 * 3600),
            horizonDate: Date().addingTimeInterval(-365 * 24 * 3600),
            isComplete: false,
            lastError: nil
        ))
        BackfillTypeRow(status: BackfillTypeStatus(
            dataType: .weight,
            reachedDate: Date().addingTimeInterval(-90 * 24 * 3600),
            horizonDate: Date().addingTimeInterval(-90 * 24 * 3600),
            isComplete: true,
            lastError: nil
        ))
        BackfillTypeRow(status: BackfillTypeStatus(
            dataType: .sleep,
            reachedDate: nil,
            horizonDate: Date().addingTimeInterval(-90 * 24 * 3600),
            isComplete: false,
            lastError: nil
        ))
        BackfillTypeRow(status: BackfillTypeStatus(
            dataType: .heartRate,
            reachedDate: Date().addingTimeInterval(-30 * 24 * 3600),
            horizonDate: Date().addingTimeInterval(-365 * 24 * 3600),
            isComplete: false,
            lastError: "Google 429: rate limited - will retry automatically"
        ))
    }
}
