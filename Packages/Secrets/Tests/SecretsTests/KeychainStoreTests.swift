// KeychainStoreTests.swift
//
// WP-03 (implementation-plan.md) required tests:
//   - set/get/delete/overwrite round-trip
//   - missing key returns nil
//   - prefix delete removes all provider keys and leaves google.* intact
//
// These run against `InMemoryKeychainBackend` (see that file's header) so
// they're deterministic in any environment, including unsigned/ad-hoc
// `swift test` runs on this Mac where the real Keychain may reject
// operations with `errSecMissingEntitlement` (-34018). A separate
// integration-style suite (`KeychainSecurityBackendTests.swift`) exercises
// the real Keychain and skips itself gracefully when that happens.

import Testing
@testable import Secrets

@Suite("KeychainStore (in-memory backend)")
struct KeychainStoreTests {
    private func makeStore() -> KeychainStore {
        KeychainStore(backend: InMemoryKeychainBackend())
    }

    @Test("set/get round-trip")
    func setGetRoundTrip() async throws {
        let store = makeStore()
        try await store.set("refresh-token-value", for: .googleRefreshToken)
        let value = try await store.get(.googleRefreshToken)
        #expect(value == "refresh-token-value")
    }

    @Test("overwrite replaces the previous value")
    func overwriteRoundTrip() async throws {
        let store = makeStore()
        try await store.set("first-value", for: .claudeAPIKey)
        try await store.set("second-value", for: .claudeAPIKey)
        let value = try await store.get(.claudeAPIKey)
        #expect(value == "second-value")
    }

    @Test("delete removes a stored value")
    func deleteRemovesValue() async throws {
        let store = makeStore()
        try await store.set("some-value", for: .openAIAPIKey)
        try await store.delete(.openAIAPIKey)
        let value = try await store.get(.openAIAPIKey)
        #expect(value == nil)
    }

    @Test("delete is idempotent when nothing is stored")
    func deleteOnMissingKeyDoesNotThrow() async throws {
        let store = makeStore()
        try await store.delete(.geminiAPIKey)
    }

    @Test("get on a key that was never set returns nil")
    func missingKeyReturnsNil() async throws {
        let store = makeStore()
        let value = try await store.get(.googleAccessToken)
        #expect(value == nil)
    }

    @Test("full round-trip across all five keys, independently")
    func allKeysRoundTripIndependently() async throws {
        let store = makeStore()
        for key in SecretKey.allCases {
            try await store.set(key.rawValue, for: key)
        }
        for key in SecretKey.allCases {
            let value = try await store.get(key)
            #expect(value == key.rawValue)
        }
    }

    @Test("prefix delete removes all provider.* keys and leaves google.* intact")
    func prefixDeleteRemovesOnlyMatchingDomain() async throws {
        let store = makeStore()
        for key in SecretKey.allCases {
            try await store.set("value-for-\(key.rawValue)", for: key)
        }

        try await store.deleteAll(matching: "provider.")

        // Every provider.* key is gone.
        #expect(try await store.get(.claudeAPIKey) == nil)
        #expect(try await store.get(.openAIAPIKey) == nil)
        #expect(try await store.get(.geminiAPIKey) == nil)

        // Both google.* keys are untouched.
        #expect(try await store.get(.googleRefreshToken) == "value-for-google.refreshToken")
        #expect(try await store.get(.googleAccessToken) == "value-for-google.accessToken")
    }

    @Test("prefix delete on google. leaves provider.* keys intact")
    func prefixDeleteOtherDirection() async throws {
        let store = makeStore()
        for key in SecretKey.allCases {
            try await store.set("value-for-\(key.rawValue)", for: key)
        }

        try await store.deleteAll(matching: "google.")

        #expect(try await store.get(.googleRefreshToken) == nil)
        #expect(try await store.get(.googleAccessToken) == nil)

        #expect(try await store.get(.claudeAPIKey) == "value-for-provider.claude.apiKey")
        #expect(try await store.get(.openAIAPIKey) == "value-for-provider.openai.apiKey")
        #expect(try await store.get(.geminiAPIKey) == "value-for-provider.gemini.apiKey")
    }

    @Test("prefix delete with a prefix matching nothing is a no-op")
    func prefixDeleteNoMatchIsNoOp() async throws {
        let store = makeStore()
        try await store.set("value", for: .googleRefreshToken)
        try await store.deleteAll(matching: "nonexistent.")
        #expect(try await store.get(.googleRefreshToken) == "value")
    }
}

@Suite("SecretKey namespacing invariant")
struct SecretKeyNamespacingTests {
    @Test("every provider key's raw value starts with provider.")
    func providerKeysShareNamespace() {
        let providerKeys: [SecretKey] = [.claudeAPIKey, .openAIAPIKey, .geminiAPIKey]
        for key in providerKeys {
            #expect(key.rawValue.hasPrefix("provider."))
        }
    }

    @Test("every google key's raw value starts with google.")
    func googleKeysShareNamespace() {
        let googleKeys: [SecretKey] = [.googleRefreshToken, .googleAccessToken]
        for key in googleKeys {
            #expect(key.rawValue.hasPrefix("google."))
        }
    }

    @Test("no key matches both namespaces")
    func namespacesAreDisjoint() {
        for key in SecretKey.allCases {
            let isProvider = key.rawValue.hasPrefix("provider.")
            let isGoogle = key.rawValue.hasPrefix("google.")
            #expect(isProvider != isGoogle)
        }
    }
}
