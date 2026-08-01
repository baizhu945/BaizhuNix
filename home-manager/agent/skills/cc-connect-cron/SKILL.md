---
name: cc-connect-cron
description: Create and manage cc-connect scheduled tasks (cron jobs) from chat messages. Use when the user sends a recurring or scheduled request through Feishu, Telegram, or other chat platforms bridged by cc-connect, e.g. "每30分钟帮我...", "每小时...", "每天X点...", "每周一...", or asks to create/list/view/edit/trigger/delete a scheduled task. Always confirm with the user before creating a cron job.
---

# cc-connect 定时任务（cron）

## Overview

把聊天消息中的自然语言定时需求转换为 cc-connect 定时任务：先向用户确认，得到同意后再执行 `cc-connect cron` 命令创建，最后汇报任务信息。

## 工作流程

### 1. 解析需求，先确认再创建

1. 从消息中解析出**执行频率**（如"每30分钟"）和**任务内容**（如"帮我检查磁盘空间"）。
2. 将频率转换为 5 段 cron 表达式（分 时 日 月 周），参考下方对照表。
3. **必须**先向用户复述拟创建的任务并征求同意，例如：

   > 我准备创建定时任务：每 30 分钟执行「检查磁盘空间并汇报」。是否确认创建？

4. 只有得到用户明确同意（如"可以""确认""好的"）后才执行创建命令；用户拒绝或要求修改时，不得创建。

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

- `--session-mode new-per-run`：每次运行开新会话，推荐用于周期性 agent 任务，避免污染当前会话；默认 `reuse`
- `--timeout-mins N`：单次运行最长等待分钟数（0 = 不限，默认 30）
- `--silent`：不发送"任务开始"通知
- `-p <project>` / `-s <session>`：指定项目/会话；未指定时自动读取 `CC_PROJECT` / `CC_SESSION_KEY` 环境变量

### 3. 验证并汇报

创建成功后运行 `cc-connect cron list`（或 `cc-connect cron info <job-id>`）确认任务已生效，然后向用户回复任务 ID、执行频率和任务内容。

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

## 注意事项

- `cc-connect cron` 依赖本机正在运行的 cc-connect 守护进程（Unix socket：`~/.cc-connect/run/api.sock`）。命令报连接失败时，提示用户检查 systemd 用户服务：`systemctl --user status cc-connect`。
- 首次使用：若当前 agent 依赖记忆文件（opencode / codex / reasonix），先让用户在聊天中执行一次 `/cron setup` 或 `/bind setup`，agent 才能正确执行定时任务流程。
- 定时任务按本机时区（Asia/Shanghai）执行。
- 不要臆造用户没说的频率或内容；信息不完整时先提问确认。
- 回复使用正常文本；如任务结果涉及文件/图片，用 `cc-connect send --file/--image` 发送。
