[![Build](https://github.com/wpowiertowski/healthloom.app/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/wpowiertowski/healthloom.app/actions?query=branch%3Amain)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Swift 6.0](https://img.shields.io/badge/swift-6.0-F05138.svg)](https://swift.org)
[![iOS 26](https://img.shields.io/badge/iOS-26-000000.svg)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-blue.svg)](https://developer.apple.com/swiftui/)
[![SwiftData](https://img.shields.io/badge/SwiftData-blue.svg)](https://developer.apple.com/swiftdata/)
[![HealthKit](https://img.shields.io/badge/HealthKit-blue.svg)](https://developer.apple.com/healthkit/)

# HealthLoom

Fitbit (and Fitbit Air) data, synced into Apple Health — with an AI coach you control.

---

## Overview

HealthLoom is a native iOS app that syncs Fitbit / Fitbit Air / Pixel Watch data from the
**Google Health API** into **Apple HealthKit**, so your health data lives in one place
even if your wearable isn't from Apple. It's built for the dual-wear user: a Fitbit worn
24/7 for baseline data (sleep, overnight HRV/SpO₂, resting HR, all-day steps) and an Apple
Watch worn for dedicated activities — HealthLoom consolidates the two instead of double
counting.

On top of that data, HealthLoom layers a **user-controlled AI coach**: on-device Apple
Foundation Models by default, with Claude, OpenAI, and Gemini available as opt-in cloud
providers. You write the system prompt; a non-editable safety suffix keeps clinical
topics pointed at an actual clinician.

## Features

Shipped (P0 + P1 — the sync pipeline):

- **Google Health OAuth (PKCE)** — `ASWebAuthenticationSession` consent flow, Keychain-backed token storage, single-flight refresh on 401
- **Typed Google Health v4 client** — `reconcile`/`dailyRollup` REST calls against `health.googleapis.com`, paged, with exponential backoff + jitter on 429/5xx
- **Full type mapping** — steps, heart rate, sleep, weight, SpO₂, HRV, blood glucose, hydration, body fat, nutrition, and ~13 exercise types mapped to their HealthKit equivalents, with unit conversion and rejection rules pinned by golden-file tests
- **Idempotent HealthKit writes** — every sample stamped with `HKMetadataKeyExternalUUID`; re-sync is diffed in batches, never one query per sample
- **High-water-mark + lookback sync cursor** — a fixed lookback window (72 h; 7 d for sleep) so late-arriving device data is never silently dropped
- **Historical backfill** — chunked, checkpointed, resumable walk-back (30 d / 90 d / 1 y / all) independent of incremental sync
- **Background sync** — `BGAppRefreshTask`-driven, with a diagnostics log and manual sync from Settings
- **Non-writable types surfaced in-app** — ECG, Active Zone Minutes, Irregular Rhythm Notifications stored locally and badged "not in Apple Health"
- **Onboarding + dashboard** — welcome → Google consent → HealthKit permission → first sync, then a per-type sync status dashboard

Architected, not yet built (see [Open Questions](#status--roadmap) below):

- Apple Watch-priority conflict resolution during overlapping workouts (D13)
- On-device AI coach (`CoachKit` is currently a placeholder package)
- Cloud AI providers (Claude / OpenAI / Gemini), prompt editor, chat UI

## Technology Stack

| Layer | Framework |
| --- | --- |
| UI | SwiftUI (`@Observable`, Approachable Concurrency, default `@MainActor`) |
| Data | SwiftData (`SyncState`, `LocalSample`, chat/knowledge models) |
| Health | HealthKit (reads for de-dup, writes for synced samples/workouts) |
| Device sync source | Google Health API (`health.googleapis.com/v4`) via OAuth 2.0 + PKCE |
| Secrets | Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) |
| Background work | BGTaskScheduler (`BGAppRefreshTask`) |
| On-device AI | Apple Foundation Models (`LanguageModelSession`), planned |
| Cloud AI | Claude / OpenAI / Gemini, provider-abstracted, opt-in, planned |
| Concurrency | Swift 6.2 strict concurrency (actors, `async`/`await`, `@concurrent`) |

## Architecture

```text
┌─────────────┐  BLE   ┌───────────────────┐  ~15 min   ┌───────────────────────┐
│ Fitbit Air  │ ─────▶ │ Google Health app │ ─────────▶ │ Google Health API     │
│ Pixel Watch │        │ (user's phone)    │    sync    │ health.googleapis…/v4 │
└─────────────┘        └───────────────────┘            └───────────┬───────────┘
                                                                    │ OAuth 2.0 + PKCE, reconcile reads
                                                                    ▼
                                                    ┌───────────────────────────────┐
                                                    │ HealthLoom (this app)         │
                                                    │ SyncEngine → TypeMapper       │
                                                    │ → ConflictResolver            │
                                                    │ → HealthKitWriter             │
                                                    └──┬──────────────────┬─────────┘
                                                       ▼                  ▼
                   Apple Watch ── native recording ──▶ Apple HealthKit    AI Coach
                   (workouts: GPS, dense HR)           (writable types)   (profile-only context)
```

Full write-up, including the twelve numbered design decisions (sync cursor semantics,
idempotency, watch-priority conflict resolution, privacy posture, AI context boundaries)
lives in [architecture.md](architecture.md).

## Project Structure

```text
HealthLoomApp/           SwiftUI app target — screens, DI wiring, BGTask registration
├── Onboarding/          Welcome → Google consent → HealthKit permission → first sync
├── Dashboard/           Per-type sync status
├── Backfill/            Historical backfill range picker + per-type progress
├── Settings/            Sync preferences, incremental consent scopes
└── Diagnostics/         Sync log viewer
Packages/                Local Swift packages, dependency-ordered (architecture.md §2)
├── CoreModel/            SwiftData models + shared value types — no I/O
├── Secrets/              Keychain wrapper (actor KeychainStore)
├── GoogleHealthClient/   OAuth (PKCE) + typed v4 REST client
├── SyncKit/              Pull → map → resolve conflicts → write pipeline + scheduling
└── CoachKit/              Provider abstraction, prompt/knowledge/context layers (placeholder)
HealthLoomTests/          Unit tests hosted in the app target (@testable import HealthLoom)
HealthLoomUITests/        XCUITest — onboarding + dashboard flows
Design/                  Yacht club design system reference (HTML + SwiftUI mockups)
```

## Testing

CI runs a per-package `swift test -Xswiftc -warnings-as-errors` matrix, then generates
the Xcode project via `xcodegen` and runs `xcodebuild build test` for the `HealthLoom`
scheme on an iOS Simulator — warnings fail the build in both stages. `make test` runs
the same package-by-package `swift test` + build locally; `make xcode` regenerates and
opens the project.

```bash
xcodegen generate                                     # regenerate HealthLoom.xcodeproj from project.yml
swift test --package-path Packages/SyncKit            # run a single package's tests
xcodebuild test -project HealthLoom.xcodeproj \
  -scheme HealthLoom -destination 'platform=iOS Simulator,name=iPhone 17'
```

| Package | Tests | Coverage |
| --- | --- | --- |
| CoreModel | 15 | SwiftData model relationships, defaults, Codable value types |
| Secrets | 14 | Keychain read/write/delete round-trip, accessibility attribute, missing-item handling |
| GoogleHealthClient | 35 | OAuth PKCE flow, token refresh, `reconcile`/`dailyRollup` decoding against real-shaped fixtures, retry/backoff |
| SyncKit | 228 | `TypeMapper` golden files per data type + rejection rules, `SyncEngine` idempotency/cursor/lookback, `HealthKitWriter` batched existence diff, backfill chunking/checkpointing, background scheduling, sync log redaction |
| CoachKit | 1 | Placeholder — provider abstraction not yet implemented |
| **HealthLoomUITests** | **2** | **XCUITest: onboarding happy path, dashboard sync states** |

## Requirements

- iOS 26 or later
- Xcode 26.4.1 or later (to build from source)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — `project.yml` is the source of truth; the `.xcodeproj` is not committed
- A Google Cloud OAuth client for the Google Health API (see [google-health-healthkit-base-knowledge.md](google-health-healthkit-base-knowledge.md))

## Status & Roadmap

P0 (foundations + first vertical slice) and P1 (full sync) are implemented — see
[progress.md](progress.md) for the per-work-package build log. Remaining phases, in
order, per [implementation-plan.md](implementation-plan.md):

- **WP-12b** — Apple Watch-priority conflict resolution (architecture.md D13)
- **P2** — on-device AI coach (`KnowledgeStore`, `ReadinessEngine`, chat UI)
- **P3** — cloud AI providers (Claude / OpenAI / Gemini) + key management
- **P4** — product polish, notifications, export/deletion, accessibility & launch checklist

## License

This project is licensed under the [MIT License](LICENSE).
