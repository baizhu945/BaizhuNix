---
name: chrome-automation
description: Connect to and control Google Chrome browser using agent-browser with CDP (Chrome DevTools Protocol). Use when the user wants to automate their existing Chrome browser, see browser actions in real-time, or needs to control the Chrome instance they're already using. Handles installation, setup, connecting via remote debugging, and all browser automation tasks with live visual feedback.
allowed-tools: Bash(*)
---

# Chrome Browser Automation with Real-time Control

Control the user's Google Chrome browser using agent-browser connected via Chrome DevTools Protocol (CDP). All actions are visible in real-time in the user's browser window.

## Prerequisites (NixOS)

`agent-browser` and `google-chrome-stable` are already installed via Nix. No manual setup needed.

- `agent-browser` — available in `$PATH` (v0.27.0)
- `google-chrome-stable` — available in `$PATH`
- Wayland display: `wayland-1` (Niri compositor)
- Screenshot tool: `grim` for Wayland screenshots, `cc-connect` for sending

## Quick Start

### Start Chrome (NixOS / Wayland)

```bash
nohup env WAYLAND_DISPLAY=wayland-1 XDG_SESSION_TYPE=wayland google-chrome-stable \
  --remote-debugging-port=9222 \
  --user-data-dir=$HOME/.config/chrome-automation \
  --no-first-run \
  --disable-vulkan --disable-gpu \
  > /tmp/opencode/chrome.log 2>&1 &
disown
sleep 5
```

If Chrome fails to start on Wayland, add `--disable-software-rasterizer --ozone-platform-hint=auto`.

### Connect and verify

```bash
agent-browser --cdp 9222 get url
agent-browser --cdp 9222 snapshot -i
```

### Close Chrome

```bash
pkill -f "chrome.*remote-debugging-port=9222"
```

## Core Workflow

**CRITICAL: Always show browser state to user after each significant action using screenshots.**

1. **Connect**: Ensure Chrome running with remote debugging port 9222
2. **Navigate**: Open pages using `--cdp 9222` flag
3. **Snapshot**: Get interactive elements with `snapshot -i`
4. **Interact**: Use element refs (@e1, @e2, etc.)
5. **Screenshot**: Capture state and show to user
6. **Report**: Describe what's visible in browser

### Standard operation pattern

```bash
# Navigate
agent-browser --cdp 9222 open https://example.com
sleep 2

# Get interactive elements
agent-browser --cdp 9222 snapshot -i

# Screenshot to show user
agent-browser --cdp 9222 screenshot /tmp/opencode/state.png

# Interact
agent-browser --cdp 9222 fill @e1 "text"
agent-browser --cdp 9222 press Enter

# Capture result
sleep 2
agent-browser --cdp 9222 screenshot /tmp/opencode/result.png
```

## Chrome Connection

### Start Chrome with persistent profile

Use the command in "Quick Start". Profile stored at `~/.config/chrome-automation`.

### Check if Chrome is already running

```bash
ss -tlnp | grep 9222
curl -s http://127.0.0.1:9222/json/version
```

### "No page found" error

Chrome needs at least one page open:

```bash
agent-browser --cdp 9222 open "about:blank"
sleep 2
agent-browser --cdp 9222 snapshot -i
```

### Connection refused

```bash
ss -tlnp | grep 9222
# If no output, Chrome is not running — start it first
```

## Checking Download Status

```bash
agent-browser --cdp 9222 open "chrome://downloads"
sleep 2
agent-browser --cdp 9222 snapshot -i
# If only heading and searchbox show — nothing is downloading
# If download items appear — something is downloading
```

## Screenshot with grim (Wayland)

```bash
grim /tmp/opencode/screenshot.png
cc-connect send --image /tmp/opencode/screenshot.png
```

## Usage Patterns

### Web Search

```bash
agent-browser --cdp 9222 open xiaohongshu.com
sleep 2
agent-browser --cdp 9222 snapshot -i
agent-browser --cdp 9222 fill @e2 "search keyword"
agent-browser --cdp 9222 press Enter
sleep 2
agent-browser --cdp 9222 screenshot /tmp/opencode/result.png
```

### Form Automation

```bash
agent-browser --cdp 9222 open https://example.com/form
sleep 2
agent-browser --cdp 9222 snapshot -i
agent-browser --cdp 9222 fill @e1 "John Doe"
agent-browser --cdp 9222 fill @e2 "john@example.com"
agent-browser --cdp 9222 click @e3
sleep 2
agent-browser --cdp 9222 screenshot /tmp/opencode/submitted.png
```

### Handle Security Verification

When sites show security verification (QR codes, captchas):

```bash
agent-browser --cdp 9222 screenshot /tmp/opencode/verification.png
# Tell user: "Site requires verification — please complete in browser window"
# User completes verification manually
agent-browser --cdp 9222 get url
agent-browser --cdp 9222 snapshot -i
```

## Real-time Feedback Protocol

**MANDATORY: Provide visual feedback after every significant action**

After navigation, clicks, or form submissions:
1. Take screenshot
2. Get current URL
3. Describe what's visible to user

## Command Reference

All commands use this format:

```bash
agent-browser --cdp 9222 <command>
```

### Essential Commands

**Navigation:**
- `open <url>` — Navigate to URL
- `back` — Go back
- `reload` — Reload page
- `get url` — Get current URL

**Page Analysis:**
- `snapshot -i` — Get interactive elements (RECOMMENDED)
- `get title` — Get page title

**Interaction:**
- `click @e1` — Click element
- `fill @e1 "text"` — Fill input
- `press Enter` — Press key
- `scroll down 500` — Scroll

**Capture:**
- `screenshot path.png` — Screenshot
- `get text @e1` — Get element text

**JavaScript:**
- `eval "code"` — Execute JavaScript

For complete command reference, see `references/commands.md`.

## Troubleshooting

### "Daemon not found" error

```bash
which agent-browser
agent-browser --version
```

### Chrome crashes on Wayland

Start with additional flags:

```bash
google-chrome-stable --remote-debugging-port=9222 \
  --user-data-dir=$HOME/.config/chrome-automation \
  --no-first-run --disable-vulkan --disable-gpu \
  --disable-software-rasterizer --ozone-platform-hint=auto
```

### "No page found" error

```bash
agent-browser --cdp 9222 open "about:blank"
sleep 2
```

## Best Practices

1. **Start Chrome first** — Chrome must be running with `--remote-debugging-port=9222` before using agent-browser
2. **Use persistent profile** — Use `~/.config/chrome-automation` to preserve login states
3. **Always screenshot** — Show user what's happening after every significant action
4. **Wait after navigation** — Use `sleep 2` after page loads
5. **Check URL** — Verify navigation succeeded
6. **Handle security** — Inform user, wait for manual completion
7. **Re-snapshot** — Get fresh refs after DOM changes
8. **Descriptive paths** — Save screenshots with clear names to `/tmp/opencode/`
9. **Report state** — Describe browser content to user

## Profile Management

### Profile location

| Platform | Automation Profile Location |
|----------|----------------------------|
| NixOS/Linux | `~/.config/chrome-automation` |

### Reset automation profile

```bash
rm -rf ~/.config/chrome-automation
```

This profile is separate from your daily Chrome, so automation activities won't affect your main browser.
