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
    /// No-ops (returns as soon as the Google screen shows) if authorization
    /// was already granted by an earlier run on this simulator -- HealthKit
    /// shows no UI at all in that case and `requestWrite(for:)` resolves
    /// immediately.
    ///
    /// Shape learned from three CI failures on the xcode-27 runner (PR #7):
    ///
    /// 1. On a cold CI simulator the sheet can take 15s+ to be presented
    ///    (run 1: two fixed 5s waits both closed before it appeared and it
    ///    then sat unhandled forever), so appearance gets one long polling
    ///    window rather than short fixed timeouts.
    /// 2. Queries must be identifier-only (`.any`), NOT typed `.buttons`:
    ///    the iOS 27 beta's accessibility bridge reports unstable
    ///    automation types for this out-of-process sheet (run 2's crash
    ///    dump: "Automation type mismatch: computed Other from legacy
    ///    attributes vs Toolbar/StaticText from modern attribute"). Run 3
    ///    proved it: an `app.buttons["Turn On All"]` query matched nothing
    ///    for 60 straight seconds while the sheet sat on screen; run 2's
    ///    `.any` query on the same sheet matched within 13s.
    /// 3. Taps go through screen coordinates (`tapCenter`), never
    ///    `XCUIElement.tap()`: the `.any` firstMatch can resolve to the
    ///    button's own StaticText label, on which tap()'s hittability +
    ///    scroll-to-visible machinery first failed (hit point {-1, -1})
    ///    and then fatally crashed the test ("Failed to get matching
    ///    snapshot") when the element went stale mid-resolution (run 2).
    ///    A center-coordinate tap lands on the enclosing control and does
    ///    none of that resolution.
    /// 4. "Turn On All" is idempotent, not a label-flipping toggle -- run
    ///    2 landed four taps on it and its identifier persisted throughout
    ///    -- so re-tapping it across retry iterations is safe. What run 2
    ///    actually got wrong was never tapping "Allow" (its else-branch
    ///    starved while "Turn On All" kept existing).
    @MainActor
    private func handleHealthKitPermissionSheetIfPresented(in app: XCUIApplication) {
        let googleSignIn = app.buttons["onboarding.google.signIn"]
        let turnOnAll = app.descendants(matching: .any).matching(identifier: "Turn On All").firstMatch
        let allow = app.descendants(matching: .any).matching(identifier: "Allow").firstMatch

        // Wait for whichever comes first: the sheet, or the next onboarding
        // screen (authorization already granted -- no sheet at all).
        guard waitUntil(timeout: 60, { googleSignIn.exists || turnOnAll.exists }),
              !googleSignIn.exists else { return }

        // Let the presentation animation settle before the first tap; run
        // 2's earliest tap landed mid-slide-in and missed.
        pause(1.5)

        // Switches on, then "Allow" (disabled until at least one switch is
        // on); retry the pair a bounded number of times in case a single
        // synthesized tap is dropped by the beta's input path. Every
        // iteration re-checks existence first, so once the sheet dismisses
        // the loop stops touching it.
        var attempts = 0
        while !googleSignIn.exists && attempts < 6 {
            if turnOnAll.exists {
                tapCenter(of: turnOnAll)
                pause(1)
            }
            if allow.exists {
                tapCenter(of: allow)
            }
            _ = waitUntil(timeout: 3) { googleSignIn.exists }
            attempts += 1
        }
        // Anything still unresolved is observed by the caller's own 30s
        // wait for the Google screen -- on failure the uploaded xcresult
        // carries the accessibility snapshots.
    }

    /// Taps the center of `element`'s current frame via a screen
    /// coordinate -- see the doc comment above for why `tap()` is unsafe
    /// against this sheet.
    @MainActor
    private func tapCenter(of element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// Spins the main run loop for `seconds` (UI-test-safe sleep).
    @MainActor
    private func pause(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    /// Polls `condition` on the main run loop until it's true or `timeout`
    /// elapses. A hand-rolled loop instead of `XCTNSPredicateExpectation`
    /// so the condition can touch `XCUIElement` state without escaping
    /// main-actor isolation (this target compiles with strict concurrency).
    @MainActor
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline { return false }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        return true
    }
}
