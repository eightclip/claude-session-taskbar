# Claude Session Taskbar

A native macOS menu bar app that shows your **real-time Claude usage** — matching exactly what you see on [claude.ai/settings/usage](https://claude.ai/settings/usage).

![macOS](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5-orange)

## What It Does

- **Menu bar progress indicator** — a small coral-colored bar fills up as you use Claude
- **Click to expand** — shows session (5h window) and weekly (7d) usage with Claude-branded UI
- **Reset countdowns** — shows exactly when your session and weekly limits reset
- **Status indicators** — green (allowed), amber (warning), red (rate limited)
- **Color shifts** from coral to amber to red as usage approaches limits
- **Tracks ALL Claude usage** — Chat, Cowork, and Code combined (not just Code)
- **Auto-refreshes** every 60 seconds

## Quick Start

```bash
git clone https://github.com/eightclip/claude-session-taskbar.git
cd "Claude Session Taskbar"
chmod +x build.sh
./build.sh
open ClaudeSessionTaskbar.app
```

### Install permanently (optional)

```bash
./build.sh --install
```

This copies the app to `~/Applications/` and adds it to your Login Items so it starts on boot.

## Requirements

- macOS 13+ (Ventura or later)
- Swift toolchain (Xcode Command Line Tools: `xcode-select --install`)
- **Claude Code** installed and logged in (the app reads your credentials from the macOS Keychain)

## How It Works

1. When you install Claude Code and log in, it stores an OAuth token in your **macOS Keychain**
2. The app reads this token at runtime (never stored in any file or config)
3. It makes a minimal API call to Anthropic's `/v1/messages` endpoint (~9 tokens, essentially free)
4. Anthropic returns **rate limit headers** with your exact usage percentages — the same data shown on claude.ai/settings/usage
5. The app displays these percentages in your menu bar

This means the numbers you see in the taskbar match exactly what claude.ai shows — including all usage across Chat, Cowork, and Code.

## Security

- **No API keys in source code** — your token is read from the macOS Keychain at runtime
- **No tokens in config files** — the only config is a refresh interval
- **Per-user isolation** — each person's Keychain contains their own Claude Code credentials
- **Minimal API cost** — each refresh uses ~9 tokens (Haiku model), costing essentially $0.00/day

## Configuration

On first launch, a config file is created at `~/.claude-taskbar.json`:

```json
{
  "refreshIntervalSeconds": 60
}
```

| Setting | Description | Default |
|---|---|---|
| `refreshIntervalSeconds` | How often the app checks usage (seconds) | 60 |

Click the gear icon in the dropdown to edit settings. Changes are picked up on the next refresh.

## Quit / Restart

- **Quit**: Click the menu bar item, then click the power icon
- **Restart**: `open ~/Applications/ClaudeSessionTaskbar.app`

## Troubleshooting

**"No Claude Code credentials found"**
You need Claude Code installed and logged in. The app reads your OAuth token from the macOS Keychain entry created by Claude Code.

**"Token expired — restart Claude Code"**
Your OAuth token has expired. Open Claude Code and start a new session — this refreshes the Keychain entry.

**Build fails with SDK mismatch**
The build script auto-selects a compatible SDK. If it still fails, install Xcode Command Line Tools: `xcode-select --install`

**Numbers don't match claude.ai exactly**
The app refreshes every 60 seconds by default. Click the refresh button for an immediate update. Small differences may occur due to timing.
