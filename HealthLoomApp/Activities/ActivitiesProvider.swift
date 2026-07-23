// ActivitiesProvider.swift
//
// WP-12b (implementation-plan.md) step 5: the one HealthKit-touching piece
// of the Activities view -- reads recent workouts (all sources, so watch
// workouts recorded by any app are first-class, architecture.md D13.1's
// "any app" posture carried into the UI) and reduces them to the pure
// `WorkoutSummary` shape `ActivityConsolidator` (ActivitiesModels.swift)
// consumes. Same completion-handler bridging as SyncKit's `HealthKitStore`/
// `HealthKitWatchCoverageProvider`, for the same reasons.
//
// Error/empty posture: any query failure (including HealthKit read
// authorization never granted -- reads never reveal denial, WP-06's rule)
// returns `[]`; the view then renders whatever `LocalSample` sessions exist
// standalone, so the screen degrades to "Fitbit activities only" rather
// than erroring.

import Foundation
import HealthKit

@MainActor
final class ActivitiesProvider {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    func recentWorkouts(daysBack: Int = 30, now: Date = Date()) async -> [WorkoutSummary] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        let start = now.addingTimeInterval(-Double(daysBack) * 24 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: [])

        let samples: [HKSample]
        do {
            samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(
                    sampleType: .workoutType(),
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
                ) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples ?? [])
                    }
                }
                healthStore.execute(query)
            }
        } catch {
            return [] // degrade -- see this file's header
        }

        return samples.compactMap { sample in
            guard let workout = sample as? HKWorkout else { return nil }
            let isHealthLoomImport = workout.metadata?["healthloom.externalID"] != nil
            // Same device-not-app classification rule as SyncKit's
            // `ProductTypeWorkoutSourceClassifier` (Conflict/
            // WatchCoverageProvider.swift) -- kept in lockstep by eye; the
            // resolver's copy is the load-bearing one.
            let isAppleWatch = (workout.sourceRevision.productType?.hasPrefix("Watch") ?? false)
                || (workout.device?.model.map { $0.contains("Watch") } ?? false)
            return WorkoutSummary(
                uuid: workout.uuid,
                activityName: Self.activityName(workout.workoutActivityType),
                start: workout.startDate,
                end: workout.endDate,
                sourceName: workout.sourceRevision.source.name,
                isHealthLoomImport: isHealthLoomImport,
                isAppleWatch: isAppleWatch
            )
        }
    }

    /// Display names for the activity types this app itself maps
    /// (TypeMapper's WP-12 table) plus a generic default -- deliberately not
    /// an exhaustive ~80-case `HKWorkoutActivityType` catalog.
    private static func activityName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Ride"
        case .swimming: return "Swim"
        case .hiking: return "Hike"
        case .traditionalStrengthTraining: return "Strength Training"
        case .yoga: return "Yoga"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .highIntensityIntervalTraining: return "HIIT"
        case .stairClimbing: return "Stair Climbing"
        case .coreTraining: return "Core Training"
        default: return "Workout"
        }
    }
}
