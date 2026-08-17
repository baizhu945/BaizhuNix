---
name: cc-connect-cron
description: Create and manage cc-connect scheduled tasks (cron jobs) from chat messages. Use when the user sends a recurring or scheduled request through Feishu, Telegram, or other chat platforms bridged by cc-connect, e.g. "每30分钟帮我...", "每小时...", "每天X点...", "每周一...", or asks to create/list/view/edit/trigger/delete a scheduled task. 
---

# cc-connect 定时任务（cron）

## Overview

把聊天消息中的自然语言定时需求转换为 cc-connect 定时任务：执行 `cc-connect cron` 命令创建，最后汇报任务信息。

## 辅助脚本与参考

- `scripts/cc-cron.sh`：cron 子命令封装（自动校验守护进程、参数透传），用法见 `scripts/README.md`
- `references/commands.md`：全部 cron 命令参数、频率→cron 对照表、聊天斜杠命令与排错

## 工作流程

### 1. 解析需求，先确认再创建

1. 从消息中解析出**执行频率**（如"每30分钟"）和**任务内容**（如"帮我检查磁盘空间"）。
2. 将频率转换为 5 段 cron 表达式（分 时 日 月 周），参考下方对照表。

### 2. 创建定时任务

Agent 提示词任务：

```bash
cc-connect cron add --cron "*/30 * * * *" --prompt "检查磁盘空间并汇报" --desc "每30分钟磁盘检查"
```

Shell 命令任务（与 `--prompt` 互斥）：

```bash
cc-connect cron add --cron "*/30 * * * *" --exec "df -h" --desc "磁盘使用率检查"
```

常用参数：

- 默认**不要传** `--session-mode`：任务继承 `[cron].session_mode`；cc-connect 默认值为 `reuse`
- `--session-mode new-per-run`：每次运行开新会话；只有用户明确要求每次隔离时才使用，绝不能因为任务是周期性的就自动添加
- `--timeout-mins N`：单次运行最长等待分钟数（0 = 不限，默认 30）
- `--silent`：不发送"任务开始"通知
- `-p <project>` / `-s <session>`：指定项目/会话；未指定时自动读取 `CC_PROJECT` / `CC_SESSION_KEY` 环境变量

**会话模式优先级：**任务自身非空的 `session_mode` 高于 `[cron].session_mode`。修改全局配置不会覆盖已经保存为 `new_per_run` 的任务。需要复用时执行：

```bash
cc-connect cron edit <job-id> session_mode reuse
```

### 3. 验证并汇报

创建成功后运行 `cc-connect cron list`，并用 `cc-connect cron info <job-id>` 检查完整任务配置。若全局配置为 `reuse`，任务详情中 `session_mode` 为空/缺省表示继承全局复用；若显示 `new_per_run`，必须在用户未明确要求隔离时改为 `reuse`。最后向用户回复任务 ID、执行频率、任务内容和会话模式。

### 4. 定时任务管理

用户要求查看、修改、立即执行或删除任务时：

```bash
cc-connect cron list                         # 列出所有任务
cc-connect cron info <job-id>                # 查看任务详情（可加字段名只看单项）
cc-connect cron edit <job-id> <field> <value>  # 修改字段：cron_expr / prompt / exec / description / enabled / mute / silent / timeout_mins / session_mode / work_dir 等
cc-connect cron exec <job-id>                # 立即触发一次
cc-connect cron del <job-id>                 # 删除任务
```

聊天斜杠命令也可直接建议用户使用：`/cron`（列表）、`/cron add <min> <hour> <day> <mon> <wk> <prompt>`、`/cron del <id>`、`/cron enable <id>`、`/cron disable <id>`。

## 频率 → cron 表达式对照

| 用户说法 | cron 表达式 |
|---------|------------|
| 每30分钟 | `*/30 * * * *` |
| 每5分钟 | `*/5 * * * *` |
| 每小时 | `0 * * * *` |
| 每天 6 点 | `0 6 * * *` |
| 每天早上 8 点和晚上 8 点 | `0 8,20 * * *` |
| 每周一 9 点 | `0 9 * * 1` |
| 每月 1 日 6 点 | `0 6 1 * *` |

其他频率按 cron 语法（分 时 日 月 周）转换；转换结果不确定时，把拟用的表达式连同任务一起发给用户确认。

## Avoiding Cron Collisions Between Jobs

**Problem:** When two or more scheduled jobs share trigger minutes, they fire simultaneously and interfere with each other — shared temp files get overwritten, and one job's run can be clobbered or fail because of the other.

Real example: a Chrome download monitor on `*/30 * * * *` (fires at :00 and :30) plus a screenshot task on `*/15 * * * *` (fires at :00, :15, :30, :45) both fired at :00 and :30, causing one task to overwrite the other.

**Solution — stagger the trigger minutes:**

1. Always run `cc-connect cron list` first and note the existing jobs' trigger minutes before creating a new one.
2. Offset a new job's minutes so they never coincide with an existing job. For "every 15 minutes starting at :20", use an explicit minute list:
   `5,20,35,50 * * * *` → fires at :05, :20, :35, :50 (never collides with :00/:30).
3. De-collide an existing job by editing its schedule:
   `cc-connect cron edit <job-id> cron_expr "5,20,35,50 * * * *"`

**Cron syntax gotcha:** `20-59/15 * * * *` only matches minutes 20–59 of each hour, so between :50 of hour N and :20 of hour N+1 there is a 30-minute gap (the :05 run is skipped) — the interval is no longer every 15 minutes. To keep a true "every 15 minutes starting at :20" schedule across hour boundaries, always use an explicit minute list (`5,20,35,50 * * * *`), never a range step.

## 注意事项

- `cc-connect cron` 依赖本机正在运行的 cc-connect 守护进程（Unix socket：`~/.cc-connect/run/api.sock`）。命令报连接失败时，提示用户检查 systemd 用户服务：`systemctl --user status cc-connect`。
- 首次使用：若当前 agent 依赖记忆文件（opencode / codex / reasonix），先让用户在聊天中执行一次 `/cron setup` 或 `/bind setup`，agent 才能正确执行定时任务流程。
- 定时任务按本机时区（Asia/Shanghai）执行。
- 不要臆造用户没说的频率或内容；信息不完整时先提问确认。
- 回复使用正常文本；如任务结果涉及文件/图片，用 `cc-connect send --file/--image` 发送。
