// swift-tools-version: 6.2
import PackageDescription

// Secrets: Keychain wrapper. No dependencies on other HealthLoom packages.
// See architecture.md §2 (module map) and §3 (concurrency model).

let package = Package(
    name: "Secrets",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [
        .library(name: "Secrets", targets: ["Secrets"]),
    ],
    targets: [
        .target(
            name: "Secrets",
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
        .testTarget(
            name: "SecretsTests",
            dependencies: ["Secrets"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
    ]
)
