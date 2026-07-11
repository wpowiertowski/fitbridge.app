// ClinicalClassification.swift
//
// WP-14 (implementation-plan.md): architecture.md D8 -- "Clinical signals are
// excluded from AI context by default." ECG and Irregular Rhythm
// Notification are clinical; Active Zone Minutes and Active Minutes (the
// other two `.localOnly`-writability types, architecture.md D2) are not.
//
// Deliberately its own `Routing/` subfolder rather than living in
// `TypeMapper/`: WP-13 is concurrently editing every file under
// `TypeMapper/` (nutrition correlations) and this WP's handoff brief calls
// that folder off-limits to avoid a file collision. Nothing here depends on
// `TypeMapper.swift`/`MappedTypes.swift` -- this is a standalone
// classification over `GoogleDataType`, usable independently of the mapping
// pipeline.
//
// This is a free function over `GoogleDataType`, not a stored field on
// `LocalSample` (CoreModel) -- deliberately. `LocalSample.dataType` (a
// `GoogleDataType.rawValue` string) already carries enough information to
// derive clinical-ness at read time, so adding a redundant `isClinical`
// column to that model would just be a second copy of the same fact that
// could drift out of sync with this table. See progress.md's WP-14 entry for
// the full reasoning (CoreModel is out of this WP's scope regardless -- it's
// owned by WP-02/other WPs -- so this "derive, don't duplicate" choice also
// sidesteps needing a CoreModel change at all). `ProfileField.isClinical`
// (`ProfileField.swift`, WP-02) is the analogous flag one layer up in the
// `KnowledgeProfile`/`HealthContext` pipeline; once WP-19/20 build the code
// that turns a `LocalSample` into a `ProfileField`, it should call this
// function rather than re-deriving the ECG/IRN list a second time.
//
// `nonisolated`: unlike CoreModel's `GoogleDataType.writability` (a computed
// property declared inside a module with `.defaultIsolation(MainActor.self)`,
// and so itself MainActor-isolated -- see TypeMapper.swift's header for the
// precedent), this function only pattern-matches against the `GoogleDataType`
// value it's handed -- no isolated computed property is touched -- so it's
// marked `nonisolated` explicitly, making it callable synchronously from
// anywhere: SyncEngine's own distinct actor, plain `swift test` targets, and
// a future MainActor-isolated dashboard/ContextAssembler call site alike,
// with no `await` required at any of them.

import CoreModel

/// Whether `type` is a clinical signal per architecture.md D8: `true` for
/// ECG and Irregular Rhythm Notification, `false` for every other
/// `GoogleDataType` -- including the other two `.localOnly`-writability
/// types (Active Zone Minutes, Active Minutes), which are non-clinical
/// activity signals, and every `.healthKit`/`.skip` type.
public nonisolated func isClinicalType(_ type: GoogleDataType) -> Bool {
    switch type {
    case .electrocardiogram, .irregularRhythmNotification:
        return true
    default:
        return false
    }
}

/// Convenience overload for callers holding a `LocalSample.dataType` raw
/// string (persisted as `GoogleDataType.rawValue`, e.g. by `SyncEngine
/// .upsertLocalSample`) rather than the enum itself -- e.g. the dashboard's
/// per-type grouping over `@Query`-fetched `LocalSample` rows. Returns
/// `false` for a string that doesn't decode to a known `GoogleDataType`:
/// forward-compatible posture (an unrecognized/future raw value is never
/// treated as clinical by default) matching `TypeMapper`'s own "never crash,
/// just skip" rule for unmapped types.
public nonisolated func isClinicalType(rawDataType: String) -> Bool {
    GoogleDataType(rawValue: rawDataType).map(isClinicalType) ?? false
}
