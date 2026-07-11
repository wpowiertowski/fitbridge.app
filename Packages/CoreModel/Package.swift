// swift-tools-version: 6.2
import PackageDescription

// CoreModel: SwiftData models + shared value types. No I/O, no HealthKit import.
// See architecture.md §2 (module map) and §3 (concurrency model).

let package = Package(
    name: "CoreModel",
    platforms: [.iOS("26.0"), .macOS("26.0")],
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
