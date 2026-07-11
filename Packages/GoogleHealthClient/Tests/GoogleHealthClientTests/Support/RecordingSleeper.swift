// RecordingSleeper.swift
//
// Test-only `BackoffSleeper` ("virtual clock", task brief: "Backoff timing
// must be testable: inject a clock/sleeper abstraction rather than calling
// Task.sleep directly."). Records requested durations and returns
// immediately -- tests observe the exact backoff schedule without waiting
// real wall-clock seconds.

import GoogleHealthClient

actor RecordingSleeper: BackoffSleeper {
    private(set) var recordedDurations: [Double] = []

    func sleep(seconds: Double) async throws {
        recordedDurations.append(seconds)
    }
}
