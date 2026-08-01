# cc-connect send 命令参考

`cc-connect send` 把本地生成的附件（截图、图表、PDF、压缩包等）发回当前聊天（Agent Attachment Send-Back）。依赖 cc-connect 守护进程（`systemctl --user status cc-connect`，socket `~/.cc-connect/run/api.sock`）。

## 命令与参数

```bash
cc-connect send --image /absolute/path/to/image.png   # 图片/截图
cc-connect send --file /absolute/path/to/report.pdf   # 文件
cc-connect send --tts "text to speak"                 # 语音回复
cc-connect send --file a.pdf --image b.png            # 多附件
```

| 参数 | 说明 |
|------|------|
| `--image <路径>` | 发送图片/截图；可重复 |
| `--file <路径>` | 发送任意文件（PDF、zip 等）；可重复 |
| `--tts <文本>` | 发送合成语音（需在 config.toml 配置 TTS provider） |
| `--image` + `--file` | 可组合，一条命令发多个附件 |

规则：
- **必须使用绝对路径**（最安全）。
- 附件默认上限 **50 MiB**：`config.toml` 的 `max_attachment_size_mb` 或环境变量 `CC_MAX_ATTACHMENT_SIZE_MB`（单位 MiB）。
- 该命令只用于发送**生成的附件**；普通文本回复直接回复即可。

## 配置

| 配置项 | 位置 | 默认 | 说明 |
|--------|------|------|------|
| `attachment_send` | `config.toml` 全局 | `"on"` | `"off"` 时禁用 image/file 发送（`--tts` 不受此开关控制，走 TTS 配置） |
| `max_attachment_size_mb` | `config.toml` | 50 | 附件大小上限 |
| `CC_MAX_ATTACHMENT_SIZE_MB` | 环境变量 | — | 同上，优先级同 |

平台支持：附件发回当前支持 **Feishu** 与 **Telegram**。

## 工作流示例

### 截图（Wayland / Niri）

```bash
grim -g "$(slurp)" /tmp/cc-connect-shot.png      # 区域截图
cc-connect send --image /tmp/cc-connect-shot.png
```

（封装脚本：`scripts/send-screenshot.sh`）

### 生成文件后发送

```bash
# 生成 PDF/图表等 → 确认存在 → 发送
ls -lh /tmp/report.pdf
cc-connect send --file /tmp/report.pdf
```

### 语音回复

```bash
cc-connect send --tts "以下是本次任务的总结……"
```

## 排错

| 现象 | 处理 |
|------|------|
| 命令无响应/连接失败 | 守护进程未运行：`systemctl --user status cc-connect`；确认 socket `~/.cc-connect/run/api.sock` 存在 |
| 附件没发出去 | 检查 `attachment_send` 是否为 `"off"`；确认文件存在、未超 50 MiB |
| 首次使用不生效 | 在聊天中执行 `/bind setup` 或 `/cron setup` 刷新记忆文件中的发送指令 |
| 超限 | 压缩后发送：`zip` 打包、`convert -quality 80 in.png out.jpg` 压图 |
| 找不到用户所指文件 | 不要臆造路径，先向用户询问实际位置 |

## 相关

- 定时任务中发附件：`cc-connect cron`（见 `cc-connect-cron` skill）
- 浏览器截图自动化：`chrome-automation` skill（agent-browser 截图后同样用 `cc-connect send --image` 发回）
