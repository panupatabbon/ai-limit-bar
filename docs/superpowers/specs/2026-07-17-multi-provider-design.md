# Multi-Provider Support (v0.4.0) — Design

Date: 2026-07-17
Status: approved

## Goal

Let the user choose which AI providers AILimitBar tracks — Claude, Codex,
Gemini, Cursor — from Settings. The menu bar shows one avatar block per
enabled live provider; the popover shows one tab per enabled provider.
Real quota data ships only for providers whose local read-only data source
is feasible: Claude (existing), Codex CLI and Gemini CLI behind bounded
research gates. Cursor ships as coming-soon (no public quota channel).

Decisions below were settled in a grill + brainstorming session with the
user; do not re-litigate them during planning.

## Decisions (settled)

1. **Scope**: full 4-provider UI; live adapters only where feasible.
   Research targets: Codex CLI, Gemini CLI (the user is signed into both).
   Cursor: coming-soon.
2. **Release**: one release (v0.4.0), internal order: framework →
   Codex research gate → Gemini research gate. Adapters that miss the
   gate stay coming-soon without blocking the release.
3. **Min-1 rule**: at least one *live* provider must stay enabled.
   Claude is the default, not locked — it can be disabled while another
   live provider remains on.
4. **Menu bar**: single `NSStatusItem`; one avatar block per enabled
   *live* provider, fixed order, uniform density (sprite + percent +
   mini-bar governed by the existing "Show %" toggle). Coming-soon
   providers never appear in the menu bar.
5. **Per-provider signals**: each block wears its own severity color and
   sprite mood; a signed-out provider shows "!" in Warning Gold; loading
   shows "--" neutral. Positions never reorder by severity.
6. **Open-tab rule**: clicking the status item opens the popover on the
   hottest provider (highest severity ≥ warn; tie → fixed order);
   otherwise the first enabled provider. The status item tooltip and
   accessibility label describe the same hottest provider.
7. **Fixed order**: claude → codex → gemini → cursor (enum case order).
8. **Tab bar**: sprite-face tabs (16×16 mascot per tab; active = Coin
   Cyan background with Void Purple sprite, inactive = Dungeon Violet
   with 70% white sprite). Hidden entirely when exactly one provider is
   enabled. Existing VO labels/selected traits/focus rings carry over.
9. **Activity**: ACTIVITY 24H renders on the Claude tab only. Other tabs
   end at QUOTA with no empty section. Per-provider activity scanners are
   future work.
10. **Mascots**: Codex = hex-blossom (six-petal hexagonal knot; alt =
    petals rotate one step; blink = core contracts). Cursor = I-beam with
    heavy top/bottom serifs for visual mass; alt = 1px vertical shift;
    blink = the frame is empty (a literal text-cursor blink).

## Architecture

Approach: **N × QuotaStore + ProviderHub** (chosen over a rewritten
multi-provider store). `QuotaStore`, `ClaudeProvider`, `Severity`, and the
sprite/mood system are reused untouched; per-provider state machines and
backoff stay isolated (one provider going offline never affects another).

### New units

- **`ProviderID`** — `enum ProviderID: String, CaseIterable { case claude,
  codex, gemini, cursor }`. Replaces/extends `ProviderTab`. Case order is
  the canonical display order.
- **`ProviderCatalog`** — static descriptors, one per provider:
  `id`, `displayName`, sprite reference, and
  `availability: .live(makeProvider: () -> QuotaProvider) | .comingSoon`.
  This is the single flip point when an adapter lands: switch the case
  from `.comingSoon` to `.live` and everything else follows.
- **`ProviderHub`** (`@Observable @MainActor`) — owns
  `[ProviderID: QuotaStore]` for providers that are enabled AND live.
  Creates a store and starts polling when a provider is toggled on;
  stops polling and drops the store when toggled off (disable = stop
  polling, not hide). API: `orderedEnabled: [ProviderID]`,
  `orderedLive: [ProviderID]`, `store(for:)`,
  `hottest() -> ProviderID?` (max severity ≥ warn, tie → order).

### Settings & persistence

- `AppSettings.enabledProviders: Set<ProviderID>` persisted in
  UserDefaults as raw strings; default `[.claude]`. Sanitized on load:
  unknown values dropped; if the result contains no *live* provider
  (empty, or only coming-soon providers — possible when catalog
  availability changes across versions), `.claude` is added back.
- Min-1 is enforced in the data layer (sanitize) and in the UI: the last
  enabled *live* provider's toggle is disabled so the menu bar can never
  be empty (an all-coming-soon selection is impossible).

### Adapters (research-gated)

Each adapter conforms to the existing `QuotaProvider` protocol and follows
the app's security posture: read-only local credentials, token kept in
memory, exactly one HTTPS endpoint per provider, no telemetry.

- **`CodexProvider`** — expected shape: read `~/.codex/auth.json`
  (Codex CLI OAuth), call the usage/rate-limit endpoint the CLI itself
  uses; map to `QuotaSnapshot` (session/weekly analogues as available).
  Research gate: confirm credential format + endpoint + response schema.
- **`GeminiProvider`** — expected shape: Gemini CLI local OAuth under
  `~/.gemini`; quota channel needs research. Same gate criteria.

A gate fails cleanly: the provider stays `.comingSoon` in the catalog and
nothing else changes. Each provider's popover error copy is localized to
its own CLI ("Install and sign in to Codex CLI first — this app reads its
quota data.").

## UI surfaces

### Menu bar

- `MenuBarImageBuilder` extends from one `Spec` to an ordered
  `[ProviderSpec]` (frame, percentText, barFraction, color per provider),
  composed into a single image with an 8pt gap between provider blocks.
- Only enabled+live providers render. Uniform density: sprite (16pt) +
  percent text + 14×3 mini-bar per the existing global "Show %" toggle.
- Per-provider color: severity trio (appearance-adaptive variants as
  today), Warning Gold "!" for credentialsMissing/tokenExpired, neutral
  "--" for loading.
- `statusDescription` (tooltip + accessibility label) describes the
  hottest provider, prefixed with its name when more than one provider is
  enabled: "Codex: Weekly Total 91% used — resets Friday 2:00 PM".
- Click opens the popover on the hottest provider's tab (rule above).

### Popover

- Tab bar = sprite-face tabs, rendered only when ≥2 providers enabled.
  Popover width stays 298pt (4 face tabs ≈ 130pt).
- Live tab: existing QUOTA UI (LimitRowView, PixelProgressBar, state
  screens) bound to that provider's store. State-screen copy is
  per-provider.
- Coming-soon tab: that provider's sprite + "INSERT CARTRIDGE" +
  "<Name> support is coming soon."
- ACTIVITY 24H section only on the Claude tab.
- Disabling the currently-viewed provider drops the tab selection to the
  first enabled provider.

### Settings

- New **PROVIDERS** section above GENERAL: four toggles in fixed order;
  coming-soon providers labeled "(coming soon)". The last enabled live
  toggle is disabled. Toggling takes effect immediately via ProviderHub.
- "Menu bar % tracks" (headline pin) applies uniformly to every
  provider's own store.

## Sprites

Two new 16×16 sprites in `SpriteLibrary`, 4-frame loop (base, alt, base,
blink), same ≥8px base/alt motion rule:

- **codex** — hex-blossom.
- **cursor** — I-beam; blink frame intentionally empty (the sprite test
  invariant "every frame draws pixels" gets a documented exception for
  this frame).

## Testing

Pure, static decision functions per existing convention:

- ProviderHub: store lifecycle on enable/disable; `hottest()` — none ≥
  warn → nil; tie → fixed order.
- AppSettings: enabledProviders persistence, sanitize (`[]`/garbage →
  `[claude]`).
- Open-tab rule; tab-bar visibility (1 provider → hidden).
- Menu bar composition: order, live-only filtering, per-provider colors,
  total width math.
- `statusDescription`: hottest-provider selection and name prefix.
- SpriteTests extended to 4 providers with the cursor-blink exception.

## Out of scope (this release)

- Cursor adapter (no public quota channel).
- Per-provider activity scanners (Codex/Gemini logs).
- User-arranged provider order.
- Threshold-crossing notifications (separate backlog item).
