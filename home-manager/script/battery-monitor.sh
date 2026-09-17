#!/usr/bin/env bash

UPOWER="@upower@/bin/upower"
GREP="@grep@/bin/grep"
NOCTALIA_V4="@noctalia@/bin/noctalia-shell"
NOCTALIA_V5="noctalia"
BATTERY_PATH="/org/freedesktop/UPower/devices/battery_BAT0"
JQ="@jq@/bin/jq"
WLRRANDR="@wlrrandr@/bin/wlr-randr"

get_state() {
  "$UPOWER" -i "$BATTERY_PATH" \
    | "$GREP" -E "^\s+state:" \
    | awk '{print $2}'
}

set_low_refresh() {
  output=$(niri msg -j outputs \
    | "$JQ" -r '.[] | select(.make == "China Star Optoelectronics Technology Co., Ltd" and .model == "MNG007DA5-3") | .name')
  if [ -n "$output" ]; then
    "$WLRRANDR" --output "$output" --mode 2560x1600@60.001999
  fi
}

prev_state=$(get_state)

"$UPOWER" --monitor | while read -r line; do
  if echo "$line" | "$GREP" -q "battery_BAT0"; then
    current_state=$(get_state)

    if [ "$current_state" = "discharging" ] && [ "$prev_state" != "discharging" ]; then
      sleep 3
      confirm_state=$(get_state)
      if [ "$confirm_state" = "discharging" ]; then
        if "$NOCTALIA_V5" msg status >/dev/null 2>&1; then
          "$NOCTALIA_V5" msg theme-mode-set dark
          "$NOCTALIA_V5" msg power-set power-saver
        else
          "$NOCTALIA_V4" ipc call darkMode setDark
          "$NOCTALIA_V4" ipc call powerProfile set "powersaver"
        fi
        set_low_refresh
      fi
    fi

    prev_state="$current_state"
  fi
done
