---
name: cc-connect-send
description: Send images, files, and TTS voice messages back to the chat via cc-connect. Use when the user asks you (through Feishu, Telegram, or other cc-connect-bridged chat platforms) to send a screenshot, image, chart, document, PDF, archive, or any generated media file, or requests a voice reply. Bridges local agent output (screenshots taken with grim, generated charts/PDFs, etc.) to the IM conversation.
---

# cc-connect 媒体发送（send）

## Overview

用户通过飞书/Telegram 等 IM 聊天要求 AI「把截图/图片/文件发给我」或要求语音回复时，用 `cc-connect send` 将本地生成的附件发回当前聊天。此命令只用于发送生成的附件，普通文本回复直接回复即可。

## 辅助脚本与参考

- `scripts/cc-send.sh`：发送封装（校验守护进程、文件存在、大小上限后透传发送）
- `scripts/send-screenshot.sh`：`grim` + `slurp` 截图并直接发送（`--full` 全屏）
- `references/commands.md`：send 全部参数、config 配置项与排错

## 前提

- cc-connect 守护进程在运行：`systemctl --user status cc-connect`（Unix socket：`~/.cc-connect/run/api.sock`；连接失败时先检查该服务）。
- 首次使用（或升级后）：若 agent 侧未注入发送指令，让用户在聊天中执行一次 `/bind setup` 或 `/cron setup` 刷新记忆文件。
- 发送开关：`config.toml` 的 `attachment_send` 默认 `"on"`；若发送无响应，检查该配置与守护进程日志。

## 命令

```bash
cc-connect send --image /absolute/path/to/image.png   # 图片/截图
cc-connect send --file /absolute/path/to/report.pdf   # 文件（PDF、压缩包等）
cc-connect send --tts "text to speak"                 # 语音回复（需 TTS provider）
cc-connect send --file a.pdf --image b.png            # 多附件（--image / --file 均可重复）
```

## 工作流程

### 1. 截图发送（Wayland / Niri）

本机截图工具为 `grim` + `slurp`（区域选择）：

```bash
# 全屏/选区截图后直接发回
grim -g "$(slurp)" /tmp/cc-connect-shot.png
cc-connect send --image /tmp/cc-connect-shot.png
```

### 2. 生成文件发送

生成图表、PDF、压缩包等后，确认文件存在且可读，用绝对路径发送；多个附件可重复 `--image` / `--file`：

```bash
ls -lh /path/to/generated.pdf && cc-connect send --file /path/to/generated.pdf
```

### 3. 语音回复

用户要求「语音回复/读出来」时，用 `--tts`；文本内容为要朗读的内容。

### 4. 发送后

- 确认命令退出成功，向用户简要说明已发送的附件。
- 临时生成的截图/文件（如 `/tmp/cc-connect-*.png`）发送后应清理，避免堆积（使用 `remove-without-permission`）。

## 注意事项

- **必须使用绝对路径**；发送前先验证文件存在（`ls`/`test -f`），不存在的路径会发送失败。
- 附件默认上限 **50 MiB**，可经 `max_attachment_size_mb`（config.toml）或 `CC_MAX_ATTACHMENT_SIZE_MB` 环境变量调整；超限时先压缩（如 `zip`、`convert -quality` 压缩图片）再发送。
- 发送失败时检查：守护进程状态（`systemctl --user status cc-connect`）、socket 是否存在（`~/.cc-connect/run/api.sock`）、文件是否超限。
- 不要臆造文件路径；找不到用户所指的文件时，先询问或说明实际情况。
- 该命令用于发回**生成的附件**；如果用户只是要文字信息，直接文字回复，不要强行发附件。
