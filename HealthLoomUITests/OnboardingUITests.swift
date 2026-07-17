// OnboardingUITests.swift
//
// WP-10 (implementation-plan.md): "UI test -- onboarding happy path with
// stubbed auth (launch argument `-UITestStubGoogle`)." test-plan.md §5's
// smoke-test #1: "Onboarding happy path: welcome -> HK permission (handle
// system alert) -> stubbed Google consent -> first sync -> dashboard shows
// 4 types."
//
// `-UITestStubGoogle` (see HealthLoomApp/DI/LaunchConfiguration.swift) swaps
// in `StubGoogleConsentCoordinator` and `StubGoogleReconcileClient` so this
// test never makes a real network call to Google. HealthKit permission is
// *not* stubbed -- `HealthKitAuth.requestWrite` runs for real against the
// simulator's real HealthKit store, so this test must drive (or dismiss)
// the system permission UI itself.

import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingHappyPathWithStubbedGoogle() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestStubGoogle"]

        app.launch()

        let welcomeContinue = app.buttons["onboarding.welcome.continue"]
        XCTAssertTrue(welcomeContinue.waitForExistence(timeout: 10), "Welcome screen never appeared")
        welcomeContinue.tap()

        let allowHealthKit = app.buttons["onboarding.healthkit.allow"]
        XCTAssertTrue(allowHealthKit.waitForExistence(timeout: 10), "HealthKit permission screen never appeared")
        allowHealthKit.tap()

        // HealthKit's real "Health Access" system sheet
        // (HKHealthStore.requestAuthorization, driven by
        // Packages/SyncKit/Sources/SyncKit/HealthKit/HealthKitAuth.swift's
        // `requestWrite(for:)`) is hosted *inside* this app's own queryable
        // element tree (a different process ID in the accessibility
        // snapshot, but directly reachable via `app.*` queries -- confirmed
        // against a real simulator run, not a cross-process alert an
        // interruption monitor is needed for).
        handleHealthKitPermissionSheetIfPresented(in: app)

        let signIn = app.buttons["onboarding.google.signIn"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 30), "Google consent screen never appeared")
        signIn.tap()

        let continueToDashboard = app.buttons["onboarding.firstSync.continue"]
        XCTAssertTrue(continueToDashboard.waitForExistence(timeout: 30), "First-sync completion screen never appeared")
        continueToDashboard.tap()

        // Dashboard shows all 4 P0 types (test-plan.md §5 smoke test #1).
        // The List is lazily rendered, so the lower rows may need a scroll
        // into view before their accessibility elements exist (see
        // ScrollUntilExists.swift for the shared, fully commented,
        // incremental-scroll workaround).
        let anyElement = app.descendants(matching: .any)
        XCTAssertTrue(anyElement["dashboard.syncNow"].waitForExistence(timeout: 10))
        for rawValue in ["steps", "heart_rate", "weight", "sleep"] {
            let element = anyElement["dashboard.row.\(rawValue).name"]
            scrollUntilExists(element, in: app)
            XCTAssertTrue(
                element.waitForExistence(timeout: 5),
                "Dashboard missing row for \(rawValue)"
            )
        }
    }

    /// Drives (or no-ops past) HealthKit's real "Health Access" system sheet.
    ///
    /// Real shape discovered via a `xcodebuild test` run against the
    /// simulator (not guessed): one scrollable list of per-category toggle
    /// switches (all off initially: `UIA.Health.Write.<Type>.SwitchCell`),
    /// a "Turn On All" cell (`UIA.Health.AuthSheet.AllCategoryButton`), and
    /// "Allow"/"Don't Allow" buttons pinned at the bottom
    /// (`UIA.Health.Allow.Button` / `UIA.Health.DoNotAllow.Button`).
    /// **"Allow" starts disabled and stays disabled until at least one
    /// switch is on** -- tapping it first (before "Turn On All") is a
    /// silent no-op that leaves the sheet on screen forever, which is
    /// exactly the failure this test hit before this fix (the sheet never
    /// dismissed, so `requestWrite(for:)` never resolved and every
    /// downstream screen timed out waiting to appear).
    ///
    /// No-ops (the loop exits as soon as the Google screen shows) if
    /// authorization was already granted by an earlier run on this
    /// simulator -- HealthKit shows no UI at all in that case and
    /// `requestWrite(for:)` resolves immediately.
    ///
    /// Structured as a single polling loop rather than two fixed
    /// `waitForExistence(timeout: 5)` windows: on CI's cold simulator the
    /// sheet can take well over 5 seconds to be presented the first time
    /// (healthd + the remote sheet process spin up from nothing; the same
    /// run showed 8-15s just to set up the automation session), and once
    /// both short windows had passed the sheet sat unhandled forever and
    /// every downstream screen timed out -- exactly the failure seen on the
    /// xcode-27 runner (PR #7). The loop instead keeps tapping whichever
    /// control is currently present until the sheet resolves (the Google
    /// screen appearing) or a generous overall deadline passes, at which
    /// point the caller's own assert reports the failure.
    @MainActor
    private func handleHealthKitPermissionSheetIfPresented(in app: XCUIApplication) {
        // `.firstMatch` on each: a plain `.any` query for "Allow" matches
        // both the button and its own label's `StaticText` child (both
        // report "Allow"), which XCUITest refuses to disambiguate on `.tap()`
        // -- observed directly against the real simulator run.
        let turnOnAll = app.descendants(matching: .any).matching(identifier: "Turn On All").firstMatch
        let allow = app.descendants(matching: .any).matching(identifier: "Allow").firstMatch
        let googleSignIn = app.buttons["onboarding.google.signIn"]
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline {
            // Sheet dismissed (or never shown): requestWrite resolved and
            // onboarding advanced past the HealthKit step.
            if googleSignIn.exists { return }
            // "Allow" starts disabled and stays disabled until at least one
            // switch is on -- tap "Turn On All" first whenever it's still
            // present; tapping a disabled "Allow" is a harmless no-op the
            // next iteration retries after "Turn On All" landed.
            if turnOnAll.exists {
                turnOnAll.tap()
            } else if allow.exists {
                allow.tap()
            }
            _ = googleSignIn.waitForExistence(timeout: 1)
        }
    }
}
