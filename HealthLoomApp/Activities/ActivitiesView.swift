// ActivitiesView.swift
//
// WP-12b (implementation-plan.md) step 5 / architecture.md D13.2: the
// consolidated Activities list -- one entry per activity, chronological,
// grouped by day. Watch workout primary (duration, source); the linked
// Fitbit session's supplementary fields inline ("+ 8.0 km · 520 kcal ·
// Fitbit Air"); Fitbit-only activities (no watch) as full entries.
//
// Data flow: `LocalSample` `.exercise` rows via `@Query` (reactive, exactly
// like `DashboardView`'s own `LocalSample` query); HealthKit workouts via
// `ActivitiesProvider` on `.task`/`.refreshable` (workouts aren't SwiftData
// -- there is nothing for `@Query` to observe; same "poll the non-SwiftData
// source" posture `BackfillView`/`SyncLogView` already use for their
// actor-backed state).

import CoreModel
import SwiftData
import SwiftUI

struct ActivitiesView: View {
    @Query(sort: \LocalSample.start, order: .reverse) private var localSamples: [LocalSample]
    @State private var workouts: [WorkoutSummary] = []
    @State private var hasLoaded = false
    private let provider = ActivitiesProvider()

    private var entries: [ActivityEntry] {
        let supplements = localSamples
            .filter { $0.dataType == GoogleDataType.exercise.rawValue }
            .map(FitbitActivitySupplement.init(sample:))
        return ActivityConsolidator.consolidate(workouts: workouts, supplements: supplements)
    }

    var body: some View {
        List {
            if entries.isEmpty && hasLoaded {
                Section {
                    Text("No activities yet. Workouts recorded by your Apple Watch and activities synced from your Fitbit will appear here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("activities.empty")
                }
            } else {
                ForEach(ActivityConsolidator.groupedByDay(entries), id: \.day) { group in
                    Section(group.day.formatted(date: .abbreviated, time: .omitted)) {
                        ForEach(group.entries) { entry in
                            ActivityRow(entry: entry)
                        }
                    }
                }
            }
        }
        .navigationTitle("Activities")
        .task {
            workouts = await provider.recentWorkouts()
            hasLoaded = true
        }
        .refreshable {
            workouts = await provider.recentWorkouts()
        }
    }
}

#Preview {
    NavigationStack {
        ActivitiesView()
    }
    .environment(AppEnvironment())
}
