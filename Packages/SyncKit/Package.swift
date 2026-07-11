// swift-tools-version: 6.2
import PackageDescription

// SyncKit: pull -> map -> resolve conflicts -> write pipeline + scheduling.
// Depends on CoreModel, Secrets, and GoogleHealthClient.
// See architecture.md §2 (module map) and §3 (concurrency model).

let package = Package(
    name: "SyncKit",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [
        .library(name: "SyncKit", targets: ["SyncKit"]),
    ],
    dependencies: [
        .package(path: "../CoreModel"),
        .package(path: "../Secrets"),
        .package(path: "../GoogleHealthClient"),
    ],
    targets: [
        .target(
            name: "SyncKit",
            dependencies: ["CoreModel", "Secrets", "GoogleHealthClient"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
        .testTarget(
            name: "SyncKitTests",
            dependencies: ["SyncKit"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
    ]
)
