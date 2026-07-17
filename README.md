# ai-limit-bar

A retro 8-bit menu bar app for macOS that shows your Claude Pro/Max
subscription quota — session (5-hour), weekly, and per-model limits with
used %, HP-style pixel bars, and reset times.

<img width="800" height="508" alt="CleanShot 2569-07-15 at 13 48 24" src="https://github.com/user-attachments/assets/88d29daa-ffbb-4071-8f92-ea71add77b6a" />

## Requirements

- macOS 14+
- [Claude Code](https://claude.com/claude-code) installed and signed in
  (this app reads the quota through Claude Code's credentials)

## Install

Download `AILimitBar.app` from Releases. The app is not notarized yet:
right-click → Open on first launch (or `xattr -d com.apple.quarantine AILimitBar.app`).

Or build from source: `./Scripts/bundle.sh` (needs Xcode 15+ command line tools).

## Security

- **Read-only.** The app reads Claude Code's OAuth access token from the
  macOS Keychain (item "Claude Code-credentials") with a fallback to
  `~/.claude/.credentials.json`. It never writes to either store and never
  refreshes tokens.
- On first launch macOS shows a Keychain access dialog — click **Always
  Allow** so you aren't prompted again. Because release builds are
  ad-hoc signed (not notarized), rebuilding from source or updating to a
  new build changes the app's signature and will trigger the Keychain
  prompt again.
- The token stays in memory, is never logged, and is sent to exactly one
  place: `https://api.anthropic.com/api/oauth/usage` over HTTPS.
- No telemetry, no analytics, no auto-update pings.
- The activity section scans `~/.claude/projects` locally and keeps only
  name+count aggregates in memory.
- Note: the usage endpoint is the same one Claude Code's `/usage` command
  uses; it is not officially documented and may change.

## Settings

Launch at login · show/hide menu bar % · pick which
limit the % tracks · choose visible limits · compact rows · PROVIDERS.

### Provider Tabs

Pick which providers to track in Settings → PROVIDERS (Claude and Codex live
today; Gemini and Cursor appear as coming-soon tabs until their adapters
land). The menu bar shows one pixel avatar per live provider; the popover
opens on whichever provider most needs attention.

### ACTIVITY 24H

Reads aggregate counts (skill/agent names only) from your local Claude Code
transcripts; nothing leaves your machine.

## Behavior

- Each live provider's avatar wears its own severity color (cyan → gold →
  red) and adapts to light/dark menu bars; `!` means that provider needs you
  (sign in / renew token), `--` means its data hasn't loaded yet.
- All animation pauses while macOS Low Power Mode is on, and respects the
  system Reduce Motion setting.

## License

MIT. Press Start 2P font © CodeMan38, SIL Open Font License 1.1.
