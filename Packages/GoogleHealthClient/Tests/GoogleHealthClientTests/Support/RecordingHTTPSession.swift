// RecordingHTTPSession.swift
//
// Test-only `HTTPSession` stub (task brief: "every required test runs
// against a stub with fixtures. No real network calls in tests."). Records
// every request it sees (so tests can assert on exact request encoding /
// stable pagination windows) and answers via a caller-supplied handler
// closure, so each test can script whatever status/body/header sequence it
// needs (including "N-th call to this endpoint returns X").

import Foundation
import GoogleHealthClient

actor RecordingHTTPSession: HTTPSession {
    private(set) var requests: [URLRequest] = []
    private let handler: @Sendable (URLRequest, [URLRequest]) async throws -> (Data, HTTPURLResponse)

    init(handler: @escaping @Sendable (URLRequest, [URLRequest]) async throws -> (Data, HTTPURLResponse)) {
        self.handler = handler
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return try await handler(request, requests)
    }

    /// Number of recorded requests whose URL's path contains `substring`
    /// (handy for "assert exactly one refresh call" style assertions).
    func requestCount(urlContains substring: String) -> Int {
        requests.filter { $0.url?.absoluteString.contains(substring) == true }.count
    }
}

/// Builds a plain 200/JSON `HTTPURLResponse` + body pair, the common case
/// for scripted handlers. `nonisolated`: scripted handler closures passed to
/// `RecordingHTTPSession` are inferred nonisolated (a `@Sendable` closure
/// literal doesn't inherit the enclosing test function's default MainActor
/// isolation), so every helper called from inside one must be nonisolated
/// too.
nonisolated func httpResponse(
    url: URL = URL(string: "https://example.invalid/")!,
    statusCode: Int,
    headers: [String: String] = [:]
) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers)!
}
