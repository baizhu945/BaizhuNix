NOCTALIA_COLORS="${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/wallpaper-colors.json"
WATCH_DIR="$(dirname "$NOCTALIA_COLORS")"
WATCH_FILE="$(basename "$NOCTALIA_COLORS")"

apply_theme() {
  echo "[theme-sync] 检测到壁纸颜色更新..."
  sleep 0.1

  python3 @noctaliaColorSync@ "$NOCTALIA_COLORS" \
    || { echo "[theme-sync] ✗ Waybar 颜色同步失败" >&2; return 1; }

  local primary_hex
  primary_hex=$(jq -r '.mPrimary' "$NOCTALIA_COLORS" | sed 's/^#//')
  if [ -n "$primary_hex" ] && [ "$primary_hex" != "null" ]; then
    mouse-trail-ctl color "$primary_hex" 2>/dev/null || true
    echo "[theme-sync] 已同步光标拖尾颜色 → $primary_hex"
  fi

  echo "[theme-sync] ✓ 完成"
}

mkdir -p "$WATCH_DIR"
echo "[theme-sync] 服务启动，监视 $NOCTALIA_COLORS"

[ -f "$NOCTALIA_COLORS" ] && apply_theme || true

inotifywait -m \
  -e close_write \
  -e moved_to \
  --format '%f' \
  "$WATCH_DIR" |
while IFS= read -r filename; do
  if [[ "$filename" == "$WATCH_FILE" ]]; then
    apply_theme || echo "[theme-sync] 本次同步失败，继续监视..." >&2
  fi
done
