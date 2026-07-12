// FirstSyncView.swift
//
// WP-10 (implementation-plan.md): onboarding step 4 of 4 -- calls
// `SyncEngine.syncAll(types:)` for the four P0 types once, on appearance,
// and reports the per-type outcome before handing off to the dashboard.
//
// Real API discovered here (progress.md's WP-09 entry, `SyncEngine.swift`):
// `syncAll(types:)` runs every type *sequentially* and never throws --
// `sync(type:)` always resolves to a `SyncOutcome` (`.ok`/`.error`), so a
// single failing type (e.g. Google 401/429 -- architecture.md §6) never
// blocks the other three or crashes onboarding; the failure just renders as
// an error line here, and again later as the dashboard's per-type error
// state (architecture.md's "errors render rather than vanish").

import SwiftUI
import SyncKit

struct FirstSyncView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    var onFinished: () -> Void

    @State private var isSyncing = true
    @State private var outcomes: [SyncOutcome] = []

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            if isSyncing {
                ProgressView()
                    .controlSize(.large)
                Text("Syncing your data from Google...")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("onboarding.firstSync.progress")
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("First Sync Complete")
                    .font(.title.bold())
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(outcomes, id: \.dataType) { outcome in
                        HStack {
                            Image(systemName: outcome.status == .ok ? "checkmark.circle" : "exclamationmark.triangle")
                                .foregroundStyle(outcome.status == .ok ? .green : .red)
                            // Plain `String` (not an inline string-interpolation
                            // literal): `Text(LocalizedStringKey)` applies
                            // locale-aware grouping to interpolated numbers
                            // by default (see SyncTypeRow.swift's note on the
                            // same gotcha, found via a real simulator run).
                            Text(outcome.dataType.rawValue + ": " + String(outcome.itemCount) + " item(s)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityIdentifier("onboarding.firstSync.summary")
                Button("Continue to Dashboard", action: onFinished)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("onboarding.firstSync.continue")
            }
            Spacer()
        }
        .padding()
        // No container-level identifier -- see WelcomeView.swift's note: it
        // would override the more specific `onboarding.firstSync.progress`/
        // `.summary`/`.continue` identifiers set on the children above.
        .task {
            outcomes = await appEnvironment.syncEngine.syncAll(types: AppEnvironment.p0Types)
            isSyncing = false
        }
    }
}
