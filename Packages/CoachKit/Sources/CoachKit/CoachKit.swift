// CoachKit
//
// Placeholder for WP-01 (project skeleton). Real content lands across WP-19
// (KnowledgeStore), WP-20 (ContextAssembler), WP-21 (PromptManager +
// SafetyLayer), WP-22 (Foundation Models session), WP-23 (ReadinessEngine +
// DailyInsight), WP-24 (Tools), WP-27 (CoachProvider + ProviderRegistry +
// CoachOrchestrator), WP-28 (cloud providers). See implementation-plan.md and
// architecture.md §2.
//
// Depends on CoreModel and Secrets (architecture.md §2 dependency order).
// CoachKit reads health data only through KnowledgeStore (HealthKit queries +
// LocalSample), never through GoogleHealthClient (architecture.md §2).

import CoreModel
import Secrets

/// Marker enum identifying this module. Exists so the package has a compilable,
/// testable placeholder ahead of the real coach layers, and proves the
/// CoreModel + Secrets dependency wiring compiles.
public enum CoachKitPlaceholder {
    public static let moduleName = "CoachKit"

    /// References the upstream modules so the dependency edges are exercised
    /// at compile time, not just declared in the manifest.
    public static let dependsOn = [
        CoreModelPlaceholder.moduleName,
        SecretsPlaceholder.moduleName,
    ]
}
