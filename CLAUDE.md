# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
swift build                              # debug build
swift test                               # full suite (must stay green before commit)
swift test --filter ResetFormatterTests  # one test class
swift test --filter ResetFormatterTests/testWeeklyCountdown  # one test method
./Scripts/bundle.sh                      # build AILimitBar.app (release, ad-hoc signed)
```

There is no separate lint step; `swift build` is the type/warning gate. CI (`.github/workflows/ci.yml`) runs build → test → bundle on `macos-latest` for every push to `main` and every PR.

## Release flow

The app version lives **only** in `Scripts/Info.plist` (`CFBundleShortVersionString` + `CFBundleVersion`) — there is no version constant in Swift. To cut a release: bump both keys, `./Scripts/bundle.sh`, then `ditto -c -k --sequesterRsrc --keepParent AILimitBar.app AILimitBar-<v>.zip`, annotated `git tag`, and `gh release create` with the zip asset. Builds are ad-hoc signed (not notarized), so each new build changes the signature and re-triggers the macOS Keychain prompt for the user.

## Architecture

A SwiftUI + AppKit menu-bar app (`NSStatusItem`, no dock icon). Two SwiftPM targets: `AILimitBarKit` (all logic + UI, testable library) and `AILimitBar` (thin executable). `swift-tools-version: 6.0` but sources compile in **Swift 5 language mode** — treat concurrency accordingly.

### Data flow (the spine)

```
QuotaProvider (per vendor)  →  QuotaStore (state machine, polling)  →  ProviderHub (N stores)  →  StatusItemController / SwiftUI views
```

- **`QuotaProvider`** (`Core/Models.swift`) — the vendor adapter protocol: `fetchSnapshot() async throws -> QuotaSnapshot`. One implementation per vendor under `Providers/<Vendor>/` (Claude and Codex are live). Each provider reads only its own CLI's local credentials and hits a single HTTPS usage endpoint. **Read-only, always**: never write/refresh tokens, never log or print them, no telemetry.
- **`QuotaStore`** (`Core/QuotaStore.swift`) — `@Observable @MainActor` wrapper owning one provider. Holds the `State` enum (`loading`/`ready`/`credentialsMissing`/`tokenExpired`/`offline`), 60s polling, and exponential-backoff retry. While `offline`, the poll timer must NOT also fire (`shouldPollTickRefresh`) so the request rate backs off instead of doubling.
- **`ProviderHub`** (`Core/ProviderHub.swift`) — `@Observable @MainActor`, owns one `QuotaStore` per *enabled live* provider. `sync(enabled:)` starts/stops stores; disabling a provider drops its store (not hides it). `hottest(pin:)` picks the provider needing the most attention (highest severity ≥ warn) for the menu-bar tooltip and the popover's opening tab.
- **`StatusItemController`** (`App/StatusItemController.swift`) — renders the menu-bar image (one avatar block per live provider), owns the popover, and drives the ~1s animation tick.

### Adding / activating a provider

`Core/ProviderCatalog.swift` is the single flip point. To make a coming-soon provider live: implement its `QuotaProvider`, return it from `makeProvider(for:)`, **and** set its descriptor `availability` to `.live`. `ProviderID.allCases` order is canonical display order everywhere — keep all live providers before coming-soon ones (`openTab` derives the tooltip from `orderedLive` but the popover tab from `orderedEnabled`; they agree only while the first enabled provider is also live).

### Design & product docs

`DESIGN.md` is the binding design system (retro 8-bit "party status screen"); `PRODUCT.md` is the product spec. Both are authoritative — match them, don't drift. Key invariants worth knowing before touching UI:

- **`Severity(percent:)`** (`Core/Models.swift`) is the single source of truth for state: ok `<60`, warn `60–84`, critical `85+`. Every quota color derives from it — never hand-pick.
- The **popover** uses the full Cyan → Gold → Red severity trio and is dark-only by doctrine. The **menu bar** uses a quieter ramp — neutral (white on dark / black on light) → orange → red — and is system-appearance aware (`RetroTheme.menuBarColor`).
- Press Start 2P (bundled TTF, loaded via `Bundle.module` — see `Package.swift` `resources`) is for short uppercase labels only; anything sentence-length is SF Mono.

## Testing convention

Logic is written as **pure static functions** on the view/controller/formatter types and tested directly, not through the SwiftUI view tree (see `StatusItemController.menuBarSpec`, `LimitRowView.resetLabel`, `ResetFormatter.*`). When adding behavior, prefer a static function with a unit test over logic embedded in `body`. Time-dependent tests use fixed `Date(timeIntervalSince1970:)` epochs for determinism; countdown formatters are timezone-independent (pure diffs) while absolute-date formatters take an explicit `timeZone`/`locale`, so assert those loosely.

## Workflow expectations

This repo uses the Superpowers skills (brainstorm → spec in `docs/superpowers/specs/` → plan in `docs/superpowers/plans/` → subagent-driven execution). Follow TDD (RED → GREEN), keep the full suite green before committing, and never work directly on `main` — branch first. Co-author trailer for commits: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
