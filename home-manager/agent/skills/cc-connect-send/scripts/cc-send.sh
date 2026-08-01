#!/bin/bash
# cc-connect send 辅助脚本 —— 校验守护进程与附件后发送到当前聊天
# 依赖: cc-connect 守护进程 (socket: ~/.cc-connect/run/api.sock)
# 用法:
#   cc-send.sh --image /abs/path/image.png
#   cc-send.sh --file /abs/path/report.pdf [--file /abs/path/other.zip]
#   cc-send.sh --tts "text to speak"
#   cc-send.sh --file a.pdf --image b.png     # 多附件可组合
set -euo pipefail

SOCK="$HOME/.cc-connect/run/api.sock"
MAX_MB="${CC_MAX_ATTACHMENT_SIZE_MB:-50}"

check_daemon() {
  if ! command -v cc-connect >/dev/null 2>&1; then
    echo "错误: cc-connect 不在 PATH" >&2
    exit 1
  fi
  if [ ! -S "$SOCK" ]; then
    echo "错误: cc-connect 守护进程 socket 不存在: $SOCK" >&2
    echo "请检查: systemctl --user status cc-connect" >&2
    exit 1
  fi
}

usage() {
  cat >&2 <<'EOF'
用法: cc-send.sh <--image <路径> | --file <路径> | --tts <文本>> [可组合/重复]
  --image <路径>   发送图片/截图
  --file <路径>    发送文件 (PDF、压缩包等)
  --tts <文本>     发送语音回复
EOF
  exit 1
}

[ $# -ge 1 ] || usage
check_daemon

# 保留原始参数, 校验后再原样发送
orig_args=("$@")
while [ $# -gt 0 ]; do
  case "$1" in
    --image|--file)
      f="${2:-}"
      [ -n "$f" ] || { echo "错误: $1 缺少路径参数" >&2; usage; }
      [ -f "$f" ] || { echo "错误: 文件不存在: $f" >&2; exit 1; }
      mb=$(du -m "$f" | cut -f1)
      if [ "$mb" -gt "$MAX_MB" ]; then
        echo "错误: $f 超过 ${MAX_MB}MiB (实际 ${mb}MiB)，请压缩后发送 (zip / convert -quality 等)" >&2
        exit 1
      fi
      shift 2
      ;;
    --tts)
      [ -n "${2:-}" ] || { echo "错误: --tts 缺少文本" >&2; usage; }
      shift 2
      ;;
    *)
      echo "错误: 未知参数: $1" >&2
      usage
      ;;
  esac
done

cc-connect send "${orig_args[@]}"
