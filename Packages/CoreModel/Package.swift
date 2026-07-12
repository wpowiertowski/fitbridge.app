// swift-tools-version: 6.2
// Tools version deliberately stays at 6.2 (a minimum): it parses under both
// Xcode 26 and the Xcode 27 beta, and nothing here needs 6.4-only manifest
// APIs. Bump to 6.4 when CI runners ship Xcode 27 (implementation-plan.md
// "Toolchain note"; WP-38). iOS platform is 27.0 -- the app target requires
// it; macOS stays 26.0 so `swift test` keeps running on macOS 26 CI hosts.
import PackageDescription

// CoreModel: SwiftData models + shared value types. No I/O, no HealthKit import.
// See architecture.md §2 (module map) and §3 (concurrency model).

let package = Package(
    name: "CoreModel",
    platforms: [.iOS("27.0"), .macOS("26.0")],
    products: [
        .library(name: "CoreModel", targets: ["CoreModel"]),
    ],
    targets: [
        .target(
            name: "CoreModel",
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
        .testTarget(
            name: "CoreModelTests",
            dependencies: ["CoreModel"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
    ]
)
