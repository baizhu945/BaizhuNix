#!/bin/bash
# 截图并发送到当前聊天 (Wayland / Niri)
# 用法:
#   send-screenshot.sh           # 区域选择截图 (grim + slurp)
#   send-screenshot.sh --full    # 全屏截图
# 发送前校验: 文件非空, 不超过附件上限 (默认 50MiB, 可设 CC_MAX_ATTACHMENT_SIZE_MB)
set -euo pipefail

OUT="/tmp/cc-connect-shot-$(date +%s).png"

if [ "${1:-}" = "--full" ]; then
  grim "$OUT"
else
  grim -g "$(slurp)" "$OUT"
fi

if [ ! -s "$OUT" ]; then
  echo "截图失败或已取消" >&2
  exit 1
fi

# 通过 cc-send.sh 复用校验逻辑; 失败时清理临时文件
if bash "$(dirname "$0")/cc-send.sh" --image "$OUT"; then
  echo "已发送: $OUT"
else
  command rm -f "$OUT"
  exit 1
fi
