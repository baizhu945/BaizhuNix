--!nonstrict
-- GPU Screen Recorder - bar widget (thin presentation client).
--
-- The recording logic lives in the [[service]] (recorder_service.luau), which runs
-- for the whole session. This widget only reflects the published "status" and
-- drives the recorder by writing to the "command" channel.
--
-- Click mapping:
--   Left click   - start/stop recording
--   Right click  - toggle replay buffer, or save replay (when one is running)
--   Middle click - save replay buffer

local state = "idle" -- idle | pending | recording | stopping | replay_pending | replaying | replay_stopping
local available = false
local RECORDING_STATES = { "recording", "pending", "stopping" }
local PENDING_STATES = { "pending", "stopping", "replay_pending", "replay_stopping" }

local function send(action)
    noctalia.state.set("command", { action = action, focusedOutputName = noctalia.focusedOutputName() })
end

-- Glyph per state, configurable. The fallback passed to each lookup is the
-- value this widget used before the settings existed, so an unset or blank
-- glyph keeps the previous appearance.
local function glyphFor(key, fallback)
    local configured = noctalia.getConfig(key)
    if type(configured) == "string" and configured ~= "" then
        return configured
    end
    return fallback
end

local function applyStatus(status)
    if type(status) == "table" then
        state = status.state or "idle"
        available = if status.available then true else false
    end

    local hideInactive = noctalia.getConfig("hide_inactive")

    if not available then
        barWidget.setGlyph(glyphFor("glyph_unavailable", "video-off"))
        barWidget.setGlyphColor("on_surface_variant")
        barWidget.setTooltip("gpu-screen-recorder 不可用")
        barWidget.setVisible(not hideInactive)
        return
    end

    if state == "recording" then
        barWidget.setGlyph(glyphFor("glyph_recording", "video"))
        barWidget.setGlyphColor("error")
        barWidget.setColor("error")
        barWidget.setTooltip("正在录制 · 左键停止")
        barWidget.setVisible(true)
    elseif table.find(PENDING_STATES, state) then
        barWidget.setGlyph(glyphFor("glyph_pending", "video"))
        barWidget.setGlyphColor("primary")
        barWidget.setColor("primary")
        barWidget.setTooltip("正在启动录屏")
        barWidget.setVisible(true)
    elseif state == "replaying" then
        barWidget.setGlyph(glyphFor("glyph_replaying", "repeat"))
        barWidget.setGlyphColor("secondary")
        barWidget.setColor("secondary")
        barWidget.setTooltip("回放缓冲运行中 · 中键保存 · 右键菜单")
        barWidget.setVisible(true)
    else
        barWidget.setGlyph(glyphFor("glyph_idle", "video"))
        barWidget.setGlyphColor("on_surface")
        barWidget.setColor("on_surface")
        barWidget.setTooltip("屏幕录制 · 左键开始 · 右键菜单")
        barWidget.setVisible(not hideInactive)
    end
end

function onClick()
    if not available then
        noctalia.notifyError("Screen Recorder", "gpu-screen-recorder 未安装或不可用")
        return
    end
    if table.find(RECORDING_STATES, state) then
        send("stop")
    elseif state == "idle" then
        send("start")
    end
end

function onRightClick()
    noctalia.togglePanel("noctalia/screen_recorder:menu")
end

function onMiddleClick()
    if state == "replaying" then
        send("replay-save")
    end
end

-- Sync the current status on load, then track changes.
applyStatus(noctalia.state.get("status"))
noctalia.state.watch("status", applyStatus)
