// FakeTokenStore.swift
//
// In-memory `GoogleTokenStoring` fake (task brief: "test against a fake"
// rather than the real Keychain, which can't run in this unsigned test
// process -- see KeychainStore+GoogleTokenStoring.swift's header).

import GoogleHealthClient

actor FakeTokenStore: GoogleTokenStoring {
    private var storedRefreshToken: String?
    private var storedAccessToken: String?

    init(refreshToken: String? = nil, accessToken: String? = nil) {
        self.storedRefreshToken = refreshToken
        self.storedAccessToken = accessToken
    }

    func refreshToken() async throws -> String? { storedRefreshToken }
    func setRefreshToken(_ value: String?) async throws { storedRefreshToken = value }

    func accessToken() async throws -> String? { storedAccessToken }
    func setAccessToken(_ value: String?) async throws { storedAccessToken = value }
}
