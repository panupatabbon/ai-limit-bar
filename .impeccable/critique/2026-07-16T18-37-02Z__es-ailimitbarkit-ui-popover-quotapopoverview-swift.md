---
target: popover — QuotaPopoverView (v2)
total_score: 28
p0_count: 0
p1_count: 2
timestamp: 2026-07-16T18-37-02Z
slug: es-ailimitbarkit-ui-popover-quotapopoverview-swift
---
Method: dual-agent (A: design-review agent · B: detector agent)

# Design Critique v2 — Quota Popover (`QuotaPopoverView.swift`)

## Design Health Score — 28/40 (Good)

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | The status item itself is mute — no tooltip, no accessibility description; "!" unexplained until clicked |
| 2 | Match System / Real World | 3 | Spoken weekly reset forces 24-hour `HH:mm` into VoiceOver output regardless of user clock preference (ResetFormatter.swift) |
| 3 | User Control and Freedom | 3 | Tab trap fixed (always opens on Claude); still no manual refresh affordance anywhere |
| 4 | Consistency and Standards | 3 | ⚙/⏻ render in fallback face inside pixelType runs — inconsistent with the deliberate ◀ handling; settings window titled "AI LIMIT BAR" not "Settings" |
| 5 | Error Prevention | 3 | All-hidden NO DATA trap defused by cause-naming; QUIT remains a tiny unconfirmed target beside SETTINGS |
| 6 | Recognition Rather Than Recall | 3 | "◀ ACTIVE" spelled out, "% OF EVENTS" labels shares; severity legend still hover-only |
| 7 | Flexibility and Efficiency | 2 | No global hotkey, no launch-at-login, right-click menu is Quit-only |
| 8 | Aesthetic and Minimalist Design | 3 | Gemini placeholder tab is permanent chrome for a non-feature (user decision: keep until Gemini ships) |
| 9 | Error Recovery | 3 | Offline backoff reaches 300s with no visible retry affordance or schedule |
| 10 | Help and Documentation | 2 | Three contextual tooltips; no About/version/right-click help |
| **Total** | | **28/40** | **Good** |

Prior run scored 28/40. All five prior priority issues are verifiably fixed (persisted tab trap, VoiceOver fragmentation, reset under-weighting at critical, undiscoverable ◀, white menu bar). The total holds at 28 because deeper findings replaced them (mute status item, compact-mode reset suppression) and this pass applied stricter readings on H7/H9/H10.

## Anti-Patterns Verdict

**Not AI slop — hand-tuned, opinionated, coherent.** Rules are named, enforced, and traceable into geometry (popover width derived from the bar grid; severity single-source feeding five channels). Detector clean (`[]`, exit 0) on both UI dir and repo root; greps confirm: 0 shadows/gradients/rounding in code, 0 color literals outside RetroTheme, pixel-font discipline 100% via pixelType (0 stragglers), motion guards ×7, timer tolerance ×3, 76/76 tests.

## What's Working

1. **Severity is a real multi-channel instrument** — one threshold function feeds hue, bar fill, motion (pulse + sprite mood), typography (reset promotion), and speech ("warning"/"critical" in VO). Survives color-blindness, Reduce Motion, and screen readers simultaneously.
2. **Skin/instrument split enforced** — every game title carries a plain hint; NO DATA distinguishes user-caused emptiness from API emptiness; pixel font never touches a sentence.
3. **Row-level VoiceOver genuinely designed** — one spoken sentence per limit with severity and human countdown, children ignored to prevent double-speaking.

## Priority Issues

1. **[P1] Compact mode hides reset for warn/critical non-binding limits** — `showsReset` checks only `isActive` (LimitRowView.swift:26-28) while `resetIsProminent` declares the countdown essential from warn upward; a 90% weekly limit shows a red bar with no reset in compact mode. Fix: `!compact || isActive || severity != .ok`. → /impeccable polish
2. **[P1] The status item is mute** — no `toolTip`, no `setAccessibilityLabel` (StatusItemController.render). VoiceOver's front door is unlabeled; "!" is unexplained on hover; reset time always costs a click. Fix: set both from the same spec each render ("Session 58% — resets in 2h 14m"). → /impeccable harden
3. **[P2] No launch-at-login + fragile Quit** — silent absence after reboot defeats "never hit a limit by surprise"; QUIT is an unpadded 7pt target that terminates instantly. Fix: `SMAppService.mainApp` toggle in Settings; `contentShape` padding on footer targets. → /impeccable harden
4. **[P2] Offline has no visible retry affordance** — backoff reaches 300s in silence; reopen-refresh exists but is untold. Fix: OFFLINE badge becomes "RETRY ▶" or appends "retrying soon". → /impeccable clarify
5. **[P2] Spoken weekly reset forces 24-hour clock** — en_US_POSIX HH:mm is fine as game-look for the pixel label, wrong for VoiceOver speech. Fix: spokenWeeklyReset uses the user's locale/clock. → /impeccable harden

Note: the Gemini placeholder tab was re-flagged (P2, aesthetic) but per the user's explicit earlier decision it stays until Gemini ships; force-open-on-Claude already neutralizes the trap.

## Persona Red Flags

**Alex:** glance is excellent (severity color + % + mini-bar, refreshIfStale on open); reset time still always costs a click; right-click Quit-only; no hotkey.
**Sam:** row sentences/tab traits/footer labels/focus ring all pass; the status-item button itself is unlabeled; QUOTA/ACTIVITY headers lack `.isHeader` traits; 24h forced in speech.
**Jordan:** INSERT COIN model first-contact; "◀ ACTIVE" and "% OF EVENTS" pass; first-run "!" unexplained without tooltip; SESSION=5-hour fact lives only in Settings.

## Minor Observations

⚙/⏻ fallback glyphs inside pixel labels · "% OF EVENTS" repeats twice at floor size/opacity · OFFLINE time duplicates footer UPDATED · reset countdown static while popover open (~60s staleness) · "112%" honest but jumps menu bar width · "!" renders in neutral color (warn-gold would signal faster) · critical-pulse TimelineView keeps firing under Low Power (renders un-pulsed; visual pause only) · Settings "Visible limits" pseudo-label is a third header style · post-show popover frame re-pin risks a one-frame jump.

## Questions to Consider

1. The menu bar answers "how much" in zero clicks and "when does it reset" in never — a status-item tooltip is system chrome, not app chrome; why not give the second question its zero-click answer?
2. Is one opt-in threshold-crossing notification a violation of the quiet-resident doctrine, or the single interruption the mission statement demands?
3. QUOTA rows are unbounded if the API returns many per-model limits — what's the overflow rule when the party grows past the screen?
