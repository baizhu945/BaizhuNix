--!nonstrict
-- Screen Toolkit bridge for Noctalia v5.
--
-- V4 rendered several Qt overlay surfaces inside Quickshell. V5 plugin entries
-- are deliberately headless, so tools.sh provides the same user-facing actions
-- through Satty, chameleos, the Wayland capture tools, and the existing OCR
-- helper. Keeping this routing in a service also makes compositor hotkeys work
-- even when the panel is closed.

local tool = (noctalia.pluginDir() or "") .. "/tools.sh"

local function runTool(action, title)
    if tool == "/tools.sh" then
        noctalia.notifyError("Screen Toolkit", "Plugin directory is unavailable")
        return
    end
    if not noctalia.runAsync({ "bash", tool, action }, function(result)
        if result.exitCode == 0 then
            noctalia.notify("Screen Toolkit", `{title}已完成`)
        else
            local detail = noctalia.string.trim(result.stderr or "")
            noctalia.notifyError("Screen Toolkit", detail ~= "" and detail or `{title}失败`)
        end
    end) then
        noctalia.notifyError("Screen Toolkit", `Unable to start {title}`)
    end
end

function onIpc(event, _payload)
    if event == "toggle" then
        noctalia.togglePanel("baizhu/screen_toolkit:panel")
    elseif event == "annotate" then
        runTool("annotate-region", "区域标注")
    elseif event == "annotateFullscreen" then
        runTool("annotate-fullscreen", "全屏涂鸦")
    elseif event == "exit" or event == "recordStop" then
        runTool(event == "exit" and "stop-all" or "record-stop", "工具")
    elseif event == "colorPicker" then
        runTool("color-picker", "取色器")
    elseif event == "ocr" then
        runTool("ocr", "OCR")
    elseif event == "qr" then
        runTool("qr", "二维码扫描")
    elseif event == "palette" then
        runTool("palette", "调色板")
    elseif event == "lens" then
        runTool("lens", "Google Lens")
    elseif event == "pin" then
        runTool("pin-region", "固定截图")
    elseif event == "pinImage" then
        runTool("pin-image", "固定图片")
    elseif event == "measure" then
        runTool("measure", "测量")
    elseif event == "mirror" then
        runTool("mirror", "摄像头镜像")
    elseif event == "record" or event == "recordMp4" then
        runTool("record-region", "区域录制")
    elseif event == "recordFullscreen" or event == "recordFullscreenMp4" then
        -- The recorder service is a different plugin, so use the public v5
        -- IPC route rather than this plugin's private state channel.
        if noctalia.runAsync({ "noctalia", "msg", "plugin", "noctalia/screen_recorder:service", "all", "start", "screen" }) then
            noctalia.notify("Screen Toolkit", "已请求全屏录制")
        else
            noctalia.notifyError("Screen Toolkit", "无法请求全屏录制")
        end
    elseif event == "screenshot" then
        runTool("screenshot-region", "区域截图")
    else
        noctalia.notifyError("Screen Toolkit", `Unknown action: {event}`)
    end
end

noctalia.setUpdateInterval(60000)
function update()
end
