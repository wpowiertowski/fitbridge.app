// swift-tools-version: 6.2
// Tools version deliberately stays at 6.2 (a minimum): it parses under both
// Xcode 26 and the Xcode 27 beta, and nothing here needs 6.4-only manifest
// APIs. Bump to 6.4 when CI runners ship Xcode 27 (implementation-plan.md
// "Toolchain note"; WP-38). iOS platform is 27.0 -- the app target requires
// it; macOS stays 26.0 so `swift test` keeps running on macOS 26 CI hosts.
import PackageDescription

// SyncKit: pull -> map -> resolve conflicts -> write pipeline + scheduling.
// Depends on CoreModel, Secrets, and GoogleHealthClient.
// See architecture.md §2 (module map) and §3 (concurrency model).

let package = Package(
    name: "SyncKit",
    platforms: [.iOS("27.0"), .macOS("26.0")],
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
