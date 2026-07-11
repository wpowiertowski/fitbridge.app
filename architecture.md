# Architecture — FitBridge

iOS app that syncs Fitbit / Fitbit Air / Pixel Watch data from the **Google Health API**
into **Apple HealthKit**, and layers a user-controlled **AI coach** on top (on-device
Apple Foundation Models by default; Claude / OpenAI / Gemini as opt-in cloud providers).

**Target user & wear pattern:** the core user wears a **Fitbit (Air) 24/7** for baseline
data (sleep, overnight HRV/SpO₂, resting HR, all-day steps) and puts on an **Apple Watch
for dedicated activities** (running, swimming, cycling, …). Apple Watch records natively
into HealthKit with higher fidelity — explicit start/stop, GPS, dense HR. FitBridge's job
is therefore twofold: import the Fitbit 24/7 baseline into Apple Health, and **consolidate
overlapping activity data with Apple Watch as the priority source** (see D13).

Companion docs:
- [google-health-healthkit-base-knowledge.md](google-health-healthkit-base-knowledge.md) — API facts and the type-mapping table (source of truth for data types).
- [implementation-plan.md](implementation-plan.md) — phased work packages implementing this architecture.
- [test-plan.md](test-plan.md) — unit/integration/UI/manual testing strategy.
- [fitbridge-final-yachtclub.html](fitbridge-final-yachtclub.html), [FitBridgeTodayView-YachtClub.swift](FitBridgeTodayView-YachtClub.swift) — final "Today" screen design (Yacht club palette).

**Naming:** the product, app target, and module prefix are all **FitBridge**
(`FitBridge` target, `fitbridge.*` metadata keys, `com.fitbridge.*` identifiers).

---

## 1. System context

```
┌────────────┐  BLE   ┌──────────────────┐  ~15 min   ┌─────────────────────┐
│ Fitbit Air │ ─────▶ │ Google Health app │ ─────────▶ │ Google Health API    │
│ Pixel Watch│        │ (user's phone)    │   sync     │ health.googleapis…/v4│
└────────────┘        └──────────────────┘            └──────────┬──────────┘
                                                                 │ OAuth 2.0 + PKCE, reconcile reads
                                                                 ▼
                                                    ┌───────────────────────────┐
                                                    │  FitBridge (this app)     │
                                                    │  SyncEngine → TypeMapper  │
                                                    │  → ConflictResolver       │
                                                    │  → HealthKitWriter        │
                                                    └───────┬──────────┬────────┘
                                                            ▼          ▼
                    Apple Watch ── native recording ──▶ Apple HealthKit   AI Coach
                    (workouts: GPS, dense HR)        (writable types)  (profile-only context)
```

Consequences of the upstream design:
- **Data is not real-time.** Devices sync through the Google Health app roughly every
  15 minutes while that app is open. The UI must show *data freshness* ("synced 9m ago"),
  never imply live streaming.
- **Late-arriving data is normal.** A watch can sync hours-old samples at any time, so a
  pure high-water-mark cursor loses data (see D3).
- **We never own the data.** Google is the source of truth for device data; HealthKit is
  the user-facing destination; the app keeps almost nothing itself (see D2).
- **HealthKit already contains a second recorder.** Apple Watch writes workouts and
  samples into HealthKit independently of us. Because the user wears the Fitbit during
  watch-recorded activities too, naive import double-counts; conflict resolution (D13)
  is a first-class pipeline stage, not an afterthought.

## 2. Module map

Local Swift packages, dependency-ordered (each depends only on packages above it):

| Package | Responsibility | Key types |
|---|---|---|
| `CoreModel` | SwiftData models + shared value types. No I/O. | `SyncState`, `LocalSample`, `KnowledgeProfile`, `DerivedInsight`, `PromptVersion`, `ChatTurn`, `ContextSnapshot`, `GoogleDataType`, `HealthContext` |
| `Secrets` | Keychain wrapper. | `actor KeychainStore` |
| `GoogleHealthClient` | OAuth (PKCE) + typed REST client for `health.googleapis.com/v4/`. | `actor GoogleAuthManager`, `GoogleHealthClient`, `GoogleDataPoint` |
| `SyncKit` | Pull → map → resolve conflicts → write pipeline + scheduling. | `TypeMapper`, `WatchCoverageIndex`, `ConflictResolver`, `HealthKitWriter`, `actor SyncEngine`, `BackfillCoordinator`, `SyncScheduler` |
| `CoachKit` | Provider abstraction, prompt/knowledge/context layers, readiness. | `CoachProvider`, `ProviderRegistry`, `PromptManager`, `KnowledgeStore`, `ContextAssembler`, `ReadinessEngine`, `CoachOrchestrator` |
| App target `FitBridge` | SwiftUI screens, app lifecycle, DI wiring, BGTask registration. | `TodayView`, `ActivitiesView`, `CoachView`, `YouView`, `SettingsView`, onboarding |

Rules:
- Packages never import each other sideways (`SyncKit` doesn't know `CoachKit` exists).
- Only the app target imports SwiftUI screens together; packages expose plain APIs.
- `CoachKit` reads health data **only** through `KnowledgeStore` (HealthKit queries +
  `LocalSample`), never through `GoogleHealthClient`.

## 3. Concurrency model (Swift 6.2)

- App target: Approachable Concurrency + default `@MainActor` isolation (Xcode 26 default).
  Views and view models are main-actor by default.
- Packages opt in via `Package.swift` (`.defaultIsolation(MainActor.self)` etc. — packages
  don't inherit app settings).
- Off-main work is explicit: `actor SyncEngine`, `actor GoogleAuthManager`,
  `actor KeychainStore`; networking and HealthKit batch writes are `@concurrent` /
  actor-isolated.
- `SyncEngine` serializes per-data-type sync so foreground + background triggers can't
  interleave; a `Set<GoogleDataType>` of in-flight types drops duplicate requests.
- Strict Concurrency = Complete everywhere; warnings are fixed, not suppressed.

## 4. Key design decisions

**D1 — Google `reconcile` is the only read path for device data.**
It merges/de-dupes across sources (Pixel Watch + Fitbit Air) server-side. Using `list`
would force client-side cross-device dedupe. `dailyRollup` is used additionally for
daily-summary types because it stitches days correctly across DST/time-zone travel.

**D2 — No local mirror of HealthKit-writable data.**
Writable types flow Google → HealthKit directly; the app persists only bookkeeping
(`SyncState`) — not sample values. `LocalSample` exists **only** for types HealthKit can't
accept (ECG, Active Zone Minutes, Irregular Rhythm Notifications). This keeps the app's
attack/privacy surface minimal and avoids a three-way consistency problem. The
`KnowledgeStore` reads back from HealthKit (+ `LocalSample`) as the single local source.

**D3 — Sync cursor = high-water mark + fixed lookback window.**
Each type keeps `lastSyncedAt`, but every sync pulls `since: lastSyncedAt − lookback`
(default 72 h; sleep 7 d, since sleep sessions finalize late). Late-arriving device data
falls inside the window; the idempotency key (D4) makes re-pulling overlap free. A pure
high-water mark would silently drop any sample synced late by the device.

**D4 — Idempotency via external ID metadata.**
Every HealthKit sample is stamped with `HKMetadataKeyExternalUUID` = Google data-point ID
plus `fitbridge.sourceDevice`. Re-sync skips existing IDs; "update" = delete-by-external-ID +
re-insert (HK samples are immutable); "disconnect & wipe" = delete-by-source.
Existence checks are **batched**: one HK query per (type, time window) collects present
external IDs into a `Set`, then the page is diffed in memory — never one query per sample.

**D5 — Historical backfill is a separate, chunked flow.**
First connect offers a backfill range (90 days default; 30 d / 90 d / 1 y / all).
`BackfillCoordinator` walks backward in ~30-day chunks per type, checkpointing progress in
`SyncState.backfillCursor`, resumable across app kills, throttled to respect API quotas.
Regular incremental sync (D3) starts immediately and is independent of backfill progress.

**D6 — Readiness is computed deterministically, never by the LLM.**
The Today hero ("82/100") comes from `ReadinessEngine`: a documented, unit-testable
formula over HRV vs 30-day baseline, resting HR vs baseline, last-night sleep
duration/efficiency, and prior-day strain — with graceful degradation when inputs are
missing (score renders with a "based on N of 4 signals" note). The coach may *explain*
the score (it's in the `KnowledgeProfile`), never invent it. Rationale: trust, testability,
and identical behavior across AI providers.

**D7 — AI context = `KnowledgeProfile` only, plus tools; never raw dumps.**
`ContextAssembler` builds `HealthContext` exclusively from the human-readable,
source-tagged, timestamped `KnowledgeProfile`, honoring the user's per-field exclusions.
The model pulls specifics on demand through typed tools (`getRecentSleep`, `getSteps`, …)
that also route through `KnowledgeStore`. Every AI turn stores a `ContextSnapshot` of the
exact context sent, powering the "What did the coach see?" trace UI.

**D8 — Clinical signals are excluded from AI context by default.**
ECG, AFib / Irregular Rhythm Notifications are stored (`LocalSample`) and shown in-app
with a "not in Apple Health" badge, but are **off by default** in the AI context and the
immutable `SafetyLayer` prompt suffix instructs the coach to decline interpreting them and
point to a clinician. Users can opt clinical fields in, but the safety suffix still applies.

**D9 — Provider abstraction with two routes, one UI.**
`CoachProvider` is the app-level seam. `AppleFoundationProvider` wraps
`LanguageModelSession`. Cloud providers prefer official `LanguageModel` packages (WWDC 26
unified route) when shipping, else a direct REST client conforming to `CoachProvider`.
The chat UI, prompt layer, tools, and safety layer are provider-agnostic. Cloud providers
are disabled until the user supplies an API key (Keychain) **and** passes a per-provider
consent screen naming exactly what leaves the device and where it goes.

**D10 — Effective system prompt = user-editable base + immutable safety suffix.**
Users can rewrite the coach's persona/instructions; the `SafetyLayer` (non-medical
disclaimer, scope limits, clinical-refusal rules) is appended after user content and is
not editable. The Prompt Editor shows the exact final string — nothing hidden.

**D11 — Privacy posture.**
- Tokens and API keys: Keychain, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- SwiftData store: `NSFileProtectionComplete` (it holds `LocalSample` clinical events and
  chat history).
- Logs / analytics / crash reports carry counts, types, and timestamps — never health
  values, never tokens.
- Network egress allowlist: `health.googleapis.com`, `oauth2.googleapis.com`, and the
  chosen AI provider's host only (verified in testing, see test plan).
- On-device AI is the default; every cloud hop is explicit opt-in.

**D12 — UI is design-locked to the Yacht club system.**
The HTML/Swift mockups are the spec: `Theme` tokens, tick-scale instrument, hairline
panels, single rust accent. Two deviations are mandated for production: (a) typography
moves from fixed-size Helvetica Neue to Dynamic-Type-scaling fonts (`ScaledMetric` /
text styles with a Helvetica-like face) for accessibility; (b) a dark-mode variant of the
palette is added (the mockup is light-only). Metric rows are user-reorderable (Edit mode);
order persists in `UserDefaults`.

**D13 — Apple Watch data wins during recorded activities; Fitbit is the 24/7 baseline.**
The target wear pattern (§ intro) means both devices record the same workout
simultaneously. Apple Watch data is more precise (deliberate start/stop, GPS routes,
dense HR), so it is the priority source wherever it exists; Fitbit fills everything else
(sleep, overnight vitals, all-day steps, watch-off periods). Mechanics:

1. **`WatchCoverageIndex`** queries HealthKit for coverage windows: workouts whose source
   device is an Apple Watch (any app, not just Apple's Workout app), padded ± 5 min.
   Source detection sits behind a protocol seam so tests can inject windows.
2. **Session-level:** an incoming Google Exercise session that overlaps a watch workout
   (≥ 50 % of the shorter duration, or start *and* end within 10 min) is **not** written
   as an `HKWorkout`. It is kept in `LocalSample`, linked to the watch workout's UUID,
   and surfaces in the in-app **Activities view** as one consolidated activity: watch
   workout primary, Fitbit fields shown only where they add something (e.g. Active Zone
   Minutes, recovery metrics) — supplement, never duplicate.
3. **Stream-level:** Fitbit samples of watch-covered quantity types (heart rate, active
   energy, steps, distance) whose interval falls inside a coverage window are suppressed
   (not written) — the watch already recorded them at higher fidelity. Outside coverage
   windows they import normally; since suppressed and imported intervals never overlap,
   Apple Health day totals compose correctly (watch during workout + Fitbit rest of day).
4. **Ordering hazard:** usually the watch workout lands in HealthKit (minutes) before the
   Fitbit data reaches the Google API (~15 min+), but not always (watch away from phone).
   Every sync therefore re-evaluates its lookback window (D3) against the *current*
   coverage index and retroactively deletes app-written samples/workouts that now conflict
   — the same delete-by-external-ID machinery as D4.
5. **User control:** Settings toggle "Prefer Apple Watch during workouts", default ON.
   OFF ⇒ everything imports and Apple Health's own source-priority ordering governs.
6. **Coach:** no special casing needed — `KnowledgeStore` reads HealthKit, so watch
   workouts are first-class inputs; Fitbit-only supplements come via `LocalSample`.
   The profile describes activities from the consolidated view, never both copies.

## 5. Data flow summaries

**Sync (incremental):** trigger (foreground / BGAppRefresh / manual) → `SyncEngine.sync(type)`
→ `GoogleHealthClient.reconcile(type, since: cursor − lookback)` (paged) → normalize units
(mm→m, etc.) → `TypeMapper.toHealthKit` (nil ⇒ `LocalSample` for ⚠ types, skip for ❌) →
`ConflictResolver` (drop samples/sessions inside watch coverage windows, D13; retroactively
delete now-conflicting app-written samples in the lookback window) → batched existence
diff → `HealthKitWriter.save(batch)` → advance `SyncState` → refresh UI.

**Coach turn:** user message → `CoachOrchestrator` → `PromptManager.effectivePrompt`
(+ SafetyLayer) + `ContextAssembler.context()` (exclusions applied, snapshot stored) →
selected `CoachProvider` (streaming) → tool calls routed to `KnowledgeStore` → reply
persisted as `ChatTurn` linked to its `ContextSnapshot`.

**Morning insight:** overnight BG sync completes → `ReadinessEngine.score()` →
`CoachOrchestrator.dailyInsight()` with `@Generable DailyInsight` (structured output) →
local notification → Today view coach panel.

## 6. Error & edge-case posture

| Situation | Behavior |
|---|---|
| Google 401 | Single-flight token refresh (actor-serialized); hard failure ⇒ re-consent UI state |
| Google 429 / 5xx | Exponential backoff + jitter; per-type; sync marked `error` with retry time |
| Workspace Google account | Detected post-consent; clear "personal accounts only" screen; sign-out |
| HealthKit write denied | Detectable for writes (`sharingDenied`): per-type badge + Settings deep-link; reads: code defensively, HK never reveals denial |
| Apple Intelligence unavailable | Availability-gated coach; explain state (`deviceNotEligible` / `notEnabled` / `modelNotReady`); offer cloud providers as fallback |
| Google-side deletions | Not tombstoned by the API; weekly reconciliation pass re-pulls a trailing 30-day window and removes app-written HK samples whose external ID no longer exists upstream |
| App killed mid-backfill | `backfillCursor` checkpoint per chunk ⇒ resume |
| Watch workout appears *after* Fitbit data was imported | Retroactive cleanup in the next sync's lookback window deletes the conflicting app-written samples/workout (D13.4) |
| User records a workout with Fitbit only (no watch) | No coverage window ⇒ full Fitbit session imports as `HKWorkout`, streams import normally |
| Time-zone travel / DST | Daily aggregates come from `dailyRollup` (server-stitched); samples carry absolute timestamps |

## 7. Open questions (decide before the affected phase)

1. **Webhook backend** (P4, optional): serverless receiver + APNs silent push vs polling
   only. Ship v1 polling-only; revisit with real usage data.
2. **Readiness formula weights** — start with the documented default in `ReadinessEngine`,
   tune during beta; weights are a constant table, not code changes.
3. **D13 overlap thresholds** (50 % / 10 min / ±5 min padding) — defaults chosen for
   auto-detected Fitbit sessions vs deliberate watch workouts; validate against real
   dual-wear data during beta and tune the constants.
