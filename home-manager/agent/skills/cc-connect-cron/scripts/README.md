# Scripts

## cc-cron.sh

cc-connect cron 子命令的辅助封装：先校验 cc-connect 守护进程（socket `~/.cc-connect/run/api.sock`），再执行 cron 操作，参数错误时打印用法。

```bash
bash ~/.config/opencode/skills/cc-connect-cron/scripts/cc-cron.sh list
# 默认不传 --session-mode，继承全局 [cron].session_mode（默认 reuse）
bash ~/.config/opencode/skills/cc-connect-cron/scripts/cc-cron.sh add "*/30 * * * *" --prompt "检查磁盘空间并汇报" --desc "每30分钟磁盘检查"
bash ~/.config/opencode/skills/cc-connect-cron/scripts/cc-cron.sh add "0 6 * * *" --exec "df -h" --desc "每日6点磁盘检查"
bash ~/.config/opencode/skills/cc-connect-cron/scripts/cc-cron.sh info <job-id>
bash ~/.config/opencode/skills/cc-connect-cron/scripts/cc-cron.sh edit <job-id> cron_expr "0 8 * * *"
bash ~/.config/opencode/skills/cc-connect-cron/scripts/cc-cron.sh exec <job-id>
bash ~/.config/opencode/skills/cc-connect-cron/scripts/cc-cron.sh del <job-id>
```

### What it does
1. 检查 `cc-connect` 是否在 PATH、守护进程 socket 是否存在（不存在时提示 `systemctl --user status cc-connect`）
2. `list` 列出所有任务
3. `add` 创建任务：`--cron <表达式>` 必填，其余参数透传（`--prompt` 与 `--exec` 二选一，可加 `--desc`/`--session-mode`/`--timeout-mins`/`--silent`）。默认不传 `--session-mode`；只有用户明确要求每次隔离时才传 `--session-mode new-per-run`
4. `info` / `edit` / `exec` / `del` 管理任务；已有任务需要复用时可执行 `edit <job-id> session_mode reuse`

### 等价直接命令

脚本只是封装，所有操作也可直接执行 `cc-connect cron ...`（见 `references/commands.md`）。
