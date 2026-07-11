// ZeroJitterSource.swift
//
// Deterministic `JitterSource` fake: always contributes zero extra delay, so
// `BackoffPolicy.delay(...)` reduces to the exact exponential schedule and
// the 429-backoff test can assert an exact sequence rather than a range.

import GoogleHealthClient

struct ZeroJitterSource: JitterSource {
    func nextFraction() -> Double { 0 }
}
