// ActivityRow.swift
//
// WP-12b (implementation-plan.md) step 5: one consolidated activity entry
// (ActivitiesModels.swift's `ActivityEntry`). Follows `SyncTypeRow`/
// `SyncLogRow`'s "dumb row, smart container" split and the "identifiers
// only on leaves" accessibility-ID rule those files established.

import SwiftUI

struct ActivityRow: View {
    let entry: ActivityEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(.tint)
                    .accessibilityIdentifier("activities.row.\(entry.id).icon")
                Text(entry.title)
                    .font(.headline)
                    .accessibilityIdentifier("activities.row.\(entry.id).title")
                Spacer()
                Text(entry.start, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(durationText) \u{00B7} \(entry.sourceLabel)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("activities.row.\(entry.id).detail")
            // D13.2: the linked Fitbit session's fields, inline as a
            // supplement under the watch workout -- never a second entry.
            if let supplement = entry.supplement {
                Text("+ \(supplementText(supplement))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("activities.row.\(entry.id).supplement")
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch entry.kind {
        case .workout(let workout):
            return workout.isAppleWatch ? "applewatch" : "figure.run"
        case .unlinkedFitbitSession:
            return "figure.run"
        }
    }

    private var durationText: String {
        let minutes = max(1, Int(entry.duration / 60))
        return "\(minutes) min"
    }

    private func supplementText(_ supplement: FitbitActivitySupplement) -> String {
        var parts: [String] = []
        if let distance = supplement.distanceMeters {
            parts.append(String(format: "%.1f km", distance / 1000))
        }
        if let energy = supplement.energyKilocalories {
            parts.append("\(Int(energy)) kcal")
        }
        parts.append(supplement.source)
        return parts.joined(separator: " \u{00B7} ")
    }
}
