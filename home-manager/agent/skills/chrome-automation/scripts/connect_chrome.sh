#!/bin/bash
# Connect to or start Chrome with remote debugging on NixOS/Wayland
PORT="${1:-9222}"

echo "Checking for Chrome with remote debugging on port $PORT..."

if ss -tlnp | grep -q ":$PORT"; then
  echo "Chrome already running with remote debugging on port $PORT"
  echo ""
  echo "Test connection with:"
  echo "  agent-browser --cdp $PORT get url"
  exit 0
fi

echo "Starting Chrome with remote debugging on port $PORT..."

mkdir -p /tmp/opencode
nohup env WAYLAND_DISPLAY=wayland-1 XDG_SESSION_TYPE=wayland google-chrome-stable \
  --remote-debugging-port=$PORT \
  --user-data-dir="$HOME/.config/chrome-automation" \
  --no-first-run \
  --disable-vulkan --disable-gpu \
  > /tmp/opencode/chrome.log 2>&1 &
disown

sleep 5

if ss -tlnp | grep -q ":$PORT"; then
  echo ""
  echo "Chrome started successfully on port $PORT"
  echo ""
  echo "Test connection with:"
  echo "  agent-browser --cdp $PORT snapshot -i"
else
  echo "Failed to start Chrome" >&2
  exit 1
fi
