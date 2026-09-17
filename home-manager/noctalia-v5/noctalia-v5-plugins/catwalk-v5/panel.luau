--!nonstrict
-- Small panel companion for the CPU-reactive Catwalk bar widget.

local threshold = tonumber(noctalia.getConfig("minimum_threshold")) or 10
local activeFrame = 1
local idleFrame = 1
local darkMode = noctalia.isDarkMode()
local activeIcons = {}
local idleIcons = {}

local function selectIcons()
    local directory = darkMode and "icons/dark" or "icons/light"
    activeIcons = {
        `{directory}/my-active-0-symbolic.svg`,
        `{directory}/my-active-1-symbolic.svg`,
        `{directory}/my-active-2-symbolic.svg`,
        `{directory}/my-active-3-symbolic.svg`,
        `{directory}/my-active-4-symbolic.svg`,
    }
    idleIcons = {
        `{directory}/my-idle-0-symbolic.svg`,
        `{directory}/my-idle-1-symbolic.svg`,
        `{directory}/my-idle-2-symbolic.svg`,
        `{directory}/my-idle-3-symbolic.svg`,
    }
end

selectIcons()

local lastInterval = 0

local function setInterval(ms)
    if ms ~= lastInterval then
        lastInterval = ms
        noctalia.setUpdateInterval(ms)
    end
end

local function currentCpu()
    local stats = noctalia.systemStats()
    if stats ~= nil and stats.cpu ~= nil then
        return tonumber(stats.cpu.usagePercent) or 0
    end
    return 0
end

local function render()
    local currentDarkMode = noctalia.isDarkMode()
    if currentDarkMode ~= darkMode then
        darkMode = currentDarkMode
        activeFrame = 1
        idleFrame = 1
        selectIcons()
    end
    local cpu = currentCpu()
    local running = cpu >= threshold
    if running then
        activeFrame = (activeFrame % #activeIcons) + 1
        setInterval(math.max(30, math.floor(200 - cpu * 1.7)))
    else
        idleFrame = (idleFrame % #idleIcons) + 1
        setInterval(400)
    end
    local path = running and activeIcons[activeFrame] or idleIcons[idleFrame]
    panel.render(ui.column({ gap = 16, align = "center", justify = "center" }, {
        ui.image({ path = path, width = 128, height = 128, fit = "contain" }),
        ui.label({ text = `CPU: {math.floor(cpu)}%`, fontSize = 18, fontWeight = "bold", color = "on_surface" }),
        ui.button({ glyph = "x", onClick = "onClose" }),
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
