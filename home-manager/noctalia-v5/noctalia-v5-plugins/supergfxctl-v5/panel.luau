--!nonstrict
local gfx = require("./common.luau")
local status = { available = false, current = "", pending = "", action = "", supported = {} }
local busy = false

noctalia.setUpdateInterval(3000)

local function refresh()
    noctalia.runAsync({ "supergfxctl", "--version", "--get", "--supported", "--pend-action", "--pend-mode" }, function(result)
        if result.exitCode == 0 then
            status = gfx.parse(result.stdout or "")
        else
            status = { available = false, current = "", pending = "", action = "", supported = {} }
        end
        busy = false
        render()
    end)
end

local function setMode(mode)
    if busy or not status.available or status.current == mode then
        return
    end
    busy = true
    render()
    noctalia.runAsync({ "supergfxctl", "--mode", mode }, function(result)
        if result.exitCode ~= 0 then
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
            ui.button({ glyph = "refresh", onClick = refresh }),
            ui.button({ glyph = "close", onClick = "onClose" }),
        }),
        ui.label({
            text = status.available and `Current: {gfx.label(status.current)}{status.action ~= "No action required" and `  ·  {status.action}` or ""}` or "supergfxctl is unavailable",
            color = status.available and "on_surface" or "error",
        }),
    }

    local modes = { "Integrated", "Hybrid", "AsusMuxDgpu", "NvidiaNoModeset", "Vfio", "AsusEgpu" }
    local modeButtons = {}
    for _, mode in ipairs(modes) do
        if status.supported[mode] == true then
            local variant = status.current == mode and "primary" or (status.pending == mode and "secondary" or "outline")
            table.insert(modeButtons, ui.button({
                key = `mode-{mode}`,
                glyph = gfx.icon(mode),
                text = gfx.label(mode),
                variant = variant,
                enabled = status.available and not busy and status.current ~= mode,
                onClick = function()
                    setMode(mode)
                end,
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

render()
