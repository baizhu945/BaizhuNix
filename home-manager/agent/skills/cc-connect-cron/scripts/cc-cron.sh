#!/bin/bash
# cc-connect cron 辅助脚本 —— 校验守护进程后封装 cron 子命令
# 依赖: cc-connect 守护进程 (socket: ~/.cc-connect/run/api.sock)
# 用法:
#   cc-cron.sh list
#   cc-cron.sh add <cron表达式> --prompt "任务内容" [--desc "描述"] [--session-mode reuse|new-per-run] [--timeout-mins N] [--silent]
#   cc-cron.sh add <cron表达式> --exec "shell 命令" [--desc "描述"]
#   cc-cron.sh info <job-id> [字段名]
#   cc-cron.sh edit <job-id> <字段> <值>
#   cc-cron.sh exec <job-id>
#   cc-cron.sh del <job-id>
set -euo pipefail

SOCK="$HOME/.cc-connect/run/api.sock"

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
用法: cc-cron.sh <子命令> [参数]
  list                                   列出所有定时任务
  add <cron表达式> --prompt "任务内容" [选项]   创建 agent 提示词任务
  add <cron表达式> --exec "命令" [选项]        创建 shell 命令任务
  info <job-id> [字段名]                 查看任务详情(可只看单项)
  edit <job-id> <字段> <值>              修改任务字段
  exec <job-id>                          立即触发一次
  del <job-id>                           删除任务
add 选项: --desc, --session-mode reuse|new-per-run, --timeout-mins N, --silent, -p <project>, -s <session>
默认不传 --session-mode，继承全局 [cron].session_mode；仅在明确要求隔离时使用 new-per-run。
EOF
  exit 1
}

[ $# -ge 1 ] || usage
check_daemon

case "$1" in
  list)
    cc-connect cron list
    ;;
  add)
    [ $# -ge 3 ] || usage
    # $2 = cron 表达式, 其余参数透传 (--prompt/--exec/--desc/...)
    cc-connect cron add --cron "$2" "${@:3}"
    ;;
  info)
    [ $# -ge 2 ] || usage
    cc-connect cron info "${@:2}"
    ;;
  edit)
    [ $# -ge 4 ] || usage
    cc-connect cron edit "$2" "$3" "$4"
    ;;
  exec)
    [ $# -ge 2 ] || usage
    cc-connect cron exec "$2"
    ;;
  del)
    [ $# -ge 2 ] || usage
    cc-connect cron del "$2"
    ;;
  *)
    usage
    ;;
esac
