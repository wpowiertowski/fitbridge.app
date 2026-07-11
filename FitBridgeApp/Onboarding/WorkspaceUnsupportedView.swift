// WorkspaceUnsupportedView.swift
//
// WP-10 (implementation-plan.md step 1) / architecture.md §6: "Workspace
// Google account -- Detected post-consent; clear 'personal accounts only'
// screen; sign-out." `GoogleAuthManager.completeConsent` already clears the
// stored tokens itself before throwing `.workspaceAccountUnsupported`
// (progress.md's WP-04 entry), so this screen only needs to explain the
// state and offer a retry -- there is nothing left here to sign out of.

import SwiftUI

struct WorkspaceUnsupportedView: View {
    var onTryDifferentAccount: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Personal Accounts Only")
                .font(.title.bold())
            Text("The account you signed in with is a Google Workspace (work or school) account. Google's Health API only supports personal Google accounts. Please sign in with a personal account instead.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button("Try a Different Account", action: onTryDifferentAccount)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboarding.workspace.retry")
            Spacer().frame(height: 16)
        }
        .padding()
        // No container-level identifier -- see WelcomeView.swift's note: it
        // would override the more specific `onboarding.workspace.retry`
        // identifier set on the button above.
    }
}

#Preview {
    WorkspaceUnsupportedView(onTryDifferentAccount: {})
}
