// DashboardView.swift
//
// WP-10 (implementation-plan.md step 2): "Dashboard list: 4 types x
// (last-sync time, item count, status icon, error text) driven by
// SyncState; a 'Sync now' button calling syncAll; a data-freshness header
// ('data reaches Google ~15 min after device sync' -- set expectations,
// D-context §1)."
//
// Driven by `@Query` over CoreModel's `SyncState` (SwiftData), reading from
// whichever `ModelContainer` `FitBridgeApp` put in the environment via
// `.modelContainer(_:)` -- production, or an in-memory one seeded by
// `AppEnvironment.seedDashboardFixtures` under `-UITestSeedData`. "Sync now"
// calls the exact same `SyncEngine.syncAll(types:)` onboarding's
// `FirstSyncView` calls; `@Query` picks up whatever that run persists to
// `SyncState` without this view re-fetching manually.
//
// WP-14 (implementation-plan.md): a second `@Query`, over CoreModel's
// `LocalSample`, drives a second section for the four `.localOnly`-writability
// types (architecture.md D2) -- these don't have a `SyncState` row of their
// own to key off of (they never touch HealthKit), so they're grouped
// client-side by `LocalSample.dataType` instead and rendered via
// `LocalOnlyTypeRow`, not `SyncTypeRow`. Deliberately **not** wired into
// `syncNow()`'s `syncAll(types:)` call below: `GoogleConsentView`'s OAuth
// scope request (`AppEnvironment.p0Types.map(\.scope)`) only covers P0's
// scopes, and ECG/IRN sit behind their own separate `.ecg`/`.irn` Google
// scopes (`GoogleDataType.scope`) -- syncing them without first requesting
// those scopes would 403 against a real (non-stubbed) Google account. Widening
// onboarding consent to request those scopes is out of this WP's stated file
// scope (`GoogleConsentView.swift` isn't listed); flagged in progress.md as
// follow-up for whichever WP does that. Until then, these rows populate from
// `-UITestSeedData`'s seeded fixtures (tests) or from a future WP's backfill/
// broader-sync wiring (production) -- never from this screen's own button.

import CoreModel
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Query(sort: \SyncState.dataType) private var syncStates: [SyncState]
    @Query(sort: \LocalSample.dataType) private var localSamples: [LocalSample]
    @State private var isSyncing = false

    private var orderedRows: [(GoogleDataType, SyncState?)] {
        AppEnvironment.p0Types.map { type in
            (type, syncStates.first { $0.dataType == type.rawValue })
        }
    }

    private var localOnlyRows: [(GoogleDataType, [LocalSample])] {
        AppEnvironment.p1LocalOnlyTypes.map { type in
            (type, localSamples.filter { $0.dataType == type.rawValue })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    freshnessHeader
                }
                Section("Your Data") {
                    ForEach(orderedRows, id: \.0) { type, state in
                        SyncTypeRow(type: type, state: state)
                    }
                }
                Section("Not in Apple Health") {
                    ForEach(localOnlyRows, id: \.0) { type, samples in
                        LocalOnlyTypeRow(type: type, samples: samples)
                    }
                }
                // WP-15 coordination point (flagged per the handoff brief,
                // and anticipated by WP-17's own note above): the smallest
                // possible addition to this pre-existing file to make the
                // new Backfill screen (`Backfill/BackfillView.swift`)
                // reachable -- one row, placed after the existing sections
                // rather than touching the `.toolbar` WP-17 also edited.
                Section { NavigationLink("Historical Backfill", destination: BackfillView()) }
            }
            .navigationTitle("FitBridge")
            .toolbar {
                // WP-17: nav link to the new Settings screen (per-type sync
                // toggles). Placed at `.topBarLeading` so it doesn't compete
                // with the existing `.primaryAction` "Sync Now" button below;
                // flagged in progress.md as a coordination point since WP-15
                // may independently want a Dashboard nav link of its own (to
                // a backfill screen) -- this item only adds `SettingsView`,
                // nothing else on this toolbar was touched.
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("dashboard.settings")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        syncNow()
                    } label: {
                        if isSyncing {
                            ProgressView()
                        } else {
                            Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(isSyncing)
                    .accessibilityIdentifier("dashboard.syncNow")
                }
            }
        }
    }

    private var freshnessHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("About data freshness", systemImage: "clock")
                .font(.subheadline.bold())
            Text("Your Fitbit or Pixel Watch reaches Google roughly every 15 minutes while the Google Health app is open. FitBridge then pulls from Google each time you sync below -- this isn't a live feed.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("dashboard.freshnessHeader")
    }

    private func syncNow() {
        isSyncing = true
        // WP-17: consult `SyncPreferences` before calling `syncAll` so a
        // type the user disabled in Settings is excluded from this manual
        // sync path -- disabling stops future syncing but does not delete
        // anything already written (WP-35's wipe flow, out of scope here).
        // A fresh `SyncPreferences()` is constructed here (not held in
        // `@State`) specifically so it always reflects whatever was most
        // recently written in `SettingsView`, even though that screen holds
        // its own separate instance -- see `SyncPreferences.swift`'s header
        // note, which also flags this as the pattern WP-16's background
        // handler should mirror for its own due-types list.
        let typesToSync = SyncPreferences().filteredForSync(AppEnvironment.p0Types)
        Task {
            _ = await appEnvironment.syncEngine.syncAll(types: typesToSync)
            isSyncing = false
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppEnvironment())
}
