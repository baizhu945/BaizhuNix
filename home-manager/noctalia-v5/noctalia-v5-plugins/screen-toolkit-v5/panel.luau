--!nonstrict
-- Native v5 panel for the V4 Screen Toolkit workflow. Overlay-heavy actions
-- are delegated to tools.sh; this keeps the panel useful without embedding
-- Quickshell QML in the v5 Luau VM.

local tool = (noctalia.pluginDir() or "") .. "/tools.sh"

local function runTool(action, title)
    if tool == "/tools.sh" then
        noctalia.notifyError("Screen Toolkit", "Plugin directory is unavailable")
        return
    end
    local accepted = noctalia.runAsync({ "bash", tool, action }, function(result)
        if result.exitCode == 0 then
            noctalia.notify("Screen Toolkit", `{title}已完成`)
        else
            local detail = noctalia.string.trim(result.stderr or "")
            noctalia.notifyError("Screen Toolkit", detail ~= "" and detail or `{title}失败`)
        end
    end)
    if accepted then
        panel.close()
    else
        noctalia.notifyError("Screen Toolkit", `Unable to start {title}`)
    end
end

local function runRecorder(action, title)
    local accepted = noctalia.runAsync(
        { "noctalia", "msg", "plugin", "noctalia/screen_recorder:service", "all", action, "screen" },
        function(result)
            if result.exitCode == 0 then
                noctalia.notify("Screen Toolkit", `已请求{title}`)
            else
                noctalia.notifyError("Screen Toolkit", noctalia.string.trim(result.stderr or `{title}失败`))
            end
        end
    )
    if accepted then
        panel.close()
    else
        noctalia.notifyError("Screen Toolkit", `Unable to start {title}`)
    end
end

local function button(glyph, text, callback, variant)
    return ui.button({
        glyph = glyph,
        text = text,
        variant = variant or "outline",
        controlSize = "sm",
        onClick = callback,
    })
end

function render()
    panel.render(ui.column({ gap = 12, flexGrow = 1, align = "stretch" }, {
        ui.row({ gap = 8, align = "center" }, {
            ui.glyph({ name = "screenshot", size = 22, color = "primary" }),
            ui.label({ text = "Screen Toolkit", fontSize = 17, fontWeight = "bold", flexGrow = 1 }),
            ui.button({ glyph = "x", onClick = "onClose" }),
        }),
        ui.label({
            text = "V4-compatible screen tools · region capture, annotation, OCR and media",
            color = "on_surface_variant",
            maxLines = 2,
        }),
        ui.scroll({ flexGrow = 1, gap = 8, align = "stretch", fill = "surface_variant/0.25", radius = 8, padding = 10 }, {
            ui.row({ gap = 8, align = "stretch" }, {
                ui.column({ gap = 8, flexGrow = 1, align = "stretch" }, {
                    button("brush", "区域标注", function() runTool("annotate-region", "区域标注") end),
                    button("maximize", "全屏涂鸦", function() runTool("annotate-fullscreen", "全屏涂鸦") end),
                    button("color-picker", "颜色拾取", function() runTool("color-picker", "取色器") end),
                    button("palette", "调色板", function() runTool("palette", "调色板") end),
                    button("scan", "OCR 识别", function() runTool("ocr", "OCR") end),
                    button("qrcode", "二维码 / 条码", function() runTool("qr", "二维码扫描") end),
                }),
                ui.column({ gap = 8, flexGrow = 1, align = "stretch" }, {
                    button("world-search", "Google Lens", function() runTool("lens", "Google Lens") end),
                    button("pin", "固定选区", function() runTool("pin-region", "固定截图") end),
                    button("folder-open", "固定图片", function() runTool("pin-image", "固定图片") end),
                    button("ruler", "测量选区", function() runTool("measure", "测量") end),
                    button("camera", "摄像头镜像", function() runTool("mirror", "摄像头镜像") end),
                    button("screenshot", "区域截图", function() runTool("screenshot-region", "区域截图") end),
                }),
            }),
        }),
        ui.row({ gap = 8, align = "stretch" }, {
            ui.button({ glyph = "video", text = "区域录制", flexGrow = 1, controlSize = "sm", variant = "outline", onClick = function() runTool("record-region", "区域录制") end }),
            ui.button({ glyph = "video", text = "全屏录制", flexGrow = 1, controlSize = "sm", variant = "outline", onClick = function() runRecorder("start", "全屏录制") end }),
            ui.button({ glyph = "x", text = "停止工具", flexGrow = 1, controlSize = "sm", variant = "ghost", onClick = function() runTool("stop-all", "工具") end }),
        }),
    }))
end

function onOpen(_context)
    render()
end

function onClose()
    panel.close()
end

render()
