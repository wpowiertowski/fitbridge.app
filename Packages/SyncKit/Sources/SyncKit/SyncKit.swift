// SyncKit
//
// Placeholder for WP-01 (project skeleton). Real content lands across WP-06
// (HealthKitAuth), WP-07/WP-11 (TypeMapper), WP-08 (HealthKitWriter), WP-09
// (actor SyncEngine), WP-12/WP-12b (HKWorkout + WatchCoverageIndex +
// ConflictResolver), WP-15 (BackfillCoordinator), WP-16 (SyncScheduler). See
// implementation-plan.md and architecture.md §2.
//
// Depends on CoreModel, Secrets, and GoogleHealthClient (architecture.md §2
// dependency order). SyncKit never imports CoachKit (packages never import
// each other sideways, architecture.md §2).

import CoreModel
import GoogleHealthClient
import Secrets

/// Marker enum identifying this module. Exists so the package has a compilable,
/// testable placeholder ahead of the real sync pipeline, and proves the
/// CoreModel + Secrets + GoogleHealthClient dependency wiring compiles.
public enum SyncKitPlaceholder {
    public static let moduleName = "SyncKit"

    /// References the upstream modules so the dependency edges are exercised
    /// at compile time, not just declared in the manifest.
    public static let dependsOn = [
        CoreModelPlaceholder.moduleName,
        SecretsPlaceholder.moduleName,
        GoogleHealthClientPlaceholder.moduleName,
    ]
}
