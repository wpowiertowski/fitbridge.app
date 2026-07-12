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
        XCTAssertTrue(signIn.waitForExistence(timeout: 15), "Google consent screen never appeared")
        signIn.tap()

        let continueToDashboard = app.buttons["onboarding.firstSync.continue"]
        XCTAssertTrue(continueToDashboard.waitForExistence(timeout: 15), "First-sync completion screen never appeared")
        continueToDashboard.tap()

        // Dashboard shows all 4 P0 types (test-plan.md §5 smoke test #1).
        // The List is lazily rendered, so the lower rows may need a scroll
        // into view before their accessibility elements exist (see
        // DashboardUITests.swift's `scrollUntilExists` for the same, more
        // fully commented, workaround).
        let anyElement = app.descendants(matching: .any)
        XCTAssertTrue(anyElement["dashboard.syncNow"].waitForExistence(timeout: 10))
        for rawValue in ["steps", "heart_rate", "weight", "sleep"] {
            let element = anyElement["dashboard.row.\(rawValue).name"]
            if !element.waitForExistence(timeout: 5) {
                app.swipeUp()
            }
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
    /// No-ops (both waits time out quickly) if authorization was already
    /// granted by an earlier run on this simulator -- HealthKit shows no UI
    /// at all in that case and `requestWrite(for:)` resolves immediately.
    @MainActor
    private func handleHealthKitPermissionSheetIfPresented(in app: XCUIApplication) {
        // `.firstMatch` on each: a plain `.any` query for "Allow" matches
        // both the button and its own label's `StaticText` child (both
        // report "Allow"), which XCUITest refuses to disambiguate on `.tap()`
        // -- observed directly against the real simulator run.
        let turnOnAll = app.descendants(matching: .any).matching(identifier: "Turn On All").firstMatch
        if turnOnAll.waitForExistence(timeout: 5) {
            turnOnAll.tap()
        }
        let allow = app.descendants(matching: .any).matching(identifier: "Allow").firstMatch
        if allow.waitForExistence(timeout: 5) {
            allow.tap()
        }
    }
}
