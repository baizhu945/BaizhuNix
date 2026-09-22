--!nonstrict

local status = {
    available = false,
    watts = "N/A",
    capacity = 0,
    status = "Unavailable",
    energy_now = 0,
    energy_full = 0,
    time_seconds = 0,
    profile = "unknown",
}

local function formatDuration(seconds)
    local value = math.floor(tonumber(seconds) or 0)
    if value <= 0 then return "Calculating…" end
    local hours = math.floor(value / 3600)
    local minutes = math.floor((value % 3600) / 60)
    return `{hours}h {minutes}m`
end

local function setProfile(profile)
    noctalia.runAsync({ "powerprofilesctl", "set", profile }, function(result)
        if result.exitCode ~= 0 then
            noctalia.notifyError("Power Profile", noctalia.string.trim(result.stderr or "Unable to change profile"))
        end
    end)
end

function render()
    local capacity = math.max(0, math.min(100, tonumber(status.capacity) or 0))
    local profile = status.profile or "unknown"
    panel.render(ui.column({ gap = 12, flexGrow = 1, align = "stretch" }, {
        ui.row({ gap = 8, align = "center" }, {
            ui.glyph({ name = "battery", size = 22, color = "primary" }),
            ui.label({ text = "Battery Info", fontSize = 17, fontWeight = "bold", flexGrow = 1 }),
            ui.button({ glyph = "x", onClick = "onClose" }),
        }),
        ui.column({ gap = 8, padding = 12, fill = "surface_variant/0.35", radius = 10 }, {
            ui.row({ gap = 8, align = "center" }, {
                ui.label({ text = "Charge", color = "on_surface_variant", flexGrow = 1 }),
                ui.label({ text = `{math.floor(capacity + 0.5)}%`, fontWeight = "bold" }),
            }),
            ui.progress({ progress = capacity / 100, fill = "primary", track = "surface_variant", height = 7 }),
            ui.row({ gap = 8, align = "center" }, {
                ui.label({ text = "State", color = "on_surface_variant", flexGrow = 1 }),
                ui.label({ text = status.status or "Unknown" }),
            }),
            ui.row({ gap = 8, align = "center" }, {
                ui.label({ text = "Power", color = "on_surface_variant", flexGrow = 1 }),
                ui.label({ text = status.watts or "N/A", fontWeight = "bold" }),
            }),
            ui.row({ gap = 8, align = "center" }, {
                ui.label({ text = "Energy", color = "on_surface_variant", flexGrow = 1 }),
                ui.label({ text = string.format("%.2f / %.2f Wh", tonumber(status.energy_now) or 0, tonumber(status.energy_full) or 0) }),
            }),
            ui.row({ gap = 8, align = "center" }, {
                ui.label({ text = "Remaining", color = "on_surface_variant", flexGrow = 1 }),
                ui.label({ text = formatDuration(status.time_seconds) }),
            }),
        }),
        ui.label({ text = `Power profile: {profile}`, color = "on_surface_variant" }),
        ui.row({ gap = 8, align = "stretch" }, {
            ui.button({ text = "Power saver", glyph = "leaf", flexGrow = 1, variant = profile == "power-saver" and "primary" or "outline", onClick = function() setProfile("power-saver") end }),
            ui.button({ text = "Balanced", glyph = "scale", flexGrow = 1, variant = profile == "balanced" and "primary" or "outline", onClick = function() setProfile("balanced") end }),
            ui.button({ text = "Performance", glyph = "rocket", flexGrow = 1, variant = profile == "performance" and "primary" or "outline", onClick = function() setProfile("performance") end }),
        }),
        ui.button({ text = "Open system controls", glyph = "settings", variant = "ghost", onClick = function()
            noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "control-center", "system" })
            panel.close()
        end }),
    }))
end

function onOpen(_context)
    render()
end

function onClose()
    panel.close()
end

noctalia.state.watch("power-status", function(value)
    if type(value) == "table" then status = value end
    render()
end)

local initial = noctalia.state.get("power-status")
if type(initial) == "table" then status = initial end
render()
