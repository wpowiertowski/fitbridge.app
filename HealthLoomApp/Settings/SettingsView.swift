// SettingsView.swift
//
// WP-17 (implementation-plan.md): "Settings screen: per-type sync toggles
// (grouped by Google scope); enabling a type whose scope isn't granted
// triggers `ensure(scopes:)` incremental consent; disabling stops sync but
// keeps written data (deletion is WP-35's wipe)."
//
// Grouping: one `List` section per `GoogleDataType.Scope`
// (`.activityAndFitness`/`.healthMetrics`/`.sleep`/`.nutrition`/`.ecg`/`.irn`,
// CoreModel), over `SyncPreferences.syncableTypes` -- every non-`.skip`
// `GoogleDataType`, per that file's header note.
//
// **`ensure(scopes:)` already existed** -- this WP did not need to add
// anything to `GoogleAuthManager` (GoogleHealthClient, WP-04): read
// `GoogleAuthManager+Consent.swift` before assuming otherwise, and found
// `public func ensure(scopes: [GoogleDataType.Scope], presentationContextProvider:)
// async throws(GoogleAuthError) -> Bool`, which already computes the missing
// subset via `missingHealthScopes(from:)` and only presents consent for that
// subset (returns `true`/no UI if nothing was missing) -- exactly WP-17's
// "incremental consent" ask, word for word. `IncrementalConsentPresenter`
// (this folder) supplies the one thing `ensure` needs beyond scopes: an
// `ASWebAuthenticationPresentationContextProviding`.
//
// Toggling a type OFF does not touch HealthKit/`LocalSample` data already
// written (WP-35's wipe flow is separate, out of scope here) -- it only
// updates `SyncPreferences`, which callers of `syncAll(types:)` are expected
// to consult (see that file's header note on the two known call sites).
//
// WP-18 (implementation-plan.md) addendum: one additive `Section` below adds
// a `NavigationLink` to the new "Sync Log" viewer (`HealthLoomApp/Diagnostics/
// SyncLogView.swift`) -- this is the one small nav-link edit that WP's scope
// fence explicitly allows in this file; nothing above this comment block
// changed.

import CoreModel
import GoogleHealthClient
import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var preferences = SyncPreferences()
    private let consentPresenter = IncrementalConsentPresenter()

    @State private var pendingTypes: Set<GoogleDataType> = []
    @State private var scopeErrors: [GoogleDataType: String] = [:]

    private var groupedByScope: [(scope: GoogleDataType.Scope, types: [GoogleDataType])] {
        let grouped = Dictionary(grouping: SyncPreferences.syncableTypes, by: \.scope)
        return GoogleDataType.Scope.allCases
            .compactMap { scope in grouped[scope].map { (scope, $0) } }
    }

    var body: some View {
        List {
            Section {
                Text("Turn off a type to stop syncing it. Data already written to Apple Health or saved on-device is not deleted -- that's a separate step in a future release.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("settings.disclaimer")

            Section {
                NavigationLink("Sync Log", destination: SyncLogView())
                    .accessibilityIdentifier("settings.synclog.link")
            }

            ForEach(groupedByScope, id: \.scope) { group in
                Section(scopeDisplayName(group.scope)) {
                    ForEach(group.types, id: \.self) { type in
                        row(for: type)
                    }
                }
            }
        }
        .navigationTitle("Sync Settings")
    }

    private func row(for type: GoogleDataType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: Binding(
                get: { preferences.isEnabled(type) },
                set: { toggle(type: type, isOn: $0) }
            )) {
                HStack(spacing: 6) {
                    Text(displayName(type))
                    if pendingTypes.contains(type) {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
            }
            .accessibilityIdentifier("settings.toggle.\(type.rawValue)")

            if let message = scopeErrors[type] {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("settings.error.\(type.rawValue)")
            }
        }
        .padding(.vertical, 2)
    }

    private func toggle(type: GoogleDataType, isOn: Bool) {
        preferences.setEnabled(isOn, for: type)
        scopeErrors[type] = nil
        guard isOn else { return }

        let scopes = Array(preferences.requiredScopes(toEnable: type))
        pendingTypes.insert(type)
        Task {
            defer { pendingTypes.remove(type) }
            do {
                try await appEnvironment.googleAuthManager.ensure(
                    scopes: scopes,
                    presentationContextProvider: consentPresenter
                )
            } catch {
                scopeErrors[type] = "Couldn't confirm Google access for \(displayName(type)): \(error)"
            }
        }
    }

    private func displayName(_ type: GoogleDataType) -> String {
        type.rawValue
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private func scopeDisplayName(_ scope: GoogleDataType.Scope) -> String {
        switch scope {
        case .activityAndFitness: return "Activity & Fitness"
        case .healthMetrics: return "Health Metrics"
        case .sleep: return "Sleep"
        case .nutrition: return "Nutrition"
        case .ecg: return "ECG"
        case .irn: return "Irregular Rhythm Notifications"
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppEnvironment())
}
