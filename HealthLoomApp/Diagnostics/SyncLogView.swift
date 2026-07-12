// SyncLogView.swift
//
// WP-18 (implementation-plan.md): Settings -> "Sync log" viewer -- "list of
// recent runs (timestamp, type, status, count, error text), with an
// export-as-text button (share sheet) producing a plain-text dump suitable
// for user support -- counts and types only, never values."
//
// Talks to `AppEnvironment.syncLogStore` (SyncKit's `actor SyncLogStore`,
// `Packages/SyncKit/Sources/SyncKit/Diagnostics/SyncLogStore.swift`)
// exclusively through its `async` public API, matching this app target's
// established "actor-backed state -> poll on a `.task` loop" convention
// (`BackfillView.swift`, WP-15) rather than inventing a different pattern
// for this WP's own actor-backed store -- `SyncLogStore` isn't
// `@Observable`/SwiftData-backed (see that file's own header for why), so
// there is nothing here to `@Query`.
//
// Export text is produced by SyncKit's own `SyncLogTextExporter` (pure,
// package-level golden-tested) -- this view is a thin, untestable-by-nature
// SwiftUI wrapper around one already-verified function, exactly the split
// `SyncLogTextExporter.swift`'s own header describes.

import CoreModel
import SwiftUI
import SyncKit

struct SyncLogView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var entries: [SyncLogEntry] = []
    @State private var hasLoadedOnce = false

    private var exportText: String {
        SyncLogTextExporter.export(entries)
    }

    var body: some View {
        List {
            Section {
                Text("Recent sync activity, most recent first. Only counts, types, and timestamps are kept here -- never your health data or account credentials.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("synclog.disclaimer")

            if entries.isEmpty {
                Section {
                    Text(hasLoadedOnce ? "No sync runs recorded yet." : "Loading…")
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("synclog.empty")
            } else {
                Section("Recent Runs") {
                    ForEach(entries) { entry in
                        SyncLogRow(entry: entry)
                    }
                }
            }
        }
        .navigationTitle("Sync Log")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: exportText, preview: SharePreview("HealthLoom Sync Log")) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("synclog.export")
                .disabled(entries.isEmpty)
            }
        }
        .task {
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await refresh()
            }
        }
        .refreshable { await refresh() }
    }

    private func refresh() async {
        let store = appEnvironment.syncLogStore
        // `SyncLogStore.recentEntries()` returns oldest-first (that actor's
        // own doc comment); this viewer displays newest-first, matching
        // `SyncLogTextExporter`'s own ordering choice for the export text.
        entries = Array(await store.recentEntries().reversed())
        hasLoadedOnce = true
    }
}

#Preview {
    NavigationStack {
        SyncLogView()
    }
    .environment(AppEnvironment())
}
