# cc-connect cron 命令参考

cc-connect 定时任务：把聊天里的自然语言需求转成按 cron 表达式周期运行的 agent 提示词任务或 shell 命令任务。依赖本机 cc-connect 守护进程（`systemctl --user status cc-connect`，socket `~/.cc-connect/run/api.sock`）。

## 子命令总览

| 子命令 | 用途 |
|--------|------|
| `cron list` | 列出所有任务 |
| `cron add` | 创建任务（`--prompt` 或 `--exec` 二选一） |
| `cron info <id> [字段]` | 查看任务详情，可只取单项字段 |
| `cron edit <id> <字段> <值>` | 修改任务字段 |
| `cron exec <id>` | 立即触发一次 |
| `cron del <id>` | 删除任务 |

## cron add 参数

| 参数 | 说明 |
|------|------|
| `--cron "<expr>"` | 必填。5 段 cron 表达式（分 时 日 月 周），如 `"*/30 * * * *"` |
| `--prompt "<任务>"` | Agent 提示词任务：任务运行 agent 并执行该提示词 |
| `--exec "<命令>"` | Shell 命令任务：直接执行命令（与 `--prompt` 互斥） |
| `--desc "<描述>"` | 任务描述，便于列表辨认 |
| `--session-mode new-per-run` | 每次运行开新会话（推荐周期任务，避免污染当前会话）；默认 `reuse` |
| `--timeout-mins N` | 单次运行最长等待分钟数（0 = 不限，默认 30） |
| `--silent` | 不发送"任务开始"通知 |
| `-p <project>` / `-s <session>` | 指定项目/会话；未指定时读 `CC_PROJECT` / `CC_SESSION_KEY` 环境变量 |

## 示例

```bash
# Agent 提示词任务：每 30 分钟执行，新会话
cc-connect cron add --cron "*/30 * * * *" --prompt "检查磁盘空间并汇报" --desc "每30分钟磁盘检查" --session-mode new-per-run

# Shell 命令任务：每天早上 8 点
cc-connect cron add --cron "0 8 * * *" --exec "df -h" --desc "每日8点磁盘检查"

# 管理
cc-connect cron list
cc-connect cron info <job-id>
cc-connect cron info <job-id> cron_expr        # 只看单项字段
cc-connect cron edit <job-id> cron_expr "0 8,20 * * *"
cc-connect cron edit <job-id> enabled true
cc-connect cron edit <job-id> mute true
cc-connect cron edit <job-id> silent true
cc-connect cron edit <job-id> timeout_mins 60
cc-connect cron edit <job-id> session_mode new-per-run
cc-connect cron edit <job-id> work_dir /path/to/dir
cc-connect cron exec <job-id>                  # 立即触发一次
cc-connect cron del <job-id>
```

## 频率 → cron 表达式对照

| 用户说法 | cron 表达式 |
|---------|------------|
| 每30分钟 | `*/30 * * * *` |
| 每5分钟 | `*/5 * * * *` |
| 每小时 | `0 * * * *` |
| 每天 6 点 | `0 6 * * *` |
| 每天 8 点和 20 点 | `0 8,20 * * *` |
| 每周一 9 点 | `0 9 * * 1` |
| 每月 1 日 6 点 | `0 6 1 * *` |

其他频率按 cron 语法（分 时 日 月 周）转换；不确定时把拟用表达式连同任务发给用户确认。

## 聊天斜杠命令（供用户直接使用）

```
/cron                    # 任务列表
/cron add <min> <hour> <day> <mon> <wk> <prompt>   # 创建（空格分隔，非标准 5 段写法）
/cron del <id>
/cron enable <id>
/cron disable <id>
```

## 配置与排错

- **首次使用**：若 agent 依赖记忆文件，先让用户在聊天中执行 `/cron setup` 或 `/bind setup`，刷新记忆文件中的定时任务指令。
- **时区**：按本机时区（Asia/Shanghai）执行。
- **socket 缺失/连接失败**：`systemctl --user status cc-connect`；socket 路径 `~/.cc-connect/run/api.sock`。
- **会话轮换**：项目配置 `reset_on_idle_mins`（默认 30）控制空闲后是否开新会话；设 0 关闭。
- 任务结果涉及文件/图片时，用 `cc-connect send --image/--file` 发回聊天（见 `cc-connect-send` skill）。
