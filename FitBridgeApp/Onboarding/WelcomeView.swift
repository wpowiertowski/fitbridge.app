// WelcomeView.swift
//
// WP-10 (implementation-plan.md): onboarding step 1 of 4. Plain SwiftUI --
// "Yacht club design lands in WP-33" (this WP's own scope note).

import SwiftUI

struct WelcomeView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "heart.text.square")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Welcome to FitBridge")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("FitBridge brings your Fitbit or Pixel Watch data -- steps, heart rate, weight, and sleep -- into Apple Health, so all your health data lives in one place.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button("Get Started", action: onContinue)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboarding.welcome.continue")
            Spacer().frame(height: 16)
        }
        .padding()
        // No container-level identifier here: applying
        // `.accessibilityIdentifier` on this VStack was observed (via a real
        // `xcodebuild test` run) to override/replace the more specific
        // `onboarding.welcome.continue` identifier set on the button below,
        // rather than coexisting with it -- see SyncTypeRow.swift's longer
        // note on the same behavior, first found there.
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
