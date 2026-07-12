// LaunchConfiguration.swift
//
// WP-10 (implementation-plan.md): launch-argument-driven configuration
// selecting which dependencies `AppEnvironment` wires up. Two UI-testing
// modes (test-plan.md §5's "App launches with arguments selecting stub
// layers"):
//
//   -UITestStubGoogle   Onboarding happy-path test. Starts at Welcome; Google
//                       consent and the first sync's reconcile client are
//                       both stubbed (`GoogleConsentCoordinator.swift`,
//                       `StubGoogleReconcileClient.swift`) so no real network
//                       call is ever made. HealthKit permission is *not*
//                       stubbed -- the real `HealthKitAuth.requestWrite`
//                       runs, and the UI test drives the system permission
//                       sheet, per implementation-plan.md WP-10's own
//                       framing ("stubbed auth" refers to Google, the one
//                       piece that would otherwise require live credentials).
//
//   -UITestSeedData     Dashboard-states test. Skips onboarding entirely and
//                       seeds an in-memory `ModelContainer` with `SyncState`
//                       rows spanning ok/error/idle before the first frame
//                       renders (`AppEnvironment.seedDashboardFixtures`).
//
// Both modes force an in-memory `ModelContainer` (`CoreModel.makeContainer
// (inMemory:)`) so UI test runs never touch the real on-disk store.

import Foundation

struct LaunchConfiguration: Sendable {
    var stubGoogle: Bool
    var seedDashboardData: Bool
    var useInMemoryContainer: Bool
    var initialRouteIsDashboard: Bool

    static var current: LaunchConfiguration {
        let arguments = ProcessInfo.processInfo.arguments
        let stubGoogle = arguments.contains("-UITestStubGoogle")
        let seedDashboardData = arguments.contains("-UITestSeedData")
        let isUITest = stubGoogle || seedDashboardData
        return LaunchConfiguration(
            stubGoogle: stubGoogle,
            seedDashboardData: seedDashboardData,
            useInMemoryContainer: isUITest,
            initialRouteIsDashboard: seedDashboardData
        )
    }
}
