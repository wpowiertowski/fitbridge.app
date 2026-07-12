// GoogleConsentView.swift
//
// WP-10 (implementation-plan.md): onboarding step 3 of 4 -- calls
// `AppEnvironment.consentCoordinator.beginConsent(scopes:)`
// (`GoogleConsentCoordinator.swift`), which is either the real
// `LiveGoogleConsentCoordinator` (presents `ASWebAuthenticationSession` via
// `GoogleAuthManager.beginConsent`) or, under `-UITestStubGoogle`, the
// hermetic `StubGoogleConsentCoordinator` -- this view has no idea which one
// it's talking to, by design.
//
// Scopes requested: the union of every P0 type's `GoogleDataType.Scope`
// (steps/heartRate -> activityAndFitness/healthMetrics, weight ->
// healthMetrics, sleep -> sleep), matching `HealthKitAuth.p0WriteTypes`'s
// data-type set rather than hand-duplicating it.

import CoreModel
import SwiftUI

struct GoogleConsentView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    var onWorkspaceUnsupported: () -> Void
    var onSuccess: () -> Void

    @State private var isConsenting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "person.badge.key")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Connect Google")
                .font(.title.bold())
            Text("Sign in with the personal Google account linked to your Fitbit or Pixel Watch. Google Workspace (work or school) accounts aren't supported.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .accessibilityIdentifier("onboarding.google.error")
            }
            Spacer()
            Button {
                beginConsent()
            } label: {
                if isConsenting {
                    ProgressView()
                } else {
                    Text("Sign in with Google")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isConsenting)
            .accessibilityIdentifier("onboarding.google.signIn")
            Spacer().frame(height: 16)
        }
        .padding()
        // No container-level identifier -- see WelcomeView.swift's note:
        // it would override the more specific `onboarding.google.signIn`/
        // `.error` identifiers set on the children above.
    }

    private func beginConsent() {
        isConsenting = true
        errorMessage = nil
        let scopes = Array(Set(AppEnvironment.p0Types.map(\.scope)))
        Task {
            let result = await appEnvironment.consentCoordinator.beginConsent(scopes: scopes)
            isConsenting = false
            switch result {
            case .success:
                onSuccess()
            case .workspaceUnsupported:
                onWorkspaceUnsupported()
            case .cancelled:
                break
            case .failure(let message):
                errorMessage = message
            }
        }
    }
}

#Preview {
    GoogleConsentView(onWorkspaceUnsupported: {}, onSuccess: {})
        .environment(AppEnvironment())
}
