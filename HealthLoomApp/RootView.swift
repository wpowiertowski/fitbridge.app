// RootView.swift
//
// WP-10 (implementation-plan.md): the app's root router -- onboarding until
// completed, the main app after. Replaces WP-01's placeholder `ContentView`.
//
// WP-33: post-onboarding now routes to `HomeView` (the Yacht club tab
// shell, Today/HomeView.swift) instead of bare `DashboardView`. The
// pre-existing `startOnDashboard` launch flag (`-UITestSeedData`, see
// LaunchConfiguration.swift) keeps both of its jobs -- skip onboarding
// *and* land on the sync dashboard -- by selecting the Data tab as the
// initial tab, so `DashboardUITests`' seeded launches still find
// `dashboard.syncNow` immediately, no test churn. A normal launch lands
// on Today.

import SwiftUI

struct RootView: View {
    @State private var isOnboarded: Bool
    private let startOnDataTab: Bool

    init(startOnDashboard: Bool) {
        _isOnboarded = State(initialValue: startOnDashboard)
        self.startOnDataTab = startOnDashboard
    }

    var body: some View {
        if isOnboarded {
            HomeView(initialTab: startOnDataTab ? .data : .today)
        } else {
            OnboardingFlowView(onFinished: { isOnboarded = true })
        }
    }
}

#Preview {
    RootView(startOnDashboard: false)
        .environment(AppEnvironment())
}
