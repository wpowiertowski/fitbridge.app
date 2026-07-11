// GoogleDataPointDecodingTests.swift
//
// WP-05 required tests: "decode each fixture to expected GoogleDataPoints";
// "mm→m normalization"; "malformed JSON throws typed error." Fixtures live
// under Fixtures/GoogleHealth (WP-05 step 7); every fixture's shape
// assumptions are recorded as a `_comment` key per the fixtures rule.

import CoreModel
import Foundation
import Testing
@testable import GoogleHealthClient

@Suite("GoogleDataPoint decoding")
struct GoogleDataPointDecodingTests {
    private func iso(_ string: String) -> Date {
        ISO8601Formatting.date(from: string)!
    }

    @Test("steps.json decodes both interval points with unqualified `count` values")
    func decodesSteps() async throws {
        let client = TestClientFactory.inertClient()
        let page = try client.decodePage(await Fixture.data("steps"), type: .steps)

        #expect(page.nextPageToken == nil)
        #expect(page.points.count == 2)

        let first = page.points[0]
        #expect(first.id == "steps-0001")
        #expect(first.dataType == .steps)
        #expect(first.start == iso("2026-07-01T00:00:00Z"))
        #expect(first.end == iso("2026-07-01T01:00:00Z"))
        #expect(first.values == ["count": 482])
        #expect(first.sessionPayload == nil)
        #expect(first.source.platform == "IOS")
        #expect(first.source.deviceDisplayName == "Fitbit Air")
        #expect(first.source.recordingMethod == "AUTOMATICALLY_RECORDED")

        #expect(page.points[1].id == "steps-0002")
        #expect(page.points[1].values == ["count": 129])
    }

    @Test("heart-rate.json decodes both instant samples with unqualified `bpm` values")
    func decodesHeartRate() async throws {
        let client = TestClientFactory.inertClient()
        let page = try client.decodePage(await Fixture.data("heart-rate"), type: .heartRate)

        #expect(page.points.count == 2)
        #expect(page.points[0].values == ["bpm": 58])
        #expect(page.points[0].start == page.points[0].end)
        #expect(page.points[1].values == ["bpm": 61])
    }

    @Test("weight.json decodes the sample with unqualified `mass` value")
    func decodesWeight() async throws {
        let client = TestClientFactory.inertClient()
        let page = try client.decodePage(await Fixture.data("weight"), type: .weight)

        #expect(page.points.count == 1)
        let point = page.points[0]
        #expect(point.id == "weight-0001")
        #expect(point.dataType == .weight)
        #expect(point.values == ["mass": 70.5])
        #expect(point.sessionPayload == nil)
        #expect(point.source.deviceDisplayName == "Fitbit Aria Air")
    }

    @Test("sleep.json decodes the session's bounds and preserves the stage segments as sessionPayload")
    func decodesSleepSession() async throws {
        let client = TestClientFactory.inertClient()
        let page = try client.decodePage(await Fixture.data("sleep"), type: .sleep)

        #expect(page.points.count == 1)
        let point = page.points[0]
        #expect(point.id == "sleep-0001")
        #expect(point.dataType == .sleep)
        #expect(point.start == iso("2026-07-08T23:15:00Z"))
        #expect(point.end == iso("2026-07-09T06:45:00Z"))
        // No scalar leaf fields in a sleep session -- everything nests under
        // `sleep.segment`, so `values` is empty and the nested structure is
        // preserved verbatim in `sessionPayload` instead (WP-05 step 2).
        #expect(point.values.isEmpty)

        let payload = try #require(point.sessionPayload)
        let decodedPayload = try JSONSerialization.jsonObject(with: payload) as? [String: Any]
        let segments = try #require(decodedPayload?["sleep.segment"] as? [[String: Any]])
        #expect(segments.count == 5)
        #expect(segments.first?["stage"] as? String == "awake")
        #expect(segments.last?["stage"] as? String == "light")
    }

    @Test("distance.json normalizes millimeters to meters (mm→m, base-knowledge §2)")
    func normalizesDistanceMillimetersToMeters() async throws {
        let client = TestClientFactory.inertClient()
        let page = try client.decodePage(await Fixture.data("distance"), type: .distance)

        #expect(page.points.count == 1)
        // Fixture's raw wire value is 15000mm; UnitNormalizer converts to 15.0m.
        #expect(page.points[0].values == ["distance": 15.0])
    }

    @Test("malformed JSON throws a typed decoding error")
    func malformedJSONThrowsTypedError() {
        let client = TestClientFactory.inertClient()
        let garbage = Data("{not valid json".utf8)

        do {
            _ = try client.decodePage(garbage, type: .steps)
            Issue.record("Expected decodingFailed to be thrown")
        } catch {
            guard case .decodingFailed = error else {
                Issue.record("Expected .decodingFailed, got \(error)")
                return
            }
        }
    }

    @Test("a data point missing a required field throws a typed decoding error")
    func missingRequiredFieldThrowsTypedError() {
        let client = TestClientFactory.inertClient()
        let body = Data("""
        { "point": [ { "dataPointId": "x", "startTime": "2026-07-01T00:00:00Z" } ] }
        """.utf8)

        do {
            _ = try client.decodePage(body, type: .steps)
            Issue.record("Expected decodingFailed to be thrown")
        } catch {
            guard case .decodingFailed = error else {
                Issue.record("Expected .decodingFailed, got \(error)")
                return
            }
        }
    }
}
