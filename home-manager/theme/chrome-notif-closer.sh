declare -A seen_windows

while true; do
  # 若 niri socket 尚未就绪则等待重试
  if ! windows_json=$(niri msg --json windows 2>/dev/null); then
    sleep 1
    continue
  fi

  current_ms=$(date +%s%3N)

  # 找出 app_id 和 title 均为空的窗口（Chrome 通知窗口特征）
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    # 仅在首次发现时记录时间戳，避免重复刷新
    if [[ -z "${seen_windows[$id]+x}" ]]; then
      seen_windows[$id]=$current_ms
    fi
  done < <(printf '%s' "$windows_json" \
    | jq -r '.[] | select(.app_id == "" and .title == "") | .id')

  # 遍历已跟踪的窗口，决定关闭还是清理
  for id in "${!seen_windows[@]}"; do
    # 检查窗口是否仍然存在（可能已被用户手动关闭）
    still_exists=$(printf '%s' "$windows_json" \
      | jq -r ".[] | select(.id == $id) | .id // empty")

    if [[ -z "$still_exists" ]]; then
      # 窗口已消失，从跟踪表中移除
      unset "seen_windows[$id]"
      continue
    fi

    elapsed=$(( current_ms - seen_windows[$id] ))

    if (( elapsed >= 2000 )); then
      # 超过 2 秒，关闭该窗口；|| true 防止偶发失败中断脚本
      niri msg action close-window --id "$id" || true
      unset "seen_windows[$id]"
    fi
  done

  sleep 0.5
done
