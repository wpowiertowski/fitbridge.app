// BackfillCoordinator.swift
//
// WP-15 (implementation-plan.md) / architecture.md §4 D5: "Historical
// backfill is a separate, chunked flow... BackfillCoordinator walks backward
// in ~30-day chunks per type, checkpointing progress in
// SyncState.backfillCursor, resumable across app kills, throttled to
// respect API quotas. Regular incremental sync (D3) starts immediately and
// is independent of backfill progress."
//
// ## Why this is a leaner, standalone pipeline rather than a call into
// ## `SyncEngine.sync(type:)`
//
// The task brief for this WP explicitly asks: "consider whether
// BackfillCoordinator can literally delegate a chunk's work to
// SyncEngine.sync(type:) with a synthetic window, or whether it needs its
// own leaner path." Read `SyncEngine.swift`/`SyncEngineTypes.swift` in full
// before deciding (per the handoff protocol) and found:
//
//   1. `SyncEngine.sync(type:)` takes **no window parameter at all** -- its
//      window is *always* derived internally from `SyncState.lastSyncedAt`
//      and `clock.now()` (`window.start = (lastSyncedAt ?? now -
//      initialWindow) - lookback(type)`, `window.end = now`, verbatim from
//      `performSync`). There is no way to hand it an arbitrary historical
//      `[start, end)` -- the plan's own illustrative "synthetic window"
//      phrasing doesn't correspond to any real parameter on the actual
//      method.
//   2. Even if it did, `sync(type:)` advances `SyncState.lastSyncedAt` (the
//      *incremental* high-water mark) on success -- backfill must never
//      touch that field. Backfill's own cursor is the entirely separate
//      `SyncState.backfillCursor` (CoreModel, WP-02), walking the opposite
//      direction (backward, toward the past) from a different starting
//      point (`min(lastSyncedAt, now)`, not `lastSyncedAt` itself). Forcing
//      backfill through `sync(type:)` would require either corrupting
//      `lastSyncedAt` with a backward-walking value (breaking D3's
//      high-water-mark contract for every future incremental sync) or a
//      structural rewrite of `SyncEngine` to parameterize its window and
//      choose which cursor field to persist -- exactly the kind of
//      "restructure" this WP was told to avoid for shared files.
//
// So `BackfillCoordinator` reuses everything *else* WP-09 established --
// `GoogleReconcileClient` (the exact same protocol, SyncEngineTypes.swift),
// `TypeMapper.map(_:)` (WP-07/11/12/13), `ConflictFiltering`/
// `IdentityConflictFilter` (the WP-12b seam), and `HealthKitWriter`'s
// batched existence-diff/save/upsert primitives (WP-08) -- but drives them
// itself, keyed on `backfillCursor` and an explicit chunk window it computes
// per call, rather than going through `SyncEngine`'s cursor-anchored
// `performSync`. `pullMapWrite`/`processPage` below are therefore a
// deliberate, small, parallel implementation of the same pull -> map ->
// conflict-filter -> existence-diff -> write/upsert shape
// `SyncEngine.performSync`/`.processPage` already implements -- not
// duplicated out of laziness, but because the two cursors' semantics
// (forward high-water-mark + lookback vs. backward chunk-walk +
// checkpoint) are genuinely different enough that sharing one method
// between them would need to parameterize away most of what makes each one
// correct. See progress.md's WP-15 entry for the full writeup and the one
// additive change this WP *did* make to `SyncEngine.swift` (`isBusy(for:)`,
// needed for step 2's suspend-during-incremental-sync rule, kept to a single
// method with no other restructuring).
//
// Guarded `#if canImport(HealthKit)`, identically to `SyncEngine.swift`
// (needs `HKObject`/`HKSampleType` and `HealthKitWriter` itself).
#if canImport(HealthKit)
import CoreModel
import Foundation
import GoogleHealthClient
import HealthKit
import SwiftData

/// Chunked, resumable, round-robin historical backfill across every
/// `GoogleDataType` this coordinator was configured with
/// (implementation-plan.md WP-15).
///
/// **Cursor semantics** (extends architecture.md D5 / D4 to the field WP-02
/// already reserved, `SyncState.backfillCursor`): a non-`nil` cursor is the
/// earliest point this type's backward walk has reached *so far* -- the
/// next chunk to pull is `[max(horizonDate, cursor - chunkDuration),
/// cursor)`. `nil` means either "never started" or "fully caught up to
/// whatever horizon was last completed" (honoring `SyncState.backfillCursor`'s
/// own doc comment literally); telling those two `nil` cases apart, and
/// resuming an "extend" (a deeper horizon chosen after a shallower one
/// completed) from the *old* horizon's boundary rather than from scratch,
/// is `BackfillHorizonRecordStore`'s one job (BackfillTypes.swift) -- see
/// that protocol's doc comment for the CoreModel-scope gap this papers over.
public actor BackfillCoordinator {
    private let types: [GoogleDataType]
    private let client: any GoogleReconcileClient
    private let writer: HealthKitWriter
    private let modelContainer: ModelContainer
    private let clock: any SyncClock
    private let sleeper: any BackoffSleeper
    private let conflictFilter: any ConflictFiltering
    private let horizonStore: any BackfillHorizonRecordStore
    private let busyProbe: any BackfillBusyProbe
    private let configuration: BackfillConfiguration

    private var horizon: BackfillHorizon
    private var isPaused = false
    private var runLoopTask: Task<Void, Never>?

    public init(
        types: [GoogleDataType],
        client: any GoogleReconcileClient,
        writer: HealthKitWriter,
        modelContainer: ModelContainer,
        clock: any SyncClock = SystemSyncClock(),
        sleeper: any BackoffSleeper = SystemSleeper(),
        conflictFilter: any ConflictFiltering = IdentityConflictFilter(),
        horizonStore: any BackfillHorizonRecordStore = UserDefaultsBackfillHorizonRecordStore(),
        busyProbe: any BackfillBusyProbe = AlwaysAvailableBusyProbe(),
        configuration: BackfillConfiguration = BackfillConfiguration(),
        horizon: BackfillHorizon = .defaultHorizon
    ) {
        self.types = types
        self.client = client
        self.writer = writer
        self.modelContainer = modelContainer
        self.clock = clock
        self.sleeper = sleeper
        self.conflictFilter = conflictFilter
        self.horizonStore = horizonStore
        self.busyProbe = busyProbe
        self.configuration = configuration
        self.horizon = horizon
    }

    // MARK: - Public control surface (WP-15 step 3: pause/resume/horizon picker)

    public func currentHorizon() -> BackfillHorizon { horizon }

    public func completedHorizon(for type: GoogleDataType) -> BackfillHorizon? {
        horizonStore.completedHorizon(for: type)
    }

    public var isPausedNow: Bool { isPaused }

    public func pause() {
        isPaused = true
    }

    public func resume() {
        isPaused = false
        start()
    }

    /// WP-15 step 3: "chosen horizon changeable (extending re-opens the
    /// walk)". Purely updates the in-actor target; the next
    /// `runNextChunk`/`runRound`/background-loop touch of each type
    /// re-derives its resume point against the new horizon (see
    /// `runNextChunk`'s "frontier" computation). Choosing a *shallower*
    /// horizon than one already completed is a safe no-op -- this
    /// coordinator never deletes previously-imported history.
    public func setHorizon(_ newHorizon: BackfillHorizon) {
        horizon = newHorizon
    }

    /// Starts (or restarts) the `.utility`-priority background walk (WP-15
    /// step 2). No-op if already running or currently paused.
    public func start() {
        guard runLoopTask == nil, !isPaused else { return }
        runLoopTask = Task(priority: .utility) { [self] in
            await runLoop()
        }
    }

    public func stop() {
        runLoopTask?.cancel()
        runLoopTask = nil
    }

    // MARK: - Status (WP-15 step 3: per-type progress UI)

    /// Live progress for `type`, derived fresh from `SyncState` +
    /// `BackfillHorizonRecordStore` + the current horizon on every call --
    /// never cached separately (the same "derive, don't duplicate" posture
    /// `Routing/ClinicalClassification.swift` documents).
    public func status(for type: GoogleDataType) async -> BackfillTypeStatus {
        let context = ModelContext(modelContainer)
        let now = clock.now()
        let syncState = fetchSyncState(for: type, context: context)
        let horizonDate = horizon.horizonDate(now: now)
        let completed = horizonStore.completedHorizon(for: type)
        let isComplete = syncState?.backfillCursor == nil
            && (completed?.coversAtLeastAsMuchHistoryAs(horizon) ?? false)
        let reachedDate: Date?
        if let cursor = syncState?.backfillCursor {
            reachedDate = cursor
        } else if let completed {
            reachedDate = completed.horizonDate(now: now)
        } else {
            reachedDate = nil
        }
        return BackfillTypeStatus(
            dataType: type,
            reachedDate: reachedDate,
            horizonDate: horizonDate,
            isComplete: isComplete,
            lastError: syncState?.lastStatus == "error" ? syncState?.lastError : nil
        )
    }

    public func statuses() async -> [BackfillTypeStatus] {
        var results: [BackfillTypeStatus] = []
        results.reserveCapacity(types.count)
        for type in types {
            results.append(await status(for: type))
        }
        return results
    }

    /// Whether every configured type has reached the current horizon.
    public func isFullyDone() async -> Bool {
        for type in types where await status(for: type).isComplete == false {
            return false
        }
        return true
    }

    // MARK: - Round-robin driver (WP-15 step 1: "process types round-robin
    // ... so one huge type doesn't starve others")

    /// Attempts exactly one chunk for each configured type, in `types`'
    /// order -- the "one chunk per type per round" fairness rule that
    /// guarantees no single type can consume more than one chunk before
    /// every other type gets a turn.
    @discardableResult
    public func runRound() async -> [GoogleDataType: BackfillChunkOutcome] {
        var results: [GoogleDataType: BackfillChunkOutcome] = [:]
        for type in types {
            results[type] = await runNextChunk(for: type)
        }
        return results
    }

    // MARK: - Per-type, per-chunk pipeline

    /// Advances `type`'s backfill by exactly one ~30-day chunk, or reports
    /// why it didn't run one. Public on its own (not just reachable via
    /// `runRound`) so tests can drive/assert individual types deterministically.
    @discardableResult
    public func runNextChunk(for type: GoogleDataType) async -> BackfillChunkOutcome {
        if isPaused { return .suspendedPaused }
        if await busyProbe.isBusy(for: type) { return .suspendedBusy }

        let context = ModelContext(modelContainer)
        let now = clock.now()
        let syncState = fetchOrCreateSyncState(for: type, context: context)
        let horizonDate = horizon.horizonDate(now: now)
        let completed = horizonStore.completedHorizon(for: type)

        // Already caught up to (at least) the current horizon. Checked via
        // the side-store, not `backfillCursor == nil` alone, since `nil` is
        // ambiguous between "never started" and "done" -- see
        // `BackfillHorizonRecordStore`'s doc comment (BackfillTypes.swift).
        if syncState.backfillCursor == nil, let completed, completed.coversAtLeastAsMuchHistoryAs(horizon) {
            return .alreadyDone
        }

        // Frontier = earliest point reached so far. Three cases:
        //   1. Mid-walk (`backfillCursor` set) -> resume from exactly there.
        //   2. Never started at all (`backfillCursor` nil, no completed
        //      horizon record) -> start from `min(lastSyncedAt, now)`,
        //      WP-15 step 1's literal starting point.
        //   3. "Extend" (`backfillCursor` nil, a *shallower* horizon already
        //      completed) -> resume from that old horizon's own boundary,
        //      continuing the walk further back instead of re-pulling
        //      everything from `min(lastSyncedAt, now)` again.
        let frontier: Date
        if let cursor = syncState.backfillCursor {
            frontier = cursor
        } else if let completed {
            frontier = completed.horizonDate(now: now)
        } else {
            frontier = min(syncState.lastSyncedAt ?? now, now)
        }

        guard frontier > horizonDate else {
            // Already at/beyond the horizon -- record completion rather
            // than issuing a zero-or-negative-width chunk (can happen right
            // after a narrowing `setHorizon` call, or a benign race between
            // two `runNextChunk` calls for the same type).
            syncState.backfillCursor = nil
            horizonStore.setCompletedHorizon(horizon, for: type)
            try? context.save()
            return .alreadyDone
        }

        let chunkEnd = frontier
        let chunkStart = max(horizonDate, chunkEnd.addingTimeInterval(-configuration.chunkDuration))

        do {
            let itemCount = try await pullMapWrite(type: type, start: chunkStart, end: chunkEnd, context: context)

            if chunkStart <= horizonDate {
                // This chunk reached the horizon -- fully caught up.
                syncState.backfillCursor = nil
                horizonStore.setCompletedHorizon(horizon, for: type)
            } else {
                syncState.backfillCursor = chunkStart
            }
            syncState.lastStatus = "ok"
            syncState.lastError = nil
            syncState.itemCount += itemCount
            try? context.save()
            return .processedChunk(window: chunkStart...chunkEnd, itemCount: itemCount)
        } catch {
            // Cursor deliberately left untouched -- same "leave it, retry
            // safely" posture as SyncEngine's incremental cursor
            // (architecture.md D3/D4's idempotency makes re-pulling this
            // exact chunk next round harmless).
            let message = String(describing: error)
            syncState.lastStatus = "error"
            syncState.lastError = message
            try? context.save()
            return .failed(message)
        }
    }

    // MARK: - Background driver

    private func runLoop() async {
        while !Task.isCancelled, !isPaused {
            if await isFullyDone() { break }
            _ = await runRound()
            if Task.isCancelled || isPaused { break }
            if await isFullyDone() { break }
            try? await sleeper.sleep(seconds: configuration.interChunkDelay)
        }
        runLoopTask = nil
    }

    // MARK: - Pull -> map -> conflict-filter -> write/upsert (one chunk window)

    /// Parallels `SyncEngine`'s own pull/map/write pipeline
    /// (`performSync`/`processPage`, SyncEngine.swift) -- see this file's
    /// header for why this is a standalone implementation rather than a
    /// shared call. Applies the same D4 batched-existence-diff invariant
    /// (one query per (type, chunk window), computed once, threaded through
    /// every page of this chunk) and the same `.workout`/`.correlation`/
    /// `.localOnly`/`.skip` routing `SyncEngine.processPage` uses.
    private func pullMapWrite(
        type: GoogleDataType,
        start: Date,
        end: Date,
        context: ModelContext
    ) async throws -> Int {
        // `await`: `.writability` is a MainActor-isolated computed property
        // (CoreModel's `.defaultIsolation(MainActor.self)`) -- same crossing
        // `SyncEngine.swift`'s header documents.
        let writability = await type.writability
        var hkSampleType: HKSampleType?
        if case .healthKit(let identifier) = writability {
            hkSampleType = try? await HealthKitObjectTypeResolver.sampleType(for: identifier)
        }

        var knownExternalIDs: Set<String> = []
        if let hkSampleType {
            knownExternalIDs = try await writer.existingExternalIDs(type: hkSampleType, start: start, end: end)
        }

        var totalItemCount = 0
        var pageToken: String?
        repeat {
            let page = try await client.reconcile(type: type, since: start, until: end, pageToken: pageToken)
            totalItemCount += try await processPage(page.points, knownExternalIDs: &knownExternalIDs, context: context)
            pageToken = page.nextPageToken
        } while pageToken != nil

        return totalItemCount
    }

    private func processPage(
        _ points: [GoogleDataPoint],
        knownExternalIDs: inout Set<String>,
        context: ModelContext
    ) async throws -> Int {
        var batch: [HKObject] = []
        var newExternalIDs: [String] = []
        var localOnlyPoints: [GoogleDataPoint] = []
        var skipCount = 0

        for point in points {
            let mapped = await conflictFilter.resolve(await TypeMapper.map(point), for: point)
            switch mapped {
            case .quantity(let sample):
                guard !knownExternalIDs.contains(point.id) else { continue }
                batch.append(sample)
                newExternalIDs.append(point.id)
            case .category(let samples):
                guard !knownExternalIDs.contains(point.id) else { continue }
                batch.append(contentsOf: samples)
                newExternalIDs.append(point.id)
            case .correlation(let correlation):
                guard !knownExternalIDs.contains(point.id) else { continue }
                batch.append(correlation)
                newExternalIDs.append(point.id)
            case .workout:
                // Same "not yet wired into this pipeline" posture as
                // `SyncEngine.processPage`'s own `.workout` case -- see that
                // method's doc comment (SyncEngine.swift) for the full
                // explanation. Deliberately mirrored, not diverged from.
                skipCount += 1
            case .localOnly:
                localOnlyPoints.append(point)
            case .skip:
                skipCount += 1
            }
        }

        if !batch.isEmpty {
            try await writer.save(batch)
            knownExternalIDs.formUnion(newExternalIDs)
        }

        for point in localOnlyPoints {
            upsertLocalSample(for: point, context: context)
        }

        return newExternalIDs.count + localOnlyPoints.count + skipCount
    }

    // MARK: - SwiftData bookkeeping (mirrors SyncEngine.swift's own helpers)

    private func fetchSyncState(for type: GoogleDataType, context: ModelContext) -> SyncState? {
        let key = type.rawValue
        let descriptor = FetchDescriptor<SyncState>(predicate: #Predicate { $0.dataType == key })
        return try? context.fetch(descriptor).first
    }

    private func fetchOrCreateSyncState(for type: GoogleDataType, context: ModelContext) -> SyncState {
        if let existing = fetchSyncState(for: type, context: context) {
            return existing
        }
        let created = SyncState(dataType: type.rawValue)
        context.insert(created)
        return created
    }

    /// Identical shape/semantics to `SyncEngine.upsertLocalSample` -- fetch
    /// first, mutate in place, never blind-reinsert, so
    /// `linkedWatchWorkoutUUID` (set later by WP-12b's `ConflictResolver`)
    /// is never clobbered back to `nil` by a backfill chunk re-touching a
    /// point a foreground sync already upserted, or vice versa.
    private func upsertLocalSample(for point: GoogleDataPoint, context: ModelContext) {
        let externalID = point.id
        let payload = BackfillLocalPayload(point: point)
        let payloadJSON = (try? JSONEncoder().encode(payload)) ?? Data()
        let sourceLabel = point.source.deviceDisplayName ?? point.source.platform ?? "unknown"
        let dataTypeKey = point.dataType.rawValue

        let descriptor = FetchDescriptor<LocalSample>(predicate: #Predicate { $0.externalID == externalID })
        if let existing = try? context.fetch(descriptor).first {
            existing.dataType = dataTypeKey
            existing.payloadJSON = payloadJSON
            existing.start = point.start
            existing.end = point.end
            existing.source = sourceLabel
        } else {
            context.insert(
                LocalSample(
                    externalID: externalID,
                    dataType: dataTypeKey,
                    payloadJSON: payloadJSON,
                    start: point.start,
                    end: point.end,
                    source: sourceLabel
                )
            )
        }
    }
}

/// Same minimal, self-contained shape as `SyncEngine`'s own
/// `SyncEngineLocalPayload` (SyncEngine.swift) -- deliberately not shared
/// (that type is `private` to its own file, and WP-14 owns the real
/// per-type payload schema regardless, per that file's own doc comment).
nonisolated private struct BackfillLocalPayload: Codable {
    var id: String
    var dataType: String
    var start: Date
    var end: Date
    var values: [String: Double]
    var sessionPayload: Data?
    var sourcePlatform: String?
    var sourceDeviceDisplayName: String?
    var sourceRecordingMethod: String?

    init(point: GoogleDataPoint) {
        self.id = point.id
        self.dataType = point.dataType.rawValue
        self.start = point.start
        self.end = point.end
        self.values = point.values
        self.sessionPayload = point.sessionPayload
        self.sourcePlatform = point.source.platform
        self.sourceDeviceDisplayName = point.source.deviceDisplayName
        self.sourceRecordingMethod = point.source.recordingMethod
    }
}
#endif
