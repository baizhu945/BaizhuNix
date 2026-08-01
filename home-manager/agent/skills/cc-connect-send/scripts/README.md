# Scripts

## cc-send.sh

`cc-connect send` 的辅助封装：发送前校验守护进程（socket `~/.cc-connect/run/api.sock`）、文件是否存在、附件是否超过大小上限（默认 50 MiB，可用 `CC_MAX_ATTACHMENT_SIZE_MB` 覆盖），校验通过后原样透传参数发送。

```bash
bash ~/.config/opencode/skills/cc-connect-send/scripts/cc-send.sh --image /tmp/chart.png
bash ~/.config/opencode/skills/cc-connect-send/scripts/cc-send.sh --file /tmp/report.pdf
bash ~/.config/opencode/skills/cc-connect-send/scripts/cc-send.sh --tts "回复内容"
bash ~/.config/opencode/skills/cc-connect-send/scripts/cc-send.sh --file a.pdf --image b.png
```

### What it does
1. 检查 `cc-connect` 在 PATH、守护进程 socket 存在
2. 逐个校验 `--image` / `--file` 的文件存在性与大小上限（超限时报错并提示压缩）
3. 校验 `--tts` 文本非空
4. 调用 `cc-connect send` 发送

## send-screenshot.sh

Wayland（Niri）截图并直接发送：`grim` + `slurp` 区域选择（`--full` 参数切换全屏），发送前复用 cc-send.sh 校验。

```bash
bash ~/.config/opencode/skills/cc-connect-send/scripts/send-screenshot.sh          # 选区
bash ~/.config/opencode/skills/cc-connect-send/scripts/send-screenshot.sh --full   # 全屏
```

### What it does
1. `grim -g "$(slurp)"` 选区截图（或 `grim` 全屏）到 `/tmp/cc-connect-shot-<ts>.png`
2. 校验文件非空
3. 调用 cc-send.sh 发送；失败时清理临时文件
