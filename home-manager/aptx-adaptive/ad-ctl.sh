#!/usr/bin/env bash
# ad-ctl - control the Sennheiser MOMENTUM 5 aptX Adaptive link mode.
#
#   ad-ctl status          show adapter, headset, codec and the current mode
#   ad-ctl toggle          flip between hq and ll
#   ad-ctl switch hq|ll    select a mode explicitly
#
# The link uses theacrat/aptx-linux's clean-room SPA encoder (aptX slot,
# ABI-17 port).  That plugin takes its mode from
#
#   * APTX_ADAPTIVE_DEFAULT_MODE - the mode a fresh connection starts in
#     (systemd drop-in, currently hq).  With the codec bound to the aptx slot
#     this wins over the PipeWire settings key, verified by reconnecting the
#     headset while that key said ll: the link still came up in HQ.
#   * the codec's `quality` property (SPA_PROP_QUALITY: 0 = HQ, 1 = LL), which
#     is what this script drives at runtime.
#
# Switching through the property takes effect immediately (the codec
# re-negotiates, a short glitch is normal).  A fresh connection - headset
# reconnect, pipewire restart - starts from APTX_ADAPTIVE_DEFAULT_MODE again.

set -euo pipefail

readonly QUALITY_HQ=0
readonly QUALITY_LL=1

readonly C_RESET=$'\033[0m'
readonly C_BOLD=$'\033[1m'
readonly C_DIM=$'\033[2m'

# Labels are padded by hand: they are double-width characters, so printf's
# byte-based field width would not line the columns up.
readonly L_ADAPTER='蓝牙适配器  '
readonly L_HEADSET='耳机        '
readonly L_CODEC='编码解码器  '
readonly L_RATE='链路采样率  '
readonly L_POLICY='采样率策略  '
readonly L_MODE='当前模式    '
readonly L_BOOT='重连后默认  '
readonly L_PLUGIN='插件        '

die() { printf 'ad-ctl: %s\n' "$*" >&2; exit 1; }
bold() { printf '%s%s%s' "$C_BOLD" "$1" "$C_RESET"; }
dim() { printf '%s%s%s' "$C_DIM" "$1" "$C_RESET"; }

usage() {
  cat <<'EOF'
usage: ad-ctl <command>

  status           show adapter, headset, codec, sample rate and mode
  toggle           switch between hq and ll
  switch <mode>    select a mode: hq (427 kbps / 12 ms) or ll (270 kbps / 10 ms)
  rate <hz>        pin the link sample rate: 44100, 48000, 96000, or default
  rate auto        follow the playing stream's rate (the HQ policy)
  recover          heavier recovery: profile cycle, then a service restart
  watch            run the adaptive watcher in the foreground (user service)

The mode applies to the running link; after a reconnect the link starts from
APTX_ADAPTIVE_DEFAULT_MODE (currently hq).  The sample rate is chosen when the
A2DP transport is set up, so `rate` restarts WirePlumber and reconnects the
headset; 96000 runs HQ only (the encoder refuses low latency there).
EOF
}

# Written by `ad-ctl rate`; the system module owns the other fragments in this
# directory.
readonly RATE_CONF="$HOME/.config/wireplumber/wireplumber.conf.d/95-aptx-adaptive-rate.conf"
readonly ADDRESS_STATE="$HOME/.local/state/ad-ctl/headset-address"
# The plugin reads this on every codec configuration, so the rate can change
# without restarting the monitor that caches the configured preference.
readonly RATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/aptx-adaptive-rate"
readonly LOCK_FILE="$HOME/.local/state/ad-ctl/lock"
readonly PROFILE_SETTLE=4
readonly AD_WAIT=15

log() {
  [ -n "${AD_CTL_VERBOSE:-}" ] || return 0
  printf 'ad-ctl[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2
}

wait_for_rate() {
  local want=$1 seconds=$2 got=''
  for _ in $(seq 1 "$seconds"); do
    got=$(link_rate 2>/dev/null || true)
    if [ -n "$got" ] && { [ -z "$want" ] || [ "$got" = "$want" ]; }; then
      printf '%s' "$got"
      return 0
    fi
    sleep 1
  done
  printf '%s' "$got"
  return 1
}


# Codec the A2DP sink currently reports, or nothing when there is no sink.
ad_codec() {
  ad_sinks 2>/dev/null | head -1 | cut -f3
}

# The headset's address: the running sink if there is one, otherwise the one we
# saw last, otherwise whatever BlueZ currently has connected.
headset_address() {
  local address
  address=$(ad_sinks 2>/dev/null | head -1 | cut -f2 \
    | sed -n 's/^bluez_output\.\([0-9A-Fa-f_]*\)\..*/\1/p' | tr '_' ':')
  if [ -z "$address" ]; then
    address=$(cat "$ADDRESS_STATE" 2>/dev/null || true)
  fi
  if [ -z "$address" ]; then
    address=$(bluetoothctl devices Connected 2>/dev/null | awk '/^Device/ { print $2; exit }')
  fi
  if [ -z "$address" ]; then
    # Only when there is exactly one paired device, so we cannot pick wrongly.
    local paired
    paired=$(bluetoothctl devices Paired 2>/dev/null | awk '/^Device/ { print $2 }')
    [ "$(printf '%s\n' "$paired" | grep -c .)" = 1 ] && address=$paired
  fi
  printf '%s' "$address"
}

remember_address() {
  local address
  address=$(ad_sinks 2>/dev/null | head -1 | cut -f2 \
    | sed -n 's/^bluez_output\.\([0-9A-Fa-f_]*\)\..*/\1/p' | tr '_' ':')
  [ -n "$address" ] || return 0
  mkdir -p "$(dirname "$ADDRESS_STATE")"
  printf '%s\n' "$address" > "$ADDRESS_STATE"
}

# Wait until the A2DP sink reports an aptX Adaptive codec.
wait_for_ad() {
  local seconds=$1
  for _ in $(seq 1 "$seconds"); do
    [ "$(ad_codec)" = 'aptx_adaptive' ] && return 0
    sleep 1
  done
  return 1
}

# Every command that touches the link goes through this first: a link that fell
# back to HFP/CVSD must never be measured or reported as if it were Adaptive.
# Returns non-zero (with an explanation) when the link cannot be recovered.
# What the bluez5 nodes currently report, for diagnostics.
bluez_state() {
  pw-dump 2>/dev/null | python3 -c '
import json, sys
lines = []
for obj in json.load(sys.stdin):
    props = (obj.get("info") or {}).get("props") or {}
    codec = props.get("api.bluez5.codec")
    if codec:
        lines.append("%s/%s" % (props.get("api.bluez5.profile", "?"), codec))
print(", ".join(lines) if lines else "no bluez node")
'
}

ensure_ad_link() {
  local address
  remember_address

  wait_for_ad 3 && return 0

  address=$(headset_address)
  if [ -z "$address" ]; then
    printf 'ad-ctl: 找不到耳机地址；请先手动连接一次耳机\n' >&2
    return 1
  fi

  # One cycle, then a patient wait; a second only if the first landed on the
  # hands-free profile.  Never restart WirePlumber and never reconnect the
  # headset here - those are what pushed the link down before, and they are
  # available explicitly through "ad-ctl recover".
  cycle_a2dp_profile || true
  wait_for_ad 20 && return 0
  log 'first cycle did not bring Adaptive back, trying once more'
  cycle_a2dp_profile || true
  wait_for_ad 20 && return 0

  printf 'ad-ctl: 链路仍不是 aptX Adaptive（bluez 现状：%s）\n' "$(bluez_state)" >&2
  printf 'ad-ctl: 需要更重的恢复请显式执行 ad-ctl recover\n' >&2
  return 1
}

bluez_device_id() {
  pw-dump 2>/dev/null | python3 -c '
import json, sys
for obj in json.load(sys.stdin):
    if obj.get("type") != "PipeWire:Interface:Device":
        continue
    props = (obj.get("info") or {}).get("props") or {}
    if props.get("device.api") == "bluez5" and props.get("api.bluez5.address"):
        print(obj["id"])
        break
'
}

# Profile the device runs right now (a2dp-sink index, e.g. 131079).
active_profile_index() {
  local dev=$1
  [ -n "$dev" ] || return 1
  pw-dump 2>/dev/null | python3 -c '
import json, sys
want = sys.argv[1]
for obj in json.load(sys.stdin):
    if str(obj.get("id")) != want:
        continue
    params = (obj.get("info") or {}).get("params") or {}
    for entry in params.get("Profile", []):
        if isinstance(entry, dict) and entry.get("index") is not None:
            print(entry["index"])
            break
' "$dev"
}

# Index of the A2DP sink profile WirePlumber would prefer, i.e. the available
# a2dp-sink entry with the highest priority.  Cycling to the *active* profile
# would keep a hands-free profile in place, which is how the headset ended up on
# CVSD during an earlier test.
# Index of a profile by name, preferring the names in the order given.
profile_index_by_name() {
  local dev=$1
  shift
  [ -n "$dev" ] || return 1
  pw-cli enum-params "$dev" EnumProfile 2>/dev/null | python3 -c '
import re, sys

wanted = sys.argv[1:]
best = None
pending = None
current = {}
for line in sys.stdin:
    match = re.search(r"Profile:(\w+) \(\d+\)", line)
    if match:
        pending = match.group(1)
        continue
    if not pending:
        continue
    match = re.match(r"\s*(?:Int|String|Id|Bool)\s+\"?(.*?)\"?\s*$", line)
    if not match:
        continue
    current[pending] = match.group(1)
    if pending == "priority":
        name = str(current.get("name", ""))
        try:
            index = int(current.get("index", ""))
            priority = int(current["priority"])
        except ValueError:
            current = {}
            pending = None
            continue
        for rank, candidate in enumerate(wanted):
            if name == candidate:
                score = (len(wanted) - rank, priority)
                if best is None or score > best[0]:
                    best = (score, index)
                break
        current = {}
    pending = None
if best:
    print(best[1])
' "$@"
}

# The A2DP sink profile WirePlumber would pick on its own.
a2dp_profile_index() {
  profile_index_by_name "$1" a2dp-sink a2dp-sink-aptx a2dp-sink-sbc
}

# A different A2DP codec, used to force a fresh configuration.
other_a2dp_profile_index() {
  profile_index_by_name "$1" a2dp-sink-sbc a2dp-sink-sbc_xq a2dp-sink-aac
}

# Rebuild the A2DP transport on the existing connection without leaving A2DP.
# Cycling through "off" does not renegotiate the codec - BlueZ keeps the running
# configuration - so the profile is bounced through another codec instead, which
# produces a fresh AVDTP SetConfiguration (measured: 0 HCI disconnect events).
force_reconfigure() {
  local dev a2dp other
  dev=$(bluez_device_id)
  [ -n "$dev" ] || return 1
  a2dp=$(a2dp_profile_index "$dev" 2>/dev/null || true)
  other=$(other_a2dp_profile_index "$dev" 2>/dev/null || true)
  [ -n "$a2dp" ] && [ -n "$other" ] && [ "$a2dp" != "$other" ] || return 1

  log "reconfigure: dev=$dev bounce=$other back=$a2dp"
  wpctl set-profile "$dev" "$other" >/dev/null 2>&1 || { log 'bounce step failed'; return 1; }
  sleep "$PROFILE_SETTLE"
  wpctl set-profile "$dev" "$a2dp" >/dev/null 2>&1 || { log 'return step failed'; return 1; }
  log 'reconfigure done'
}

# Recovery only: bring A2DP back when the headset sits on the hands-free
# profile or has no profile at all.
cycle_a2dp_profile() {
  local dev index
  dev=$(bluez_device_id)
  if [ -z "$dev" ]; then
    return 1
  fi
  index=$(a2dp_profile_index "$dev" 2>/dev/null || true)
  if [ -z "$index" ]; then
    index=$(active_profile_index "$dev" 2>/dev/null || true)
  fi
  [ -n "$index" ] && [ "$index" != 0 ] || return 1
  log "profile cycle: dev=$dev a2dp=$index"
  wpctl set-profile "$dev" 0 >/dev/null 2>&1 || { log 'off step failed'; return 1; }
  sleep "$PROFILE_SETTLE"
  wpctl set-profile "$dev" "$index" >/dev/null 2>&1 || { log 'a2dp step failed'; return 1; }
  log 'profile cycle done'
}

write_rate_conf() {
  local rate=$1 mode=${2:-pin}
  if [ -z "$rate" ]; then
    rm -f "$RATE_CONF"
    return 0
  fi
  mkdir -p "$(dirname "$RATE_CONF")"
  cat > "$RATE_CONF" <<EOF
# Written by \`ad-ctl\`; ad-ctl:mode=$mode
# Selects the preferred sample rate the bluez5 monitor offers the codec.
# "auto" lets \`ad-ctl watch\` follow the playing stream; "pin" fixes it.
monitor.bluez.properties = {
  "bluez5.default.rate" = $rate
}
EOF
}

# "auto", "pin", or "none" when the file is not ours.
rate_conf_mode() {
  if grep -q 'ad-ctl:mode=auto' "$RATE_CONF" 2>/dev/null; then
    printf 'auto'
  elif [ -f "$RATE_CONF" ]; then
    printf 'pin'
  else
    printf 'none'
  fi
}

# Sample rates of the streams that are playing right now.
stream_rates() {
  pw-dump 2>/dev/null | python3 -c '
import json, sys
rates = set()
for obj in json.load(sys.stdin):
    if obj.get("type") != "PipeWire:Interface:Node":
        continue
    info = obj.get("info") or {}
    props = info.get("props") or {}
    if props.get("media.class") != "Stream/Output/Audio":
        continue
    if info.get("state") != "running":
        continue
    params = info.get("params") or {}
    for key in ("Format", "EnumFormat"):
        found = None
        for entry in params.get(key, []):
            if isinstance(entry, dict) and entry.get("rate"):
                found = int(entry["rate"])
                break
        if found:
            rates.add(found)
            break
for rate in sorted(rates):
    print(rate)
'
}

# Link rate that fits what is playing: the 44.1 family maps to 44100, the 48
# family to 48000 or 96000 (the vendor codec halves 88.2/192 kHz the same way).
# Highest rate wins when several streams play at once; empty means idle.
target_rate() {
  local rate target=''
  while read -r rate; do
    [ -n "$rate" ] || continue
    case "$rate" in
      44100 | 88200 | 176400 | 352800) rate=44100 ;;
      48000) rate=48000 ;;
      96000 | 192000 | 384000) rate=96000 ;;
      *) continue ;;
    esac
    if [ -z "$target" ] || [ "$rate" -gt "$target" ]; then
      target=$rate
    fi
  done < <(stream_rates 2>/dev/null)
  printf '%s' "$target"
}

# Serialise everything that touches the link: the watcher service and a manual
# command rebuilding the transport at the same time is what pushed the headset
# onto the hands-free profile.  "try" skips when another operation holds it.
LOCK_HELD=''
acquire_lock() {
  # Re-entrant within one process; the watcher releases it after each pass so a
  # manual command can take over.
  [ -n "$LOCK_HELD" ] && return 0
  mkdir -p "$(dirname "$LOCK_FILE")"
  exec 9>"$LOCK_FILE" || return 1
  if [ "${1:-wait}" = try ]; then
    flock -n 9 || return 1
  else
    flock -w 90 9 || return 1
  fi
  LOCK_HELD=1
}

release_lock() {
  [ -n "$LOCK_HELD" ] || return 0
  exec 9>&- 2>/dev/null || true
  LOCK_HELD=''
}

# The user-facing command: an explicit rate pins the link, `auto` hands it to
# the watcher, `default` drops the override.
cmd_rate() {
  acquire_lock wait || die '另一个 ad-ctl 操作仍在进行，请稍后再试'
  case "${1:-}" in
    44100 | 48000 | 96000) apply_rate "$1" pin ;;
    auto)
      local want
      want=$(target_rate)
      [ -n "$want" ] || want=48000
      apply_rate "$want" auto
      ;;
    default) apply_rate '' pin ;;
    *) die 'rate 需要一个参数：44100 | 48000 | 96000 | auto | default' ;;
  esac
}

# Core: set the preferred rate and the policy marker, then verify what the link
# actually negotiated.  $2 is "auto" (the watcher may retarget it) or "pin".
apply_rate() {
  local want=$1 conf_mode=${2:-pin} got started elapsed
  acquire_lock wait || die '另一个 ad-ctl 操作仍在进行，请稍后再试'
  remember_address

  write_rate_conf "$want" "$conf_mode"
  if [ -n "$want" ]; then
    printf '%s\n' "$want" > "$RATE_FILE"
  else
    rm -f "$RATE_FILE"
  fi

  started=$(date +%s)
  got=$(link_rate 2>/dev/null || true)
  log "apply_rate want=${want:-default} current=${got:-none} mode=$conf_mode"

  if [ -n "$want" ] && [ "${got:-}" != "$want" ]; then
    ensure_ad_link || return 1
    force_reconfigure || log 'reconfigure failed'
    got=$(wait_for_rate "$want" "$AD_WAIT" || true)
    if [ "${got:-}" != "$want" ]; then
      log "saw ${got:-nothing} after the first reconfigure, retrying once"
      force_reconfigure || true
      got=$(wait_for_rate "$want" "$AD_WAIT" || true)
    fi
  fi
  elapsed=$(( $(date +%s) - started ))

  if [ -z "${got:-}" ]; then
    printf 'ad-ctl: 无法读回链路采样率（耳机未连接？）\n' >&2
    return 1
  fi

  printf '链路 codec=%s，采样率 %s kHz（%s 秒）' "$(ad_codec)" "$((got / 1000))" "$elapsed"
  if [ -n "$want" ] && [ "$got" != "$want" ]; then
    printf '：期望 %s，未生效\n' "$want"
    return 1
  fi
  case "$got" in
    44100) printf '（44.1 kHz：HQ 与 LL 均可用）\n' ;;
    96000) printf '（96 kHz：仅 HQ，约 8 ms / 616-646 kbps）\n' ;;
    *) printf '\n' ;;
  esac
}

normalise_mode() {
  case "${1,,}" in
    hq | high | high-quality) printf 'hq' ;;
    ll | low-latency | lowlatency | low_latency) printf 'll' ;;
    *) return 1 ;;
  esac
}

quality_of_mode() {
  case "$1" in
    hq) printf '%s' "$QUALITY_HQ" ;;
    ll) printf '%s' "$QUALITY_LL" ;;
    *) return 1 ;;
  esac
}

# Print "id<TAB>node-name<TAB>codec<TAB>description" for every aptX Adaptive
# A2DP sink that bluez5 currently exposes (usually one).
ad_sinks() {
  pw-dump 2>/dev/null | python3 -c '
import json, sys
try:
    objects = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for obj in objects:
    props = (obj.get("info") or {}).get("props") or {}
    codec = str(props.get("api.bluez5.codec") or "")
    factory = str(props.get("factory.name") or "")
    if not codec.startswith("aptx_adaptive"):
        continue
    if "a2dp" not in factory and props.get("media.class") != "Audio/Sink":
        continue
    print("%s\t%s\t%s\t%s" % (obj.get("id"), props.get("node.name") or "?",
                              codec, props.get("node.description") or ""))
'
}

# Node id of the link to act on: the default sink when it is an aptX Adaptive
# A2DP sink, otherwise the first such sink.
ad_sink_id() {
  local default_id sinks
  default_id=$(wpctl status 2>/dev/null | sed -n '/Sinks:/,/Sources:/p' \
    | grep -E '[*][[:space:]]*[0-9]+\.' | grep -oE '[0-9]+' | head -1 || true)
  sinks=$(ad_sinks || true)
  [ -n "$sinks" ] || return 1
  if [ -n "$default_id" ] && printf '%s\n' "$sinks" | cut -f1 | grep -qx "$default_id"; then
    printf '%s' "$default_id"
    return 0
  fi
  printf '%s' "$(printf '%s\n' "$sinks" | head -1 | cut -f1)"
}

# Read the codec's SPA_PROP_QUALITY (the mode) back from the running node.
current_mode() {
  local id
  id=$(ad_sink_id) || return 1
  pw-cli enum-params "$id" Props 2>/dev/null | python3 -c '
import re, sys
pending = False
for line in sys.stdin:
    if re.search(r"Props:quality \(269\)", line):
        pending = True
        continue
    if not pending:
        continue
    m = re.match(r"\s*Int (-?\d+)", line)
    if m:
        print(int(m.group(1)))
        break
    if line.strip():
        pending = False
sys.exit(0)
'
}

# Sample rate the negotiated codec configuration runs at.  The bluez5 A2DP node
# reports it in its EnumFormat, so it is readable without playing anything.
link_rate() {
  local id
  id=$(ad_sink_id) || return 1
  pw-dump 2>/dev/null | python3 -c '
import json, sys
want = sys.argv[1]
for obj in json.load(sys.stdin):
    if str(obj.get("id")) != want:
        continue
    params = (obj.get("info") or {}).get("params") or {}
    for key in ("EnumFormat", "Format"):
        for entry in params.get(key, []):
            if isinstance(entry, dict) and entry.get("rate"):
                print(entry["rate"])
                raise SystemExit
' "$id"
}

# Boot default, i.e. what a fresh connection uses.
boot_default_mode() {
  local pid mode
  pid=$(pgrep -x pipewire | head -1 || true)
  if [ -n "${pid:-}" ] && [ -r "/proc/$pid/environ" ]; then
    mode=$(tr '\0' '\n' <"/proc/$pid/environ" \
      | sed -n 's/^APTX_ADAPTIVE_DEFAULT_MODE=//p' | head -1)
  fi
  if [ -n "${mode:-}" ]; then
    normalise_mode "$mode" 2>/dev/null || printf '%s' "$mode"
  else
    printf 'hq (plugin default)'
  fi
}

# "directory<TAB>slot" of the plugin pipewire actually loaded.
active_plugin() {
  local pid dir slot
  pid=$(pgrep -x pipewire | head -1 || true)
  [ -n "${pid:-}" ] || return 1
  [ -r "/proc/$pid/environ" ] || return 1
  dir=$(tr '\0' '\n' <"/proc/$pid/environ" | sed -n 's/^SPA_PLUGIN_DIR=//p' | head -1)
  slot=$(tr '\0' '\n' <"/proc/$pid/environ" | sed -n 's/^APTX_ADAPTIVE_SLOT=//p' | head -1)
  [ -n "${dir:-}" ] || return 1
  printf '%s\t%s' "$(printf '%s' "$dir" | cut -d: -f1)" "${slot:-aptx}"
}

# "hci0 UP" / "hci0 DOWN" / "no adapter".
adapter_state() {
  local state
  state=$(hciconfig -a 2>/dev/null | awk '
    /^hci[0-9]+:/ { dev = $1; sub(/:$/, "", dev); next }
    dev != "" && /^[[:space:]]*(UP|DOWN)/ {
        printf "%s %s", dev, ($0 ~ /UP/ ? "UP" : "DOWN")
        exit
    }' || true)
  if [ -z "$state" ]; then
    state=$(bluetoothctl show 2>/dev/null | awk '
        /Controller/ { dev = $2 }
        /Powered:/ { printf "%s %s", (dev == "" ? "adapter" : dev),
                            ($2 == "yes" ? "UP" : "DOWN"); exit }' || true)
  fi
  printf '%s' "${state:-unknown}"
}

cmd_status() {
  local sinks id line name codec desc mode boot plugin rate

  remember_address
  printf '%s\n' "$(bold 'aptX Adaptive')  $(dim '— Sennheiser MOMENTUM 5')"
  printf '  %s%s\n' "$L_ADAPTER" "$(adapter_state)"

  sinks=$(ad_sinks || true)
  if [ -z "$sinks" ]; then
    printf '  %s%s\n' "$L_HEADSET" "$(dim '未连接（没有 aptX Adaptive 输出节点）')"
  else
    id=$(ad_sink_id || true)
    line=$(printf '%s\n' "$sinks" | awk -F'\t' -v id="$id" '$1 == id { print; exit }')
    name=$(printf '%s' "$line" | cut -f2)
    codec=$(printf '%s' "$line" | cut -f3)
    desc=$(printf '%s' "$line" | cut -f4)
    printf '  %s%s\n' "$L_HEADSET" "${desc:-$name}"
    printf '  %s%s\n' "$L_CODEC" "$codec  $(dim "node $id · $name")"
    rate=$(link_rate 2>/dev/null || true)
    if [ -n "${rate:-}" ]; then
      printf '  %s%s\n' "$L_RATE" "$(printf '%s kHz' "$((rate / 1000))")  $(dim 'LL 仅 ≤48 kHz')"
    fi
    case "$(rate_conf_mode)" in
      auto) printf '  %s%s\n' "$L_POLICY" "$(bold 'auto')  $(dim '跟随音源采样率（HQ 策略）')" ;;
      pin) printf '  %s%s\n' "$L_POLICY" "$(dim "固定 $(grep -oE 'bluez5.default.rate\" = [0-9]+' "$RATE_CONF" 2>/dev/null | grep -oE '[0-9]+$') Hz")" ;;
      *) printf '  %s%s\n' "$L_POLICY" "$(dim '系统默认（48000 Hz）')" ;;
    esac
  fi

  mode=$(current_mode 2>/dev/null || true)
  boot=$(boot_default_mode)

  case "${mode:-}" in
    0) printf '  %s%s\n' "$L_MODE" "$(bold 'HQ')  $(dim '427 kbps / 12 ms（ABR 自动升降档）')" ;;
    1) printf '  %s%s\n' "$L_MODE" "$(bold 'Low latency')  $(dim '270 kbps / 10 ms')" ;;
    *) printf '  %s%s\n' "$L_MODE" "$(dim '未知（耳机未连接或无法读回）')" ;;
  esac

  printf '  %s%s\n' "$L_BOOT" "$boot  $(dim 'APTX_ADAPTIVE_DEFAULT_MODE')"

  if plugin=$(active_plugin); then
    printf '  %s%s\n' "$L_PLUGIN" \
      "$(printf '%s' "$plugin" | cut -f1)  $(dim "槽位 $(printf '%s' "$plugin" | cut -f2)")"
  fi

  [ -n "$sinks" ] || return 1
}

cmd_switch() {
  local mode quality id result
  [ $# -eq 1 ] || die 'switch 需要一个参数：hq 或 ll'
  acquire_lock wait || die '另一个 ad-ctl 操作仍在进行，请稍后再试'
  ensure_ad_link || return 1
  mode=$(normalise_mode "$1") || die "未知模式 '$1'（应为 hq 或 ll）"
  quality=$(quality_of_mode "$mode")

  id=$(ad_sink_id 2>/dev/null || true)
  if [ -z "${id:-}" ]; then
    printf 'ad-ctl: 耳机未连接；已记录 %s，下次连接由 APTX_ADAPTIVE_DEFAULT_MODE 决定\n' \
      "$mode" >&2
    return 0
  fi

  # The mode carries the rate policy: low latency can only run up to 48 kHz, so
  # it pins the link there, while HQ follows the source through the watcher.
  # Changing the rate re-establishes the transport, which resets the codec to
  # APTX_ADAPTIVE_DEFAULT_MODE, so it has to happen before the mode is set.
  case "$mode" in
    ll) apply_rate 48000 pin >/dev/null 2>&1 || true ;;
    hq)
      # Nothing playing yet: start from 48 kHz and let the watcher retarget.
      local idle_rate
      idle_rate=$(target_rate)
      [ -n "$idle_rate" ] || idle_rate=48000
      apply_rate "$idle_rate" auto >/dev/null 2>&1 || true
      ;;
  esac
  # The transport is rebuilt as part of the rate change, so give the node a
  # moment to reappear instead of failing on a transient empty read.
  for _ in 1 5; do
    id=$(ad_sink_id 2>/dev/null || true)
    [ -n "${id:-}" ] && break
    sleep 2
  done
  [ -n "${id:-}" ] || die '重设采样率后找不到耳机节点'

  pw-cli set-param "$id" Props "{ quality = $quality }" >/dev/null 2>&1 || true
  sleep 0.4
  result=$(current_mode 2>/dev/null || true)
  case "$mode:$result" in
    hq:0) printf '已切换到 %s（427 kbps / 12 ms）\n' "$(bold HQ)" ;;
    ll:1) printf '已切换到 %s（270 kbps / 10 ms）\n' "$(bold 'Low latency')" ;;
    *) die "切换失败（node $id 报告 quality=${result:-未知}）" ;;
  esac
}

# Keep the link at the rate the playing stream wants, while the rate policy is
# "auto" and the mode is HQ.  Runs as a user service (see the home-manager
# module); each change re-establishes the A2DP transport, so it waits for a
# stable target and then holds off before acting again.
cmd_watch() {
  local mode target current last='' stable=0 cooldown=0
  while :; do
    sleep 3
    if [ "$cooldown" -gt 0 ]; then
      cooldown=$((cooldown - 3))
      continue
    fi
    if [ "$(rate_conf_mode)" != auto ]; then
      continue
    fi
    # Never rebuild the transport while a manual command is doing the same.
    acquire_lock try || continue
    if ! ensure_ad_link >/dev/null 2>&1; then
      release_lock
      continue
    fi
    mode=$(current_mode 2>/dev/null || printf '')
    if [ "$mode" != 0 ]; then
      release_lock
      continue
    fi
    target=$(target_rate)
    if [ -z "$target" ]; then
      last=''
      stable=0
      release_lock
      continue
    fi
    current=$(link_rate 2>/dev/null || true)
    if [ "$target" = "${current:-}" ]; then
      last=''
      stable=0
      release_lock
      continue
    fi
    if [ "$target" = "$last" ]; then
      stable=$((stable + 1))
    else
      last=$target
      stable=1
    fi
    if [ "$stable" -ge 2 ]; then
      if apply_rate "$target" auto >/dev/null 2>&1; then
        cooldown=21
      fi
      last=''
      stable=0
    fi
    release_lock
  done
}

# Heavier recovery, only when explicitly asked for: profile cycle, then a
# monitor restart, then reconnecting the headset.
cmd_recover() {
  acquire_lock wait || die '另一个 ad-ctl 操作仍在进行，请稍后再试'
  remember_address
  if wait_for_ad 3; then
    printf '链路已是 aptX Adaptive（%s）\n' "$(ad_codec)"
    return 0
  fi

  cycle_a2dp_profile || true
  if wait_for_ad 15; then
    printf '已用 profile 循环恢复（%s）\n' "$(ad_codec)"
    return 0
  fi

  printf 'ad-ctl: 重启 WirePlumber 以恢复（可能短暂断开）\n' >&2
  systemctl --user restart wireplumber
  sleep 5
  cycle_a2dp_profile || true
  if wait_for_ad 15; then
    printf '已用重启恢复（%s）\n' "$(ad_codec)"
    return 0
  fi

  local address
  address=$(headset_address)
  if [ -n "$address" ]; then
    printf 'ad-ctl: 最后手段：重连耳机 %s\n' "$address" >&2
    bluetoothctl disconnect "$address" >/dev/null 2>&1
    sleep 3
    bluetoothctl connect "$address" >/dev/null 2>&1
    if wait_for_ad 15; then
      printf '已用蓝牙重连恢复（%s）\n' "$(ad_codec)"
      return 0
    fi
  fi

  printf 'ad-ctl: 恢复失败（bluez 现状：%s）\n' "$(bluez_state)" >&2
  return 1
}

cmd_toggle() {
  case "$(current_mode 2>/dev/null || true)" in
    0) cmd_switch ll ;;
    1) cmd_switch hq ;;
    *) die "无法读回当前模式（耳机未连接？）；请用 'ad-ctl switch hq|ll'" ;;
  esac
}

case "${1:-}" in
  status | st) cmd_status ;;
  toggle | t) cmd_toggle ;;
  switch | sw) shift; cmd_switch "$@" ;;
  rate | r) shift; cmd_rate "$@" ;;
  watch) cmd_watch ;;
  recover) cmd_recover ;;
  -h | --help | help | '') usage ;;
  *) usage >&2; exit 2 ;;
esac
