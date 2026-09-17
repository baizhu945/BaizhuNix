--!nonstrict
-- Compact V5 equivalent of the V4 recorder bar context menu.

local state = "idle"
local available = false

local function send(action)
    noctalia.state.set("command", {
        action = action,
        focusedOutputName = noctalia.focusedOutputName(),
    })
    panel.close()
end

local function actionButton(glyph, text, action, variant)
    return ui.button({
        glyph = glyph,
        text = text,
        variant = variant or "outline",
        contentAlign = "start",
        onClick = function() send(action) end,
    })
end

function render()
    local actions = {}
    if available then
        if state == "replaying" then
            table.insert(actions, actionButton("device-floppy", "保存回放", "replay-save", "primary"))
            table.insert(actions, actionButton("player-stop", "停止回放", "replay-stop", "outline"))
        elseif state == "replay_pending" then
            table.insert(actions, actionButton("player-stop", "取消启动回放", "replay-stop", "outline"))
        elseif state == "idle" and noctalia.getConfig("replay_enabled") == true then
            table.insert(actions, actionButton("player-play", "启动回放缓冲", "replay-start", "outline"))
        end
    end

    table.insert(actions, ui.button({
        glyph = "settings",
        text = "录屏设置",
        variant = "ghost",
        contentAlign = "start",
        onClick = function()
            panel.close()
            noctalia.openSettings()
        end,
    }))

    panel.render(ui.column({ gap = 8, padding = 10, align = "stretch" }, {
        ui.row({ gap = 8, align = "center" }, {
            ui.glyph({ name = "video", size = 20, color = state == "recording" and "error" or "primary" }),
            ui.label({ text = "屏幕录制", fontWeight = "bold", flexGrow = 1 }),
            ui.button({ glyph = "x", variant = "ghost", onClick = function() panel.close() end }),
        }),
        ui.label({
            text = available and (state == "recording" and "正在录制" or "录屏器可用") or "gpu-screen-recorder 不可用",
            color = "on_surface_variant",
        }),
        ui.column({ gap = 7, align = "stretch" }, actions),
    }))
end

local function applyStatus(status)
    if type(status) == "table" then
        state = status.state or "idle"
        available = status.available == true
    end
    render()
end

function onOpen(_context)
    applyStatus(noctalia.state.get("status"))
end

noctalia.state.watch("status", applyStatus)
render()
