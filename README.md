# ai-limit-bar

A retro 8-bit menu bar app for macOS that tracks your AI coding quota across
providers — session (5-hour), weekly, and per-model limits with used %,
HP-style pixel bars, and reset times. Live for **Claude** (Pro/Max) and
**Codex**; Gemini and Cursor are coming soon.

<img width="800" height="508" alt="CleanShot 2569-07-15 at 13 48 24" src="https://github.com/user-attachments/assets/88d29daa-ffbb-4071-8f92-ea71add77b6a" />

## Requirements

- macOS 14+
- At least one supported CLI installed and signed in — the app reads each
  provider's quota through that CLI's own local credentials:
  - [Claude Code](https://claude.com/claude-code) for Claude
  - [Codex CLI](https://github.com/openai/codex) for Codex

## Install

Download `AILimitBar.app` from Releases. The app is not notarized yet:
right-click → Open on first launch (or `xattr -d com.apple.quarantine AILimitBar.app`).

Or build from source: `./Scripts/bundle.sh` (needs Xcode 15+ command line tools).

## Security

- **Read-only, always.** Each provider reads only its own CLI's local
  credentials, never writes them, and never refreshes tokens. Tokens stay
  in memory and are never logged.
- **Claude:** reads the OAuth access token from the macOS Keychain (item
  "Claude Code-credentials") with a fallback to `~/.claude/.credentials.json`,
  and sends it only to `https://api.anthropic.com/api/oauth/usage`.
- **Codex:** reads `tokens.access_token` from `~/.codex/auth.json` (the
  `id_token`, `refresh_token`, and `account_id` fields are never touched),
  and sends it only to `https://chatgpt.com/backend-api/wham/usage`.
- On first launch macOS shows a Keychain access dialog (for Claude) — click
  **Always Allow** so you aren't prompted again. Because release builds are
  ad-hoc signed (not notarized), rebuilding from source or updating to a new
  build changes the app's signature and will trigger the Keychain prompt
  again.
- No telemetry, no analytics, no auto-update pings.
- The activity section scans `~/.claude/projects` locally and keeps only
  name+count aggregates in memory.
- Note: both usage endpoints are the undocumented ones the CLIs' own usage
  commands use; they are not officially supported and may change.

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
