--!nonstrict
-- Small panel companion for the CPU-reactive Catwalk bar widget.

local threshold = tonumber(noctalia.getConfig("minimum_threshold")) or 10
local activeFrame = 1
local idleFrame = 1
local activeIcons = {
    "icons/my-active-0-symbolic.svg",
    "icons/my-active-1-symbolic.svg",
    "icons/my-active-2-symbolic.svg",
    "icons/my-active-3-symbolic.svg",
    "icons/my-active-4-symbolic.svg",
}
local idleIcons = {
    "icons/my-idle-0-symbolic.svg",
    "icons/my-idle-1-symbolic.svg",
    "icons/my-idle-2-symbolic.svg",
    "icons/my-idle-3-symbolic.svg",
}

noctalia.setUpdateInterval(400)

local function currentCpu()
    local stats = noctalia.systemStats()
    if stats ~= nil and stats.cpu ~= nil then
        return tonumber(stats.cpu.usagePercent) or 0
    end
    return 0
end

local function render()
    local cpu = currentCpu()
    local running = cpu >= threshold
    if running then
        activeFrame = (activeFrame % #activeIcons) + 1
    else
        idleFrame = (idleFrame % #idleIcons) + 1
    end
    local path = running and activeIcons[activeFrame] or idleIcons[idleFrame]
    panel.render(ui.column({ gap = 16, align = "center", justify = "center" }, {
        ui.image({ path = path, width = 128, height = 128, fit = "contain" }),
        ui.label({ text = `CPU: {math.floor(cpu)}%`, fontSize = 18, fontWeight = "bold", color = "on_surface" }),
        ui.button({ glyph = "close", onClick = "onClose" }),
    }))
end

function onOpen(_context)
    render()
end

function update()
    render()
end

function onClose()
    panel.close()
end
