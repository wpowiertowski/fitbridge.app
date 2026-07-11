// Fixture.swift
//
// Loads JSON fixtures from Fixtures/GoogleHealth (WP-05 step 7). Resource
// bundling is declared in Package.swift's test target (`resources: [.copy("Fixtures")]`).

import Foundation

enum Fixture {
    /// `async`, not plain `nonisolated`, because SPM's generated
    /// `Bundle.module` accessor is itself subject to this target's
    /// `.defaultIsolation(MainActor.self)` (it's compiled as part of this
    /// module too) -- `async` lets this be called from both ordinary
    /// (MainActor-default) test bodies and the nonisolated `@Sendable`
    /// handler closures passed to `RecordingHTTPSession`.
    static func data(_ name: String) async -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/GoogleHealth") else {
            fatalError("Missing fixture \(name).json under Fixtures/GoogleHealth")
        }
        return try! Data(contentsOf: url)
    }
}
