---
name: AILimitBar
description: Retro 8-bit macOS menu bar app showing Claude quota as HP-style pixel bars
colors:
  void-purple: "#09051C"
  dungeon-violet: "#1D0245"
  pixel-white: "#FFFFFF"
  neon-magenta: "#FF79C6"
  coin-cyan: "#00D9FF"
  warning-gold: "#FFC300"
  damage-red: "#FF5C5C"
typography:
  display:
    fontFamily: "Press Start 2P, monospace"
    fontSize: "12pt"
    fontWeight: 400
  headline:
    fontFamily: "Press Start 2P, monospace"
    fontSize: "9pt"
    fontWeight: 400
  title:
    fontFamily: "Press Start 2P, monospace"
    fontSize: "8pt"
    fontWeight: 400
  label:
    fontFamily: "Press Start 2P, monospace"
    fontSize: "7pt"
    fontWeight: 400
  caption:
    fontFamily: "Press Start 2P, monospace"
    fontSize: "6pt"
    fontWeight: 400
  body:
    fontFamily: "SF Mono, ui-monospace, monospace"
    fontSize: "10pt"
    fontWeight: 400
rounded:
  none: "0pt"
spacing:
  micro: "2pt"
  xs: "4pt"
  sm: "8pt"
  md: "12pt"
  lg: "16pt"
  xl: "20pt"
components:
  tab-active:
    backgroundColor: "{colors.coin-cyan}"
    textColor: "{colors.void-purple}"
    typography: "{typography.title}"
    rounded: "{rounded.none}"
    padding: "6pt 10pt"
  tab-inactive:
    backgroundColor: "{colors.dungeon-violet}"
    textColor: "#FFFFFFB3"
    typography: "{typography.title}"
    rounded: "{rounded.none}"
    padding: "6pt 10pt"
  progress-segment:
    backgroundColor: "{colors.coin-cyan}"
    rounded: "{rounded.none}"
    size: "10pt"
  state-title:
    textColor: "{colors.neon-magenta}"
    typography: "{typography.display}"
  footer-action:
    textColor: "#FFFFFFB3"
    typography: "{typography.label}"
    rounded: "{rounded.none}"
---

# Design System: AILimitBar

## 1. Overview

**Creative North Star: "The Party Status Screen"**

AILimitBar renders Claude quota the way a JRPG renders its party: HP bars, exact numbers, and a mascot sprite, all readable in a single glance from a pause-menu-dark screen. The system is a native SwiftUI translation of the Jules cyberpunk palette — deep purple-black surfaces, neon magenta as the brand voice, cyan as the working accent — worn as a game skin over an instrument core. Every value on screen is literal: percentages, reset countdowns, and severity states are never abstracted into decoration.

The register is product. The popover is 298pt wide (derived from the HP bar's pixel grid), the settings window 340pt; there is no responsive web layout, no hover choreography, no scroll. Density is deliberate: one glance answers "how much HP is left," a second glance answers "which limit and when does it reset." The system explicitly rejects the SaaS analytics dashboard — no white cards, no metric tiles, no charts-for-the-sake-of-charts. Quota is a status screen, not a report. It equally rejects retro-at-the-cost-of-legibility: the pixel font is reserved for short uppercase labels; anything sentence-length switches to SF Mono.

**Key Characteristics:**
- Dark-only, dual-surface world: Void Purple base with Dungeon Violet panels
- Pixel type (Press Start 2P) for labels, SF Mono for prose — never the reverse
- Severity speaks in exactly three colors: Coin Cyan → Warning Gold → Damage Red
- 100% flat: depth is a surface-color change or a 1px stroke, never a shadow
- Sharp corners everywhere; the grid is the ornament
- Motion is a heartbeat, not a show: 0.3s sprite ticks, paused in Low Power Mode

## 2. Colors

A committed dark palette where the surfaces are the night and four saturated voices do all the talking.

### Primary
- **Neon Magenta** (`#FF79C6`): The brand's voice. Section headers ("QUOTA", "ACTIVITY 24H"), state-screen titles ("INSERT COIN", "TOKEN EXPIRED"), and the ◀ active-limit marker. It marks *where the app speaks*, never how bad things are.
- **Coin Cyan** (`#00D9FF`): The working accent. Active tab fill, plan-name header, activity group titles, settings tint — and doubles as the `ok` severity color (usage below 60%).

### Secondary
- **Warning Gold** (`#FFC300`): Severity `warn` (usage 60–84%) and the OFFLINE badge. Appears only when the user should start paying attention.
- **Damage Red** (`#FF5C5C`): Severity `critical` (usage 85%+). The only red in the system; when it shows, a limit is nearly spent.

### Neutral
- **Void Purple** (`#09051C`): The base background of every surface — popover, settings window, menu bar image canvas. Also the text color on Coin Cyan fills (active tab).
- **Dungeon Violet** (`#1D0245`): The panel layer — empty progress-bar segments, inactive tab fills. One step up from the void; the only "elevation" the system has.
- **Pixel White** (`#FFFFFF`): All text, at stepped opacities that form the de facto text ramp: 100% primary labels, 70–80% secondary text and footer actions, 60% timestamps, 50% empty states, 40% bar borders, 20% divider rules.

### Named Rules
**The Magenta-Is-Brand Rule.** Neon Magenta never encodes severity or data. It is prohibited on bars, percentages, and warnings; it belongs to headers, state titles, and brand marks only. Severity speaks exclusively through the Cyan → Gold → Red trio.

**The Severity Trio Rule.** `Severity(percent:)` is the single source of truth: below 60% is Coin Cyan, 60–84% is Warning Gold, 85%+ is Damage Red. Any UI that shows quota state derives its color from this function — never hand-picked.

**The White-Opacity Ramp Rule.** There are no gray hex values. Secondary text is Pixel White at reduced opacity (0.8 / 0.7 / 0.6 / 0.5), so every "gray" stays tinted by the purple ground beneath it.

## 3. Typography

**Display Font:** Press Start 2P (bundled TTF, fallback: bold monospaced system font)
**Body Font:** SF Mono via `.system(design: .monospaced)` (fallback: ui-monospace)

**Character:** A hard pairing on one axis — bitmap pixel type for the game skin, a clean system mono for the instrument core. Both are monospace, so numbers align; only one is allowed to carry a full sentence.

### Hierarchy
- **Display** (Press Start 2P, 12pt): State-screen titles — "LOADING", "INSERT COIN", "TOKEN EXPIRED", "NO DATA", "INSERT CARTRIDGE". The loudest voice in the app; one per screen at most.
- **Headline** (Press Start 2P, 9pt): The plan name at the top of the popover ("CLAUDE MAX").
- **Title** (Press Start 2P, 8pt): Limit-row labels ("SESSION", "WEEKLY TOTAL"), percent values, and provider tabs.
- **Label** (Press Start 2P, 7pt): Section headers, footer actions ("⚙ SETTINGS", "⏻ QUIT"), activity percentages, menu bar percent text, OFFLINE badge.
- **Caption** (Press Start 2P, 6pt): Reset labels ("RESET 2H 15M") and the UPDATED timestamp. The floor — nothing renders smaller.
- **Body** (SF Mono `.caption`, ~10pt): Hints, error guidance, activity item names — any string longer than a label. Sentence case, never all-caps.

### Named Rules
**The Half-Cell Tracking Rule.** All Press Start 2P text carries letter-spacing of half a pixel cell (6.25% of point size — 0.5pt at 8pt) via `pixelType(size:)` in SwiftUI and a matching `.kern` in the menu bar image. Grid-true steps only; never arbitrary em values.

**The Pixel-For-Labels Rule.** Press Start 2P is prohibited on any string longer than ~3 words or any sentence with punctuation. Short uppercase labels only; the moment text must be *read* rather than *recognized*, it becomes SF Mono.

**The All-Caps Contract.** Everything set in Press Start 2P is uppercase. Everything set in SF Mono is sentence case. Mixing the two conventions in one element is a bug.

## 4. Elevation

**The Flat Cartridge Rule.** This system has no shadows — not on cards, not on popovers, not on focus states. It is flat by doctrine, not by omission: 8-bit hardware never rendered a drop shadow, and neither does this app. Depth is conveyed exactly two ways: a surface-color step (Void Purple → Dungeon Violet) and a 1px stroke (Pixel White at 40% for bar frames, 20% for divider rules). If a new element seems to need a shadow, it actually needs a surface change or a border.

## 5. Components

All components share the "refined retro" temperament: pixel-perfect geometry and game vocabulary, executed with restraint — exact alignment, stepped opacities, no noise. Every plain-style button carries `pixelFocusRing()`: a 1px Pixel White 70% rectangle on keyboard focus — the flat-language replacement for the system glow.

### Provider Tabs
- **Shape:** Sharp rectangles (0pt radius), 6pt vertical / 10pt horizontal padding, one 16×16 mascot sprite per tab
- **Active:** Coin Cyan fill with the mascot rendered in Void Purple — the strongest inversion in the app
- **Inactive:** Dungeon Violet fill with the mascot rendered in Pixel White at 70%
- **Visibility:** Hidden entirely when exactly one provider is enabled; existing VoiceOver labels, selected traits, and focus rings carry over unchanged

### Pixel Progress Bar (signature)
- **Structure:** Exactly 12 segments, each 20×10pt, 2pt gaps, wrapped in a 1px Pixel White 40% stroke with 2pt inset — 266pt total, the popover's full measure (the popover width derives from this grid: 266 + 32pt padding = 298pt)
- **Fill:** Severity color from the Severity Trio Rule; empty segments are Dungeon Violet
- **The Twelve Segment Rule:** any usage above 0% lights at least one segment — a nearly-empty bar never lies about being untouched
- **Low-HP flash:** at critical severity the leading filled segment pulses (0.8s cycle, dims to 35%) — the JRPG danger blink; suppressed under Reduce Motion and Low Power Mode
- **Accessibility:** carries a "`N` percent used" label

### Limit Row
- **Layout:** Label row (kind + percent + optional active marker) over the bar, 4pt gap; reset caption below — hidden in compact mode except for the binding limit, and promoted to 7pt full white from warn upward
- **Percent color:** severity-derived; kind label stays Pixel White
- **Active marker:** Neon Magenta "◀ ACTIVE" with tooltip "Currently binding limit"
- **Accessibility:** each row is one VoiceOver element speaking a full sentence ("Session, 58 percent used, resets in 2 hours 14 minutes, you'll hit this limit first")

### State Screens
- **Structure:** Centered Display title in Neon Magenta over an SF Mono hint at 80% white, 16pt vertical padding
- **Voice:** Game-flavored titles ("INSERT COIN" for missing credentials), plain-English hints — the skin jokes, the instrument explains

### Section Headers
- **Structure:** Label-size Neon Magenta title over a 1px divider (Pixel White 20%), 4pt gap. This is the app's one deliberate "kicker" system, used for exactly two sections: QUOTA and ACTIVITY 24H

### Sprite Avatar (signature)
- **Structure:** 16×16 pixel bitmap rendered on Canvas at 2–3× scale, single-color fill
- **Color:** In the popover header and menu bar, the sprite wears the headline limit's severity color — the mascot *is* the status indicator
- **Mood:** the mascot's body language follows severity — **calm** (ok/no data: rests on base, blinks one tick in ten), **wary** (warn: walks the 4-step loop at half speed), **agitated** (critical: paces base/alt every tick, no time to blink)
- **Motion:** frame tick every 0.3s in the popover, 1s in the menu bar; all variants hold the resting frame under Low Power Mode and Reduce Motion
- **Mascots:** Claude (wide body, two slit eyes, side arms, four legs), Gemini (twin stars, alt swaps heights), Codex (hex-blossom — six petals around a hollow hexagonal core; alt rotates the petals one step, blink contracts the core), Cursor (I-beam with heavy top/bottom serifs for mass; alt shifts 1px vertically, blink is an intentionally empty frame — a literal text-cursor blink, the sprite test's one documented exception to "every frame draws pixels")

### Menu Bar Item
- **Composition:** One pre-rendered NSImage, 18pt tall, built from one avatar block per enabled *live* provider (16pt sprite + 3pt gap + right block: 7pt pixel percent text above a 14×3pt mini bar at 25% track opacity), joined by an 8pt gap between provider blocks, in fixed catalog order (claude → codex → gemini → cursor). Coming-soon providers never render here
- **Everything monochrome** in each block's own severity color, so every block reads as its own instrument light
- **Text states:** "--" means no data yet for that provider (loading, neutral color); "!" means that provider needs the user (sign in / renew token) and wears Warning Gold — the two must never share a glyph or a color
- **System-appearance aware:** the menu bar sits on the *system's* surface, not the app's dark-only one. Dark menu bar wears the palette trio unchanged; light menu bar wears darker same-hue variants (`#0E7490` / `#B45309` / `#DC2626`, all ≥4.5:1 on the light bar); the no-data neutral flips white ↔ black. The popover itself never changes — dark-only stays doctrine

### Settings Form
- **Structure:** Native SwiftUI toggles and pickers tinted Coin Cyan on Void Purple, grouped under Label-size Neon Magenta section headers (same 1px-divider kicker as the popover), 20pt padding, 340pt wide; control labels in SF Mono per the typography contract
- **PROVIDERS section:** Sits above GENERAL — four toggles in fixed order, coming-soon providers labeled "(coming soon)"; the last enabled *live* provider's toggle is disabled so the menu bar can never go empty (the min-1-live rule). Toggling takes effect immediately via `ProviderHub`
- **Window pinned dark:** the settings window forces dark appearance with a transparent Void Purple title bar, so native control chrome never renders light-theme variants onto the dark surface
- **Native controls are kept native** — no custom-drawn checkboxes; the retro skin stops where macOS affordances begin

## 6. Do's and Don'ts

### Do:
- **Do** derive every quota color from `Severity(percent:)` — Coin Cyan under 60, Warning Gold 60–84, Damage Red at 85+.
- **Do** keep Press Start 2P uppercase and under ~3 words; switch to SF Mono the moment text becomes a sentence.
- **Do** express depth only as Void Purple → Dungeon Violet surface steps or 1px white-opacity strokes.
- **Do** keep the 12-segment bar geometry (20×10pt cells, 2pt gaps) for any new quota display.
- **Do** write state-screen titles in game voice and hints in plain English ("INSERT COIN" + "Install and sign in to Claude Code first").
- **Do** pause all animation under macOS Low Power Mode; the app is a quiet resident.

### Don't:
- **Don't** build anything that reads as a *SaaS analytics dashboard* — no white cards, no metric tiles, no hero-number-with-sparkline layouts (PRODUCT.md anti-reference, verbatim).
- **Don't** let retro cost legibility: never set hints, errors, or activity names in the pixel font, and never render Press Start 2P below 6pt.
- **Don't** use Neon Magenta for severity, data, or bars — it is brand voice only (The Magenta-Is-Brand Rule).
- **Don't** add shadows, glows, or blurs anywhere; the system is flat by doctrine (The Flat Cartridge Rule).
- **Don't** introduce rounded corners, gradients, or gray hex values — corners are 0pt, fills are solid, "gray" is white at reduced opacity.
- **Don't** replace native macOS form controls with custom-drawn retro widgets; the skin never reinvents standard affordances.
