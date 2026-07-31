#!/bin/bash
# Start Chrome with automation profile on NixOS/Wayland (Niri)
set -e
DEBUG_PORT="${1:-9222}"
CHROME_AUTOMATION_DIR="$HOME/.config/chrome-automation"

if ss -tlnp | grep -q ":$DEBUG_PORT"; then
  echo "Chrome already running with debug port $DEBUG_PORT"
  exit 0
fi

mkdir -p "$CHROME_AUTOMATION_DIR"
mkdir -p /tmp/opencode

echo "Starting Chrome with debug port $DEBUG_PORT..."
nohup env WAYLAND_DISPLAY=wayland-1 XDG_SESSION_TYPE=wayland google-chrome-stable \
  --remote-debugging-port=$DEBUG_PORT \
  --user-data-dir="$CHROME_AUTOMATION_DIR" \
  --no-first-run \
  --disable-vulkan --disable-gpu \
  > /tmp/opencode/chrome.log 2>&1 &
disown

sleep 5

if ss -tlnp | grep -q ":$DEBUG_PORT"; then
  echo "Chrome started on port $DEBUG_PORT"
else
  echo "Failed to start Chrome" >&2
  exit 1
fi
