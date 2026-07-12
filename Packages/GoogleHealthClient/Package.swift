// swift-tools-version: 6.2
// Tools version deliberately stays at 6.2 (a minimum): it parses under both
// Xcode 26 and the Xcode 27 beta, and nothing here needs 6.4-only manifest
// APIs. Bump to 6.4 when CI runners ship Xcode 27 (implementation-plan.md
// "Toolchain note"; WP-38). iOS platform is 27.0 -- the app target requires
// it; macOS stays 26.0 so `swift test` keeps running on macOS 26 CI hosts.
import PackageDescription

// GoogleHealthClient: OAuth (PKCE) + typed REST client for health.googleapis.com/v4/.
// Depends on CoreModel (GoogleDataType, shared value types) and Secrets (KeychainStore).
// See architecture.md §2 (module map) and §3 (concurrency model).

let package = Package(
    name: "GoogleHealthClient",
    platforms: [.iOS("27.0"), .macOS("26.0")],
    products: [
        .library(name: "GoogleHealthClient", targets: ["GoogleHealthClient"]),
    ],
    dependencies: [
        .package(path: "../CoreModel"),
        .package(path: "../Secrets"),
    ],
    targets: [
        .target(
            name: "GoogleHealthClient",
            dependencies: ["CoreModel", "Secrets"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
        .testTarget(
            name: "GoogleHealthClientTests",
            dependencies: ["GoogleHealthClient"],
            resources: [
                .copy("Fixtures"),
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
    ]
)
