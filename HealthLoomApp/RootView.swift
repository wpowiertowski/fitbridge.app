// RootView.swift
//
// WP-10 (implementation-plan.md): the app's root router -- onboarding until
// completed, dashboard after. Replaces WP-01's placeholder `ContentView`.
//
// Initial route is decided once at construction (`startOnDashboard`, passed
// down from `HealthLoomApp` reading `AppEnvironment.launchConfiguration`) so
// `-UITestSeedData` UI test runs land directly on the dashboard without
// flashing onboarding first (implementation-plan.md WP-10's "Tests" line:
// "dashboard renders per-type states from a seeded in-memory container").

import SwiftUI

struct RootView: View {
    @State private var isOnboarded: Bool

    init(startOnDashboard: Bool) {
        _isOnboarded = State(initialValue: startOnDashboard)
    }

    var body: some View {
        if isOnboarded {
            DashboardView()
        } else {
            OnboardingFlowView(onFinished: { isOnboarded = true })
        }
    }
}

#Preview {
    RootView(startOnDashboard: false)
        .environment(AppEnvironment())
}
