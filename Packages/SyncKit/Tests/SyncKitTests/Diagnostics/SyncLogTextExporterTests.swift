// SyncLogTextExporterTests.swift
//
// WP-18 (implementation-plan.md): "export-as-text for support ... a
// plain-text dump ... counts and types only, never values." Not one of the
// two explicitly required "Tests:" lines (redaction, ring-buffer capping),
// but this is new, pure, package-level logic backing a real deliverable
// (the Settings viewer's share-sheet export) -- covered with a light golden
// test rather than left unverified.
import Foundation
import Testing
@testable import SyncKit

@Suite struct SyncLogTextExporterTests {
    @Test func exportRendersNewestFirstWithHeaderAndPerEntryLines() {
        let older = SyncLogEntry(
            timestamp: Date(timeIntervalSince1970: 1_000),
            dataType: .steps,
            status: .ok,
            itemCount: 10
        )
        let newer = SyncLogEntry(
            timestamp: Date(timeIntervalSince1970: 2_000),
            dataType: .heartRate,
            status: .error,
            itemCount: 0,
            errorMessage: "Network error"
        )
        let text = SyncLogTextExporter.export([older, newer], generatedAt: Date(timeIntervalSince1970: 3_000))

        #expect(text.contains("FitBridge Sync Log Export"))
        #expect(text.contains("Entries: 2"))

        let lines = text.components(separatedBy: "\n")
        let newerLineIndex = lines.firstIndex { $0.contains("heart_rate") } ?? -1
        let olderLineIndex = lines.firstIndex { $0.contains("steps") && $0.contains("ok") } ?? -1
        #expect(newerLineIndex >= 0)
        #expect(olderLineIndex >= 0)
        #expect(newerLineIndex < olderLineIndex) // newest-first ordering

        #expect(lines[newerLineIndex].contains("error"))
        #expect(lines[newerLineIndex].contains("Network error"))
        #expect(lines[newerLineIndex].contains("0 item(s)"))
        #expect(lines[olderLineIndex].contains("10 item(s)"))
    }

    @Test func exportOfNoEntriesStillProducesAValidHeader() {
        let text = SyncLogTextExporter.export([], generatedAt: Date(timeIntervalSince1970: 0))
        #expect(text.contains("Entries: 0"))
    }

    @Test func exportNeverIncludesAnUnredactedTokenWhenTheStoredEntryWasAlreadyRedacted() {
        // Exporter only ever sees what `SyncLogStore` already holds -- this
        // just confirms the exporter doesn't itself reintroduce raw text
        // (e.g. by reading some other, un-redacted field).
        let entry = SyncLogEntry(
            timestamp: Date(),
            dataType: .weight,
            status: .error,
            itemCount: 0,
            errorMessage: SyncLogRedactor.redact("failed: ya29.a0AfH6SMBxABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        )
        let text = SyncLogTextExporter.export([entry])
        #expect(!text.contains("ya29"))
    }
}
