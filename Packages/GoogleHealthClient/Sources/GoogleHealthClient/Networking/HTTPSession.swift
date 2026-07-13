// HTTPSession.swift
//
// WP-04/WP-05 (implementation-plan.md): the one seam all networking in this
// package goes through. Every test in this package injects a stub conforming
// to `HTTPSession` instead of touching the network, per the WP-04 step 6 /
// WP-05 step 6 requirement ("inject HTTPSession so tests inject a stub").
//
// Deliberately minimal: a single `send(_:)` entry point mirroring
// `URLSession.data(for:)`, returning the response already downcast to
// `HTTPURLResponse` (every endpoint this package talks to is HTTP(S)).

import Foundation

/// Thin `URLSession` wrapper. Production code uses `URLSessionHTTPSession`;
/// tests inject a recording/scripted stub (see `Tests/.../Support`).
nonisolated public protocol HTTPSession: Sendable {
    nonisolated func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Production `HTTPSession` backed by a real `URLSession`.
nonisolated public struct URLSessionHTTPSession: HTTPSession {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}
