// IncrementalConsentPresenter.swift
//
// WP-17 (implementation-plan.md): presentation-context seam for
// `GoogleAuthManager.ensure(scopes:presentationContextProvider:)`
// (GoogleHealthClient, WP-04 -- already built; see `SettingsView.swift`'s
// header note), called when this screen enables a data type whose Google
// scope isn't granted yet.
//
// This is a small, independent copy of `DI/GoogleConsentCoordinator.swift`'s
// `LiveGoogleConsentCoordinator.presentationAnchor(for:)` conformance rather
// than a shared dependency: that file is explicitly out of this WP's edit
// scope (read-only, per the handoff brief, since it's WP-10's onboarding
// seam), so duplicating this ~10-line adapter keeps this WP's diff
// additive-only instead of reopening a file another WP might also be
// touching. Behavior is intentionally identical.
import AuthenticationServices
import UIKit

@MainActor
final class IncrementalConsentPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    /// `ASWebAuthenticationSession` calls this on the main thread (Apple's
    /// documented behavior), but the protocol requirement itself is not
    /// actor-isolated -- with this app target's `SWIFT_DEFAULT_ACTOR_ISOLATION:
    /// MainActor` setting (project.yml), a plain implementation here would
    /// otherwise be implicitly MainActor-isolated and fail to satisfy the
    /// (non-isolated) protocol requirement. `MainActor.assumeIsolated` bridges
    /// the documented main-thread guarantee into this MainActor-isolated
    /// type without needing an `await` the synchronous protocol can't provide
    /// (same resolution `LiveGoogleConsentCoordinator` uses).
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if let keyWindow = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow }) {
                return keyWindow
            }
            guard let scene = scenes.first else {
                preconditionFailure("No UIWindowScene available to anchor ASWebAuthenticationSession")
            }
            return UIWindow(windowScene: scene)
        }
    }
}
