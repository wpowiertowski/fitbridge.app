// OnboardingFlowView.swift
//
// WP-10 (implementation-plan.md step 1): "welcome -> HealthKit permission ->
// Google consent -> first sync. Include the Workspace-unsupported and
// HK-unavailable states." Plain, explicit state machine -- no navigation
// stack needed since onboarding is strictly linear except for two
// dead-end/retry branches (architecture.md §6).

import SwiftUI

enum OnboardingStep: Equatable {
    case welcome
    case healthKitPermission
    case healthKitUnavailable
    case googleConsent
    case workspaceUnsupported
    case firstSync
}

struct OnboardingFlowView: View {
    @State private var step: OnboardingStep = .welcome
    var onFinished: () -> Void

    var body: some View {
        Group {
            switch step {
            case .welcome:
                WelcomeView(onContinue: { step = .healthKitPermission })
            case .healthKitPermission:
                HealthKitPermissionView(
                    onUnavailable: { step = .healthKitUnavailable },
                    onGranted: { step = .googleConsent }
                )
            case .healthKitUnavailable:
                HealthKitUnavailableView()
            case .googleConsent:
                GoogleConsentView(
                    onWorkspaceUnsupported: { step = .workspaceUnsupported },
                    onSuccess: { step = .firstSync }
                )
            case .workspaceUnsupported:
                WorkspaceUnsupportedView(onTryDifferentAccount: { step = .googleConsent })
            case .firstSync:
                FirstSyncView(onFinished: onFinished)
            }
        }
        .animation(.default, value: step)
    }
}
