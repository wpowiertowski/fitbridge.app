// Page.swift
//
// WP-05 step 4 (implementation-plan.md): "`reconcile(type:since:until:pageToken:)`
// returns `Page(points:, nextPageToken:)`. `since/until` are the request
// window; the page token continues within that window (do not re-derive the
// window per page)." `GoogleHealthClient.reconcile`/`.dailyRollup` re-send the
// same `since`/`until` on every page of a single logical fetch -- see the
// "stable window" pagination test.

nonisolated public struct Page: Sendable, Equatable {
    public var points: [GoogleDataPoint]
    public var nextPageToken: String?

    public init(points: [GoogleDataPoint], nextPageToken: String?) {
        self.points = points
        self.nextPageToken = nextPageToken
    }
}
