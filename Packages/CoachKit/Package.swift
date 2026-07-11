// swift-tools-version: 6.2
import PackageDescription

// CoachKit: provider abstraction, prompt/knowledge/context layers, readiness.
// Depends on CoreModel and Secrets. Reads health data only through KnowledgeStore
// (HealthKit queries + LocalSample) -- never through GoogleHealthClient.
// See architecture.md §2 (module map) and §3 (concurrency model).

let package = Package(
    name: "CoachKit",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [
        .library(name: "CoachKit", targets: ["CoachKit"]),
    ],
    dependencies: [
        .package(path: "../CoreModel"),
        .package(path: "../Secrets"),
    ],
    targets: [
        .target(
            name: "CoachKit",
            dependencies: ["CoreModel", "Secrets"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
        .testTarget(
            name: "CoachKitTests",
            dependencies: ["CoachKit"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
    ]
)
