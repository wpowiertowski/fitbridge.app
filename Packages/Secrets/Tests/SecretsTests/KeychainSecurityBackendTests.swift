// KeychainSecurityBackendTests.swift
//
// WP-03 (implementation-plan.md) testing note: this is the one
// integration-style test that attempts the *real* Keychain (as opposed to
// `KeychainStoreTests`, which runs the required suite against an in-memory
// fake). `swift test` on this Mac runs an unsigned/ad-hoc binary, and macOS's
// Keychain can reject every `SecItem*` call from such a process with
// `errSecMissingEntitlement` (-34018) — behavior that differs from the iOS
// data-protection Keychain the app actually ships against. Rather than fail
// the suite in that environment, this test probes availability first and
// skips itself with a clear reason via the `.enabled(if:)` trait. See
// progress.md's WP-03 entry for what was observed on this machine.

import Testing
@testable import Secrets

/// Attempts a real add+delete cycle on a disposable Keychain item to decide
/// whether the real Keychain is usable in this process at all. Uses its own
/// throwaway service name (distinct from both production
/// `"com.fitbridge.secrets"` and the test service below) purely as a probe,
/// so it can never interact with a real secret.
nonisolated private func isRealKeychainUsable() -> Bool {
    let backend = KeychainSecurityBackend(service: "com.fitbridge.secrets.integration-test-probe")
    do {
        try backend.write(account: "__probe__", value: "probe")
        try backend.erase(account: "__probe__")
        return true
    } catch {
        return false
    }
}

@Suite("KeychainStore against the real Keychain (integration)")
struct KeychainSecurityBackendTests {
    // Distinct from the production service name ("com.fitbridge.secrets") so
    // this suite can never read, overwrite, or delete a secret a real app
    // run left behind on this machine.
    private static let testService = "com.fitbridge.secrets.integration-test"

    private func makeStore() -> KeychainStore {
        KeychainStore(backend: KeychainSecurityBackend(service: Self.testService))
    }

    @Test(
        "real Keychain set/get/delete/overwrite round-trip",
        .enabled(
            if: isRealKeychainUsable(),
            """
            Real Keychain unavailable to this test process (commonly \
            errSecMissingEntitlement / -34018 for an unsigned `swift test` \
            runner on macOS, or a sandboxed CI environment). This is a \
            known macOS-vs-iOS Keychain gap, not a bug in KeychainStore -- \
            see progress.md's WP-03 entry. The required round-trip / \
            missing-key / prefix-delete behavior is still fully verified by \
            KeychainStoreTests against the in-memory backend.
            """
        )
    )
    func realKeychainRoundTrip() async throws {
        let store = makeStore()

        // Best-effort clean slate in case a previous run of this suite
        // crashed before its own cleanup ran.
        try? await store.delete(.googleRefreshToken)

        let initial = try await store.get(.googleRefreshToken)
        #expect(initial == nil)

        try await store.set("integration-test-value-1", for: .googleRefreshToken)
        let afterSet = try await store.get(.googleRefreshToken)
        #expect(afterSet == "integration-test-value-1")

        try await store.set("integration-test-value-2", for: .googleRefreshToken)
        let afterOverwrite = try await store.get(.googleRefreshToken)
        #expect(afterOverwrite == "integration-test-value-2")

        try await store.delete(.googleRefreshToken)
        let afterDelete = try await store.get(.googleRefreshToken)
        #expect(afterDelete == nil)
    }
}
