// PaginationTests.swift
//
// WP-05 required test: "pagination stitches 2 pages, preserves window."
// architecture.md D1 / WP-05 step 4: "the page token continues within that
// window (do not re-derive the window per page)."

import Foundation
import Testing
@testable import GoogleHealthClient

@Suite("GoogleHealthClient pagination")
struct PaginationTests {
    @Test("reconcile stitches 2 pages in order and both requests carry an identical since/until window")
    func stitchesTwoPagesWithStableWindow() async throws {
        let http = RecordingHTTPSession { request, _ in
            if TestClientFactory.isTokenRequest(request) {
                return (TestClientFactory.tokenJSON(), httpResponse(statusCode: 200))
            }
            let bodyDict = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any]
            let pageToken = bodyDict?["pageToken"] as? String
            if pageToken == "PAGE2TOKEN" {
                return (await Fixture.data("paged-steps-p2"), httpResponse(statusCode: 200))
            }
            return (await Fixture.data("paged-steps-p1"), httpResponse(statusCode: 200))
        }
        let client = TestClientFactory.client(http: http)

        let since = Date(timeIntervalSince1970: 1_800_000_000)
        let until = since.addingTimeInterval(3 * 3600)

        let page1 = try await client.reconcile(type: .steps, since: since, until: until)
        #expect(page1.points.map(\.id) == ["steps-page1-0001", "steps-page1-0002"])
        #expect(page1.nextPageToken == "PAGE2TOKEN")

        let page2 = try await client.reconcile(type: .steps, since: since, until: until, pageToken: page1.nextPageToken)
        #expect(page2.points.map(\.id) == ["steps-page2-0001"])
        #expect(page2.nextPageToken == nil)

        let stitched = page1.points + page2.points
        #expect(stitched.map(\.id) == ["steps-page1-0001", "steps-page1-0002", "steps-page2-0001"])

        let dataRequests = await http.requests.filter { !TestClientFactory.isTokenRequest($0) }
        #expect(dataRequests.count == 2)

        let windows = dataRequests.map { request -> [String: String] in
            let dict = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any]
            return [
                "startTime": dict?["startTime"] as? String ?? "",
                "endTime": dict?["endTime"] as? String ?? "",
            ]
        }
        #expect(windows[0] == windows[1])
        #expect(windows[0]["startTime"] == ISO8601Formatting.string(from: since))
        #expect(windows[0]["endTime"] == ISO8601Formatting.string(from: until))
    }
}
