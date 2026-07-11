// swift-tools-version: 6.2
import PackageDescription

// GoogleHealthClient: OAuth (PKCE) + typed REST client for health.googleapis.com/v4/.
// Depends on CoreModel (GoogleDataType, shared value types) and Secrets (KeychainStore).
// See architecture.md §2 (module map) and §3 (concurrency model).

let package = Package(
    name: "GoogleHealthClient",
    platforms: [.iOS("26.0"), .macOS("26.0")],
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
