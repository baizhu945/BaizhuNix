--!nonstrict
-- Native v5 panel for the V4 SuperGFX Control plugin.
-- It retains V4's supported-mode pills and its patchPending action hint.

local gfx = require("./common.luau")
local status = { available = false, current = "", pending = "", action = "", supported = {} }
local busy = false
local polling = noctalia.getConfig("polling") == true
local pollingInterval = math.max(1000, math.floor(tonumber(noctalia.getConfig("polling_interval")) or 3000))
local patchPending = noctalia.getConfig("patch_pending") ~= false
local debug = noctalia.getConfig("debug") == true
local pendingOverride = nil

noctalia.setUpdateInterval(polling and pollingInterval or 60000)

local modes = { "Integrated", "Hybrid", "AsusMuxDgpu", "NvidiaNoModeset", "Vfio", "AsusEgpu" }

local function publish()
    noctalia.state.set("status", status)
end

local function applyStatus(value)
    if type(value) == "table" then
        status = value
        status.supported = type(status.supported) == "table" and status.supported or {}
        if patchPending then
            if pendingOverride ~= nil then
                status.pending = pendingOverride
            end
            if status.pending ~= nil and status.pending ~= "" then
                status.action = gfx.requiredAction(status.pending, status.current)
            end
        end
    end
    render()
end

local function refresh()
    if debug then noctalia.log("refreshing SuperGFX status") end
    noctalia.runAsync({ "supergfxctl", "--version", "--get", "--supported", "--pend-action", "--pend-mode" }, function(result)
        if result.exitCode == 0 then
            local nextStatus = gfx.parse(result.stdout or "")
            if patchPending then
                if pendingOverride ~= nil then
                    nextStatus.pending = pendingOverride
                end
                if nextStatus.pending ~= nil and nextStatus.pending ~= "" then
                    nextStatus.action = gfx.requiredAction(nextStatus.pending, nextStatus.current)
                end
            end
            status = nextStatus
        else
            status = { available = false, current = "", pending = "", action = "", supported = {} }
        end
        busy = false
        publish()
        render()
    end)
end

local function openSession()
    if not noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "session" }) then
        noctalia.notifyError("SuperGFX Control", "无法打开会话面板")
    end
end

local function setMode(mode)
    local cancelling = status.current == mode and status.pending ~= nil and status.pending ~= ""
    if busy or not status.available or (status.current == mode and not cancelling) then
        return
    end
    busy = true
    pendingOverride = cancelling and "" or mode
    status.pending = pendingOverride
    status.action = (patchPending and pendingOverride ~= "") and gfx.requiredAction(pendingOverride, status.current) or ""
    publish()
    render()

    noctalia.runAsync({ "supergfxctl", "--mode", mode }, function(result)
        if result.exitCode ~= 0 then
            pendingOverride = nil
            noctalia.notifyError("SuperGFX Control", noctalia.string.trim(result.stderr or "supergfxctl failed"))
        end
        refresh()
    end)
end

function render()
    local children = {
        ui.row({ gap = 8, align = "center" }, {
            ui.glyph({ name = gfx.icon(status.current), size = 22, color = "primary" }),
            ui.label({ text = "SuperGFX Control", fontSize = 17, fontWeight = "bold", flexGrow = 1 }),
            ui.button({ glyph = "refresh", enabled = not busy, onClick = refresh }),
            ui.button({ glyph = "x", onClick = "onClose" }),
        }),
        ui.label({
            text = status.available and `Current: {gfx.label(status.current)}` or "supergfxctl is unavailable",
            color = status.available and "on_surface" or "error",
        }),
    }

    if status.action ~= "" and status.action ~= "No action required" then
        local actionIsMode = status.action == "You must switch to Integrated first"
        table.insert(children, ui.button({
            glyph = gfx.actionGlyph(status.action),
            text = actionIsMode and "Switch to Integrated" or status.action,
            variant = "secondary",
            onClick = actionIsMode and function() setMode("Integrated") end or openSession,
        }))
    end

    local modeButtons = {}
    for _, mode in ipairs(modes) do
        if status.supported[mode] == true then
            local isCurrent = status.current == mode and (status.pending == nil or status.pending == "")
            local isPending = status.pending == mode
            table.insert(modeButtons, ui.button({
                key = `mode-{mode}`,
                glyph = gfx.icon(mode),
                text = gfx.label(mode),
                variant = isCurrent and "primary" or (isPending and "secondary" or "outline"),
                enabled = status.available and not busy and not isCurrent and not isPending,
                onClick = function() setMode(mode) end,
            }))
        end
    end
    if #modeButtons == 0 then
        table.insert(modeButtons, ui.label({ text = "No supported GPU modes reported.", color = "on_surface_variant" }))
    end
    table.insert(children, ui.scroll({ flexGrow = 1, gap = 8, align = "stretch", fill = "surface_variant/0.25", radius = 8, padding = 8 }, modeButtons))
    if busy then
        table.insert(children, ui.label({ text = "Applying GPU mode…", color = "tertiary" }))
    end
    panel.render(ui.column({ gap = 12, flexGrow = 1, align = "stretch" }, children))
end

function onOpen(_context)
    refresh()
end

function onClose()
    panel.close()
end

noctalia.state.watch("status", applyStatus)
render()
refresh()
