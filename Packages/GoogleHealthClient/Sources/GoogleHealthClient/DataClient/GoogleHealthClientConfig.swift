// GoogleHealthClientConfig.swift
//
// WP-05 (implementation-plan.md) / base-knowledge.md §2: "Base URL:
// https://health.googleapis.com/v4/."

nonisolated public struct GoogleHealthClientConfig: Sendable {
    public var baseURL: String
    public var backoff: BackoffPolicy

    public init(
        baseURL: String = "https://health.googleapis.com/v4/",
        backoff: BackoffPolicy = BackoffPolicy()
    ) {
        self.baseURL = baseURL
        self.backoff = backoff
    }
}
