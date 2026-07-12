// StubGoogleReconcileClient.swift
//
// WP-10 (implementation-plan.md): used only when the app launches with
// `-UITestStubGoogle` (see LaunchConfiguration.swift) so onboarding's "first
// sync" step (FirstSyncView -> SyncEngine.syncAll) never makes a real
// network call to Google -- it returns an immediately-successful, empty
// page for every type. `SyncEngine` (Packages/SyncKit/Sources/SyncKit/
// SyncEngine/SyncEngine.swift) treats an empty page as a fully-successful
// zero-item run (cursor still advances, `lastStatus` still becomes "ok"),
// so the dashboard the onboarding flow lands on shows real "ok" states, not
// fabricated ones.
//
// Real API discovered here (progress.md's WP-09 entry, `SyncEngineTypes
// .swift`): `GoogleReconcileClient`'s one requirement is
// `nonisolated func reconcile(type:since:until:pageToken:) async
// throws(GoogleHealthClientError) -> Page` -- matches the real
// `GoogleHealthClient`'s own signature exactly (SyncKit conforms it via
// `GoogleHealthClient+SyncEngine.swift` with zero additional code), so this
// stub only has to match that same shape.

import CoreModel
import Foundation
import GoogleHealthClient
import SyncKit

nonisolated struct StubGoogleReconcileClient: GoogleReconcileClient {
    nonisolated func reconcile(
        type: GoogleDataType,
        since: Date,
        until: Date,
        pageToken: String?
    ) async throws(GoogleHealthClientError) -> Page {
        Page(points: [], nextPageToken: nil)
    }
}
