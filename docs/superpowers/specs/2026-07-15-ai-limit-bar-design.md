# ai-limit-bar — Design Spec

**Date:** 2026-07-15
**Status:** Approved pending user review

A macOS menu bar app that shows AI subscription quota (limit / used / reset) in a retro 8-bit arcade style. V1 tracks Claude Pro/Max subscription limits; the architecture is provider-agnostic so Gemini (and others) can be added later. Open source (MIT), distributed via GitHub Releases.

## 1. Goals & Non-Goals

### Goals (V1)
- Always-visible menu bar indicator: pixel avatar + percent of the most-constrained limit, color-coded green (<60%) / yellow (60–85%) / red (≥85%).
- Popover showing every limit the API reports (session 5-hour, weekly all-models, weekly per-model) with number, percent, HP-style progress bar, and reset time.
- 8-bit arcade/NES aesthetic: pixel font, code-defined pixel sprites, neon-on-dark and pastel-on-cream palettes.
- Settings: language EN/TH, theme Dark/Light/System, four show/hide options, 3 selectable animated avatars.
- Zero-setup for Claude Code users: reads existing Claude Code credentials read-only.
- Safe to open-source: no telemetry, no secret persistence, single HTTPS destination.

### Non-Goals (V1)
- No notifications (display-only; menu bar color is the alert).
- No launch-at-login, no auto-update (Sparkle later).
- No "Sign in with Claude" OAuth flow (architecture reserves a slot; see §4.1).
- No API pay-as-you-go billing tracking.
- No Gemini provider yet (protocol designed for it).

## 2. Platform & Stack

- Swift 6.x, SwiftUI for all views; AppKit shell (`NSStatusItem` + `NSPopover` + `NSHostingController`) for full control over the animated status item.
- Project is a plain Swift Package (no `.xcodeproj`). `Scripts/bundle.sh` wraps `swift build -c release` into `AILimitBar.app` (Info.plist with `LSUIElement = true` so no Dock icon).
- Minimum macOS: 14 (Sonoma). Dev machine: Swift 6.3 / Xcode 26.4.
- Distribution: GitHub Releases, unsigned/ad-hoc in V1. README documents first-open (right-click → Open) and build-from-source. Notarization can be added later without code changes.
- CI: GitHub Actions on macOS runner — `swift build && swift test` on every PR.

## 3. Repository Layout

```
ai-limit-bar/
├── Package.swift                  # executable target "AILimitBar"
├── Sources/AILimitBar/
│   ├── App/                       # main entry, AppDelegate, StatusItemController
│   ├── Core/                      # QuotaProvider protocol, models, QuotaStore, AppSettings
│   ├── Providers/Claude/          # ClaudeCredentialsReader, ClaudeUsageClient, ClaudeProvider
│   ├── UI/
│   │   ├── Popover/               # QuotaPopoverView, LimitRowView
│   │   ├── Settings/              # SettingsWindow, General/Display/Avatar panes
│   │   └── Retro/                 # RetroTheme, PixelProgressBar, AvatarSpriteView, sprites
│   └── Resources/                 # PressStart2P font (OFL), Localizable.xcstrings (EN/TH)
├── Tests/AILimitBarTests/         # unit tests + JSON fixtures
├── Scripts/bundle.sh
├── docs/superpowers/specs/
├── LICENSE                        # MIT
└── README.md                      # install, security section, screenshots
```

## 4. Data Layer

### 4.1 Provider abstraction

```swift
protocol QuotaProvider {
    var id: String { get }            // "claude"
    var displayName: String { get }   // "CLAUDE MAX" (derived from subscriptionType)
    func fetchSnapshot() async throws -> QuotaSnapshot
}

struct QuotaSnapshot {
    let limits: [QuotaLimit]
    let fetchedAt: Date
}

struct QuotaLimit {
    let kind: LimitKind        // .session, .weeklyAll, .weeklyModel(displayName: String)
    let percentUsed: Double    // 0–100
    let resetsAt: Date
    let isActive: Bool         // which limit currently binds
}
```

`AuthSource` enum exists from day one with a single case `claudeCodeCredentials`; a future `ownOAuth` case slots in without restructuring (settings UI, provider init, and error states all switch on it).

### 4.2 Claude credentials (read-only, verified on real machine)

Resolution order — pick the candidate with the newest `claudeAiOauth.expiresAt`:
1. macOS Keychain generic password, service `"Claude Code-credentials"`, account = current user. This is the live store on macOS; first read triggers the standard Keychain "Allow" dialog (documented in README and in-app hint).
2. Fallback: `~/.claude/.credentials.json` (may be stale — observed stale on the dev machine).

Both contain `claudeAiOauth: { accessToken, refreshToken, expiresAt, refreshTokenExpiresAt, scopes, subscriptionType, rateLimitTier }`. The app reads `accessToken`, `expiresAt`, `subscriptionType` only. **It never writes to either store and never calls the token-refresh endpoint** (refresh-token rotation could race with Claude Code and invalidate its session). On expiry the app shows a recovery state (§7) and heals automatically once Claude Code refreshes the token.

### 4.3 Usage endpoint (verified 2026-07-15 against production)

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <accessToken>
anthropic-beta: oauth-2025-04-20
```

Primary parse target is `limits[]`:

```json
{ "kind": "session|weekly_all|weekly_scoped", "group": "session|weekly",
  "percent": 58, "severity": "normal|…", "resets_at": "ISO8601",
  "scope": { "model": { "display_name": "Fable" } } | null, "is_active": true }
```

Mapping: `session` → `.session`, `weekly_all` → `.weeklyAll`, `weekly_scoped` → `.weeklyModel(scope.model.display_name)`. Unknown `kind` values are skipped (forward compatibility). If `limits[]` is missing/empty, fall back to top-level `five_hour` / `seven_day` objects (`utilization`, `resets_at`). All other fields in the response are ignored.

### 4.4 QuotaStore

Single `@Observable` source of truth:
- Polls every 60 s via `Timer`; also refetches on popover open if the snapshot is older than 10 s.
- State machine: `loading → ready(QuotaSnapshot) | credentialsMissing | tokenExpired | offline(lastGood: QuotaSnapshot?)`.
- On network failure: keep last snapshot, retry with exponential backoff (base 5 s, cap 5 min), surface `offline` state.
- Computes `headlineLimit`: by default the limit with max `percentUsed` ("auto"); settings can pin it to session or weekly (§6).

## 5. UI / Retro Design System

### 5.1 Theme

`RetroTheme` with two palettes; `System` follows macOS appearance.

| Token | Dark | Light |
|---|---|---|
| Background | `#0A0A12` | `#F2EAD3` (cream) |
| Primary accent | neon green `#00FF66` | SNES-dark green |
| Secondary accents | pink `#FF2E88`, cyan `#00CCFF` | dark pastel pink/blue |
| Quota OK / warn / critical | neon green / yellow / red | pastel-dark green / amber / red |

Severity hues stay in the same family across themes; every text/background pair is checked for WCAG AA contrast.

### 5.2 Typography

- Game labels and all numerals: **Press Start 2P** (OFL, bundled). Game labels (SESSION, WEEKLY, RESET, INSERT COIN, …) stay English in both languages — part of the aesthetic.
- Thai descriptive text (settings, hints, error explanations): SF Pro Rounded via system font APIs.

### 5.3 Sprites (code-defined, original art)

Avatars are original 16×16 pixel designs defined as 2D bitmap arrays in Swift, rendered via `Canvas` (popover) and rasterized to `NSImage` (status item). No image assets; sprites tint to theme/severity color at render time. Three avatars: **BOO** (ghost), **BUG** (alien), **BOT** (robot). Frames: 2-frame idle for menu bar, 4–8-frame loop for popover.

### 5.4 Menu bar (StatusItemController)

- `NSStatusItem` with `button.image` = current avatar frame tinted by severity color, plus attributed-string title `"42%"` in the pixel font (title hidden when the show-% setting is off).
- Idle animation flips 2 frames at 1 s interval; animation pauses under Low Power Mode.
- Percent shown = `headlineLimit.percentUsed` (auto or pinned per settings).
- Error states render a gray icon with `--` title.

### 5.5 Popover

```
┏━━ AI QUOTA ━━━━━━━━━━┓
┃ ▶ CLAUDE MAX    [BOO]┃   animated avatar (4–8 frames)
┃ SESSION      10%     ┃
┃ ██░░░░░░░░░░░░       ┃   segmented HP bar
┃ RESET 2H 14M         ┃   session → countdown
┃ WEEKLY ALL   58% ◀   ┃   ◀ marks is_active limit
┃ ████████░░░░░        ┃
┃ RESET THU 04:00      ┃   weekly → local day + time
┃ WEEKLY FABLE 38%     ┃
┃ ██████░░░░░░░        ┃
┃ [GEAR] SETTINGS      ┃
┗━━━━━━━━━━━━━━━━━━━━━━┛
```

- One `LimitRowView` per `QuotaLimit`, ordered: session, weekly all, weekly per-model.
- `PixelProgressBar`: chunky segments, fill color by severity.
- Compact mode (setting) hides the reset line and detail numerals, leaving label + bar + %.
- Layout accommodates future second provider section (Gemini) by iterating providers.

### 5.6 Settings window

Separate retro-styled window, three panes:
- **General:** language EN/TH, theme Dark/Light/System.
- **Display:** show/hide % on menu bar · which limits appear in popover · which limit the menu bar % tracks (auto/session/weekly) · compact vs full rows.
- **Avatar:** pick BOO/BUG/BOT with live animated preview.

Persisted via `UserDefaults` (`AppSettings` `@Observable` wrapper). Localization via String Catalog (`.xcstrings`), EN + TH.

## 6. Error Handling

| State | Menu bar | Popover |
|---|---|---|
| `credentialsMissing` | gray icon, `--` | `INSERT COIN` screen + localized hint "Install / sign in to Claude Code first" |
| `tokenExpired` (401 / expiresAt past) | gray icon, `--` | `TOKEN EXPIRED` + hint "Use Claude Code once to renew"; auto-recovers on a later poll |
| `offline` | last data, dimmed | `OFFLINE` badge + last-fetched timestamp; backoff retry per §4.4 |
| Malformed/changed API response | — | defensive decode; `limits[]` missing → legacy field fallback; still-broken → treated as `offline` with log line |

All error screens use the same retro theme (pixel art, game vocabulary in EN, explanation localized).

## 7. Security Posture

- **Read-only everywhere:** never writes Claude Code's Keychain item or credentials file; never calls the OAuth refresh endpoint.
- Access token lives in memory only; never persisted, never logged. Logging layer redacts any `Authorization`-shaped value.
- Exactly one network destination: `https://api.anthropic.com`. No telemetry, no analytics, no update pings.
- README carries a security section: what is read, what is never touched, why the Keychain "Allow" dialog appears, and the ToS-gray-area note about the undocumented usage endpoint.

## 8. Testing (TDD)

- **Decoding:** fixtures captured from the real response (redacted), plus cases for empty/missing `limits[]`, unknown `kind`, null scopes → legacy fallback.
- **Credentials:** Keychain-vs-file precedence by `expiresAt`, missing-both, malformed JSON.
- **QuotaStore:** state transitions (loading→ready→tokenExpired→recovered; offline keeps last snapshot) using a mock `QuotaProvider`; headline-limit selection (auto max, pinned overrides).
- **Formatting:** countdown ("2H 14M"), weekly reset ("THU 04:00" local), severity color thresholds at 59/60/84/85.
- **UI:** manual smoke checklist — both themes × both languages × every state (driven by a debug mock provider).
- CI runs the full unit suite on every PR.

## 9. Open Questions / Future Work

- Gemini provider (no known usage API today; revisit when one exists).
- "Sign in with Claude" own-OAuth mode (`AuthSource.ownOAuth`) — ToS review first.
- Notifications at thresholds, launch-at-login, Sparkle auto-update, Homebrew cask + notarization.

## 10. Decision Log

| Decision | Choice | Why |
|---|---|---|
| Quota type | Subscription limits (not API billing) | Matches daily Claude Code usage; live data available |
| Providers V1 | Claude only, protocol reserved for Gemini | Ship value fast; no Gemini usage API today |
| Shell | AppKit `NSStatusItem` + SwiftUI popover | Full control over animated colored icon + dynamic title |
| Project | SwiftPM + bundle script, no `.xcodeproj` | Clean diffs, contributor-friendly |
| Data source | Keychain-first read of Claude Code credentials | Verified live on dev machine; file copy was stale |
| Token expiry | Read-only, never self-refresh | Refresh rotation could break the user's Claude Code login |
| Auth for public users | Claude Code required in V1 | Own OAuth is ToS gray area; enum slot reserved |
| Distribution | GitHub Releases unsigned + build-from-source | No paid dev account required to start |
| Style | 8-bit arcade; Dark neon / Light SNES pastel | User choice in grill session |
| Sprites | Code-defined 2D arrays, original designs | Theme-tintable, no asset pipeline, no trademark risk |
| TH localization | Game labels stay EN pixel font; prose localized | Pixel fonts lack Thai glyphs; EN labels are part of the aesthetic |
| Notifications | None (display-only) | User choice; icon color is the alert |
