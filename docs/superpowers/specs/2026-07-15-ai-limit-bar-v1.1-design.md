# ai-limit-bar V1.1 — Design Spec

**Date:** 2026-07-15
**Status:** Approved pending user review
**Baseline:** V1 (branch `feat/v1-design`, commit `94f3d83`, 51 tests green) + V1 spec `2026-07-15-ai-limit-bar-design.md`

V1.1 responds to first real-use feedback: menu bar fixes (animation, spacing, mini progress bar), softened retro palettes, correct popover anchoring, provider tabs (Claude live / Gemini coming soon), a local-log "Activity 24h" section, per-provider avatars, and a roomier professional popover layout.

## 1. Scope

### In
1. Menu bar item redrawn as one composite `NSImage` (avatar + smaller % + mini progress bar), tighter spacing, visibly animated.
2. Softened severity + theme palettes for Dark and Light (exact values §4).
3. Popover anchored flush under the status item (standard system offset).
4. Popover restructured: provider tabs, sectioned layout, wider (300 pt), consistent padding.
5. New ACTIVITY 24H section fed by a local transcript scanner (`~/.claude/projects`), plus an UPDATED footer line.
6. Gemini tab present as a retro COMING SOON screen.
7. Provider avatars (Claude, Gemini) replace the BOO/BUG/BOT picker entirely.

### Out (unchanged from V1)
Read-only credentials posture, 60 s quota polling, notifications, launch-at-login, real Gemini quota, notarization.

## 2. Menu bar item (feedback #1, #3)

Replace `button.image` + `attributedTitle` with a single composite `NSImage` rendered per tick by a pure, testable builder:

```swift
enum MenuBarImageBuilder {
    struct Spec: Equatable {
        let frame: SpriteFrame        // current avatar frame
        let percentText: String?      // "42%" | "--" | nil (hidden by setting)
        let barFraction: Double?      // 0...1, nil when no data/error
        let color: NSColor            // severity or gray
    }
    static func layoutWidth(for spec: Spec) -> CGFloat   // pure, unit-tested
    static func image(for spec: Spec) -> NSImage
}
```

Layout inside an 18 pt-tall image: `[avatar 16×16] [3 pt gap] [right block]`, right block = percent text in Press Start 2P **7 pt** (top) with a **14×3 pt segmented mini bar** below it (filled fraction = headline percent, same severity color). No `attributedTitle`, no `baselineOffset` — the button returns to standard status-item metrics, which also fixes the popover gap (#3). Acceptance for #3: popover top edge sits at the standard NSPopover offset under the menu bar, same as system items.

**Animation fix:** V1 frames differed only in bottom rows — invisible at 16 px. The new provider sprites (§6) are designed with obvious 2-frame motion (≥8 changed pixels + 1 px vertical bob between frames). Animation still pauses under Low Power Mode (documented in README as intended behavior); numbers keep updating.

## 3. Popover structure (feedback #5, #6, #7)

Width 300 pt, outer padding 16 pt, section spacing 14 pt. Layout (Claude tab):

```
┌────────────────────────────────┐
│ [CLAUDE] [GEMINI]              │  tab bar (retro segmented)
│ CLAUDE MAX            [sprite] │  header: plan name + provider avatar (animated)
│ ── QUOTA ────────────────────  │  section header + pixel divider
│  SESSION      10%              │
│  ███░░░░░░░░░░░                │  (rows as V1, spacing 10 pt)
│  RESET 2H 14M                  │
│  WEEKLY ALL   58% ◀  …         │
│ ── ACTIVITY 24H ─────────────  │
│  SKILLS                        │
│   brainstorming          ×12   │  top 3, name truncated middle
│   code-review            ×8    │
│  AGENTS                        │
│   general-purpose        ×21   │  top 3
│  SESSIONS 14                   │
│ ── ─────────────────────────   │
│ UPDATED 2M AGO   ⚙ SETTINGS  ⏻ QUIT │  footer row
└────────────────────────────────┘
```

- **Tabs:** `ProviderTab` enum (`claude`, `gemini`), selected tab persisted in `AppSettings.selectedTab`. Active tab styled with accent underline/fill; pixel font 8 pt labels.
- **Gemini tab content:** provider avatar + `INSERT CARTRIDGE` + localized hint "Gemini support is coming soon" (EN/TH via L10n). No data calls.
- **Section headers:** pixel font 7 pt, letter-spaced, with a 1 px divider in `textPrimary @ 20%`.
- **Footer:** `UPDATED <relative>` (left) + SETTINGS + QUIT buttons (right). Relative time via pure `RelativeTimeFormatter.string(since:now:)` → `JUST NOW` (<60 s), `2M AGO`, `1H 5M AGO` (unit-tested).
- Menu bar continues to show Claude data regardless of selected tab (Claude is the only live provider).
- Error/loading states (INSERT COIN, TOKEN EXPIRED, OFFLINE badge, LOADING) render inside the Claude tab below the tab bar; ACTIVITY section still shows (it's independent of quota fetch).

## 4. Palettes — softened (feedback #2, #4)

Saturation reduced across the board; severity hues remain distinguishable; all text/background pairs re-checked for WCAG AA.

| Token | Dark | Light |
|---|---|---|
| background | `#14141B` | `#F5EFDF` |
| surface | `#1E1E28` | `#EAE2CC` |
| textPrimary | `#D8D8E4` | `#3A3A42` |
| accentPink | `#E85D9E` | `#A8487E` |
| accentCyan | `#5BC8E8` | `#2E7D96` |
| ok | `#4ADE80` | `#3B8C5A` |
| warn | `#E8C547` | `#B0821F` |
| critical | `#F07171` | `#C25454` |

Same `RetroTheme` structure; only values change (plus updated `RetroThemeTests` expectations).

## 5. ActivityScanner (feedback #5)

New unit `Sources/AILimitBarKit/Core/Activity/`:

```swift
struct ActivityCount: Equatable, Sendable {
    let name: String
    let count: Int
}

struct ActivitySummary: Equatable, Sendable {
    let topSkills: [ActivityCount]    // top 3 by count
    let topAgents: [ActivityCount]    // top 3
    let sessionCount: Int             // distinct .jsonl files scanned
    let scannedAt: Date
}

struct ActivityScanner: Sendable {
    init(root: URL = ~/.claude/projects, window: TimeInterval = 86_400)
    func scan() -> ActivitySummary          // synchronous core, called off-main
    static func parseLine(_ line: Substring) -> ActivityEvent?   // pure, unit-tested
}

@MainActor @Observable final class ActivityStore {
    private(set) var summary: ActivitySummary?
    func refreshIfStale(olderThan: TimeInterval = 300) // async, Task.detached scan
}
```

- File selection: `*.jsonl` under root with `contentModificationDate` within the window (~42 MB/77 files observed on the dev machine — acceptable for a 5-minute cadence).
- Parsing is **string-search based**, not full JSON decoding: a line counts as a skill event if it contains `"name":"Skill"` and a capturable `"skill":"<value>"`; as an agent event if it contains `"subagent_type":"<value>"`. Unknown/malformed lines are skipped silently. This is a heuristic over an undocumented local format — defensive by construction, must never crash on garbage.
- Read-only, same security posture as credentials: file contents never logged, never transmitted; only aggregate names+counts are held in memory.
- Cache: `ActivityStore.refreshIfStale(300)` called on popover open; scan runs in `Task.detached(priority: .utility)`; UI shows the previous summary (or `SCANNING…`) meanwhile.
- Empty state: no files in window → section shows `NO ACTIVITY`.

## 6. Provider avatars (feedback #8)

- `AvatarID` enum and the Settings avatar picker are **removed**. The stored `avatar` UserDefaults key is simply ignored (no migration).
- `SpriteLibrary.sprite(forProvider id: String) -> Sprite` keyed by provider id (`"claude"`, `"gemini"`).
- Two new original 16×16 sprites (designed fresh, no resemblance to Anthropic/Google logos):
  - **CLAUDE:** friendly spark-creature; frame B shifts body 1 px up with limbs repositioned (clear motion).
  - **GEMINI:** twin-star pair; frame B swaps star sizes/positions.
  - Each still has a blink frame → 4-frame popover loop `[base, alt, base, blink]`, menu bar uses `[base, alt]`.
- Menu bar avatar = active (live) provider = Claude.

## 7. Settings changes

- Remove: Avatar pane.
- Keep: General (language, theme), Display (all four V1 toggles).
- Add: nothing new (tab selection persists implicitly from the popover).
- `AppSettings` gains `selectedTab: ProviderTab` (persisted, default `.claude`).

## 8. Localization additions

New L10n key (EN/TH, both non-empty, tested): `tabComingSoonHint` ("Gemini support is coming soon" / Thai equivalent). Everything else in the new UI is a game label that stays English pixel-font per the V1 language policy: `UPDATED`, `JUST NOW`, `xM AGO`, `INSERT CARTRIDGE`, `ACTIVITY 24H`, `QUOTA`, `SKILLS`, `AGENTS`, `SESSIONS`, `NO ACTIVITY`, `SCANNING…`.

## 9. Testing

- `MenuBarImageBuilder`: layout width for combinations (with/without % text, with/without bar), image size, pure.
- `RelativeTimeFormatter`: JUST NOW / xM AGO / xH xM AGO boundaries.
- `ActivityScanner.parseLine`: fixture lines for skill events, agent events, garbage, near-miss strings (e.g. `"name":"Skills"`), empty line.
- `ActivityScanner.scan`: temp directory fixture with fresh + stale `.jsonl` files → only fresh counted; top-3 ordering; sessionCount.
- `ActivityStore`: stale-gate behavior with injected clock.
- `RetroThemeTests`: updated to new palette values.
- Tab persistence: `AppSettings.selectedTab` default + round-trip.
- L10n: existing completeness test automatically covers new keys.
- Removed: sprite/avatar-picker tests tied to `AvatarID` (replaced by provider-sprite tests: 16×16, 4 frames, base≠alt, per provider id).
- Manual smoke checklist (delta): menu bar composite renders (avatar+%+bar, compact), animation visible with Low Power OFF, popover flush under menu bar, tabs switch and persist, Gemini COMING SOON, ACTIVITY section shows real counts, UPDATED ticks over, both themes readable.

## 10. Decision log (V1.1)

| Decision | Choice | Why |
|---|---|---|
| Activity data source | Local `~/.claude/projects` JSONL string-scan | OAuth endpoint has no skill/agent data; logs verified present (42 MB/24 h) |
| Scan strategy | Background scan + 5-min cache (Approach A) | Popover opens instantly; 42 MB scan too slow to run per-open |
| Gemini this release | Tab + COMING SOON screen | No usage API exists; UI structure lands now, data pluggable later |
| Avatars | Per-provider sprites replace user picker | Clearer meaning (avatar identifies provider); simpler settings |
| Menu bar rendering | Single composite NSImage | Only way to control gap precisely + draw mini bar + fix button metrics (popover gap) |
| Low Power Mode | Animation still pauses | Intentional energy behavior; documented instead of removed |
| Menu bar data with tabs | Always Claude | Only live provider; revisit when a second provider has real data |
