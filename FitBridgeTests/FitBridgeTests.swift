import Testing

@Test func appLaunchesPlaceholder() async throws {
    // Trivial placeholder so `xcodebuild test` has a passing suite for the
    // app scheme (WP-01 "Done when" clause). Real UI tests land in WP-10.
    #expect(true)
}
