# Product

## Register

product

## Users

Developers on macOS who use Claude Code daily under a Claude Pro/Max subscription. They glance at the menu bar mid-work to answer one question fast: "how much quota do I have left, and when does it reset?" Secondary context: checking which skills/agents have been active in the last 24 hours. Sessions are seconds long — a glance at the bar, occasionally a popover open, rarely the settings window.

## Product Purpose

AILimitBar surfaces Claude Pro/Max quota (5-hour session, weekly, per-model limits) as HP-style pixel bars in the macOS menu bar, with reset times and a local activity summary. It exists so developers never hit a limit by surprise. Success = the answer is readable in under a second without opening anything, and the popover answers the follow-up ("which limit, when does it reset") in one more glance. Read-only, private, no telemetry.

## Brand Personality

Playful · Retro · Precise. The app speaks in 8-bit game language — HP bars, sprites, pixel type — but the numbers underneath are exact and instantly legible. Fun is the costume; accuracy is the body. Tone of copy: terse, game-flavored where it costs nothing ("HP", reset countdowns), plain English where clarity matters (errors, settings).

## Anti-references

- **Not a SaaS analytics dashboard.** No white cards, metric tiles, charts-for-the-sake-of-charts, or KPI-row layouts. Quota is a game status screen, not a report.
- Retro flavor must never cost legibility — pixel font for labels/accents, never for dense data the user must parse quickly.

## Design Principles

1. **Glanceable first.** Every surface is optimized for a sub-second read; anything that slows the glance (decoration, extra states, dense layout) gets cut.
2. **Game skin, instrument core.** Retro styling wraps exact numbers — percentages, reset times, and severity states are always literal and unambiguous.
3. **Severity is the signal.** Color and animation exist to communicate quota state (ok → warning → critical), never as ornament.
4. **Quiet resident.** It lives in the menu bar all day: no attention-grabbing motion at rest, animation pauses in Low Power Mode, nothing interrupts the user's real work.
5. **Trust through restraint.** Read-only, local-only, no telemetry — the UI mirrors that honesty: no upsells, no badges, no fake urgency.

## Accessibility & Inclusion

Baseline: readable. Text on dark surfaces stays high-contrast (white/near-white on the deep purple backgrounds); severity states are distinguishable by more than hue alone (position, fill level, label). No formal WCAG target beyond keeping everything comfortably legible at menu-bar and popover sizes. Menu bar animation already pauses under macOS Low Power Mode.
