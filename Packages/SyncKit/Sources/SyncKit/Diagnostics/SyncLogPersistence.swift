// SyncLogPersistence.swift
//
// WP-18 (implementation-plan.md): durability seam for `SyncLogStore`'s ring
// buffer, mirroring this package's established "narrow protocol + real
// conformer + test conformer" house style (`GoogleReconcileClient`/
// `HealthStoreProtocol`/`BackfillHorizonRecordStore`, ...).
//
// **Chosen persistence mechanism: one JSON file under Application Support,
// not a second SwiftData model/`ModelContainer`.** WP-18's brief offers
// either "SwiftData-backed via a new lightweight model, OR a simple
// file-backed ring buffer -- your choice, document why." A SwiftData model
// would need to join `CoreModel.modelTypes`'s schema list to share the
// app's one `ModelContainer` (CoreModel.swift) -- `CoreModel` is explicitly
// read-only for this WP -- or stand up an entirely separate second
// `ModelContainer`/store file purely to hold one flat, non-relational
// record type that's never queried by anything except this file's own
// eviction logic and the Settings viewer's list. That's materially more
// machinery (a second store, its own file-protection setup, SwiftData's
// fetch/sort/delete dance to implement "evict oldest past a cap") than a
// capped `[SyncLogEntry]` array encoded as one JSON file needs -- ring-
// buffer eviction here is a two-line array operation (`append`, then
// `removeFirst(overflow)`, see `SyncLogStore.swift`), not a query.
// File-backed still gets the same `NSFileProtectionComplete` treatment
// `CoreModel.swift` applies to its own on-disk store (architecture.md D11),
// applied identically below.
import Foundation

/// Load/save seam for `SyncLogStore`'s backing array. `nonisolated` so a
/// conformer's own actor affinity (or lack of one) never blocks satisfying
/// the requirement -- same rationale as this package's other protocol seams
/// (`BackfillHorizonRecordStore.swift`'s doc comment makes the identical
/// argument for its own, unrelated side-store).
public protocol SyncLogPersisting: Sendable {
    nonisolated func load() -> [SyncLogEntry]
    nonisolated func save(_ entries: [SyncLogEntry])
}

/// Test/preview double: never touches disk, `load()` always returns `[]`.
/// Mirrors `AlwaysAvailableBusyProbe`'s "no-op default" shape
/// (Backfill/BackfillTypes.swift).
nonisolated public struct NullSyncLogPersistence: SyncLogPersisting {
    public init() {}
    public func load() -> [SyncLogEntry] { [] }
    public func save(_ entries: [SyncLogEntry]) {}
}

/// Production store: one JSON file, `Application Support/FitBridge/SyncLog.json`
/// -- the same parent directory `CoreModel.swift`'s `productionStoreURL()`
/// uses for `CoreModel.store`, kept as a sibling file rather than inside the
/// SwiftData store itself (CoreModel's schema is closed to this WP, per its
/// own scope fence). `@unchecked Sendable` + an internal lock: this class is
/// shared (indirectly, via `SyncLogStore`'s actor isolation) but its own
/// synchronous file I/O needs no `async` seam, mirroring
/// `UserDefaultsBackfillHorizonRecordStore`'s identical `@unchecked
/// Sendable` posture for the same "known-safe, not statically provable"
/// reason (Backfill/BackfillTypes.swift's doc comment).
nonisolated public final class FileSyncLogPersistence: SyncLogPersisting, @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()

    public init(fileURL: URL = FileSyncLogPersistence.defaultFileURL()) {
        self.fileURL = fileURL
    }

    public static func defaultFileURL() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        let directory = base.appending(path: "FitBridge", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "SyncLog.json", directoryHint: .notDirectory)
    }

    public func load() -> [SyncLogEntry] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([SyncLogEntry].self, from: data)) ?? []
    }

    public func save(_ entries: [SyncLogEntry]) {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
        applyCompleteFileProtection()
    }

    /// Same treatment as `CoreModel.swift`'s `applyCompleteFileProtection` --
    /// a real guarantee on-device (iOS), a documented no-op on the macOS
    /// host this package's tests run on (see that file's own doc comment
    /// for why the `#if os(iOS)` guard is honest about platform behavior,
    /// not a missed case).
    private func applyCompleteFileProtection() {
        #if os(iOS)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: fileURL.path
        )
        #endif
    }
}
