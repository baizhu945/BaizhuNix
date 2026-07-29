# Scripts

## start-chrome-linux.sh

Start Chrome with remote debugging on NixOS / Wayland (Niri).

```bash
bash ~/.config/opencode/skills/chrome-automation/scripts/start-chrome-linux.sh
```

### What it does
1. Checks if Chrome is already running with debug port (9222)
2. Creates persistent profile at `~/.config/chrome-automation`
3. Starts Chrome with `--remote-debugging-port=9222` and Wayland environment
4. Verifies Chrome started successfully

## connect_chrome.sh

Connect to or start Chrome for automation.

```bash
bash ~/.config/opencode/skills/chrome-automation/scripts/connect_chrome.sh
```

### What it does
1. Checks if Chrome is running with debug port
2. If running: shows test command
3. If not running: starts Chrome with debug port and persistent profile
