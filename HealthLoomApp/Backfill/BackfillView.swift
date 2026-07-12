// BackfillView.swift
//
// WP-15 (implementation-plan.md) step 3: "UI: progress per type ('Mar 2026
// … done' style), pause/resume controls, and a horizon picker that can
// extend an already-completed backfill (extending re-opens the walk)."
//
// Talks to `AppEnvironment.backfillCoordinator` (SyncKit's `actor
// BackfillCoordinator`, `Packages/SyncKit/Sources/SyncKit/Backfill/
// BackfillCoordinator.swift`) exclusively through its `async` public API --
// every actor call in this file is wrapped in a `Task { ... }` from a
// synchronous SwiftUI action, or awaited directly inside the one `.task`
// modifier below, matching this app target's existing `DashboardView
// .syncNow()` pattern (`Dashboard/DashboardView.swift`) for calling into an
// actor from a plain `Button` action.
//
// Deliberately **polls** `backfillCoordinator.statuses()` on a plain timer
// loop (`.task`'s `while !Task.isCancelled` below) rather than trying to
// observe `SyncState` reactively via `@Query`: `BackfillTypeStatus` also
// folds in `BackfillCoordinator`'s in-actor `horizon`/`isPausedNow` state
// and `BackfillHorizonRecordStore`'s completed-horizon bookkeeping -- neither
// of which is SwiftData-backed (`Backfill/BackfillTypes.swift`'s
// `BackfillHorizonRecordStore` doc comment explains why, a CoreModel-scope
// gap this WP papers over with a small side-store) -- so a `@Query` alone
// could show a fresh `backfillCursor` but a stale "is this actually done for
// the *current* horizon" answer. Polling `coordinator.statuses()` (which
// itself reads `SyncState` fresh every call, `BackfillCoordinator.status(for:)`'s
// doc comment) keeps exactly one source of truth for this whole screen.

import CoreModel
import SwiftUI
import SyncKit

struct BackfillView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var statuses: [BackfillTypeStatus] = []
    @State private var isPaused = false
    @State private var horizon: BackfillHorizon = .defaultHorizon

    var body: some View {
        List {
            Section {
                horizonPicker
                pauseResumeButton
            }
            Section("Backfill Progress") {
                ForEach(statuses, id: \.dataType) { status in
                    BackfillTypeRow(status: status)
                }
            }
        }
        .navigationTitle("Historical Backfill")
        .task {
            await appEnvironment.backfillCoordinator.start()
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                await refresh()
            }
        }
    }

    private var horizonPicker: some View {
        Picker(
            "Import history back to",
            selection: Binding(get: { horizon }, set: { changeHorizon(to: $0) })
        ) {
            Text("30 days").tag(BackfillHorizon.days30)
            Text("90 days").tag(BackfillHorizon.days90)
            Text("1 year").tag(BackfillHorizon.year1)
            Text("All available history").tag(BackfillHorizon.all)
        }
        .accessibilityIdentifier("backfill.horizonPicker")
    }

    private var pauseResumeButton: some View {
        Button {
            togglePause()
        } label: {
            Label(
                isPaused ? "Resume Backfill" : "Pause Backfill",
                systemImage: isPaused ? "play.fill" : "pause.fill"
            )
        }
        .accessibilityIdentifier("backfill.pauseResumeButton")
    }

    private func changeHorizon(to newHorizon: BackfillHorizon) {
        horizon = newHorizon
        Task {
            let coordinator = appEnvironment.backfillCoordinator
            await coordinator.setHorizon(newHorizon)
            // A previously-finished walk's background loop has already
            // exited (`BackfillCoordinator.runLoop()`'s `isFullyDone()`
            // check) -- extending the horizon needs `start()` called again
            // to reopen it; `start()` itself is a no-op if the loop is
            // already running, so this is always safe to call.
            await coordinator.start()
            await refresh()
        }
    }

    private func togglePause() {
        Task {
            let coordinator = appEnvironment.backfillCoordinator
            if isPaused {
                await coordinator.resume()
            } else {
                await coordinator.pause()
            }
            await refresh()
        }
    }

    private func refresh() async {
        let coordinator = appEnvironment.backfillCoordinator
        statuses = await coordinator.statuses()
        isPaused = await coordinator.isPausedNow
        horizon = await coordinator.currentHorizon()
    }
}

#Preview {
    NavigationStack {
        BackfillView()
    }
    .environment(AppEnvironment())
}
