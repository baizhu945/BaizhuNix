--!nonstrict
-- CPU-reactive port of the v4 Catwalk widget.

local threshold = tonumber(noctalia.getConfig("minimum_threshold")) or 10
local externalMonitor = noctalia.getConfig("external_monitor") or "resources || missioncenter || jdsystemmonitor || corestats || system-monitoring-center || gnome-system-monitor || plasma-systemmonitor || mate-system-monitor || ukui-system-monitor || deepin-system-monitor || pantheon-system-monitor"
local activeFrame = 1
local idleFrame = 1
local tick = 0
local lastInterval = 0
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

local function setInterval(ms)
    if ms ~= lastInterval then
        lastInterval = ms
        noctalia.setUpdateInterval(ms)
    end
end

local function render(cpu)
    local running = cpu >= threshold
    if running then
        tick += 1
        activeFrame = (activeFrame % #activeIcons) + 1
        setInterval(math.max(30, math.floor(200 - cpu * 1.7)))
        barWidget.setImage(activeIcons[activeFrame], false, 18, 18)
    else
        -- V4 advances one idle frame on every 400ms timer tick.
        idleFrame = (idleFrame % #idleIcons) + 1
        setInterval(400)
        barWidget.setImage(idleIcons[idleFrame], false, 18, 18)
    end
    barWidget.setTooltip(running and noctalia.tr("tooltip.running") or noctalia.tr("tooltip.sleeping"))
end

function update()
    local currentDarkMode = noctalia.isDarkMode()
    if currentDarkMode ~= darkMode then
        darkMode = currentDarkMode
        activeFrame = 1
        idleFrame = 1
        selectIcons()
    end
    local stats = noctalia.systemStats()
    local cpu = 0
    if stats ~= nil and stats.cpu ~= nil then
        cpu = tonumber(stats.cpu.usagePercent) or 0
    end
    render(cpu)
end

function onClick()
    noctalia.togglePanel("baizhu/catwalk:panel")
end

-- V4 opens the Catwalk panel with either primary or secondary click.
function onRightClick()
    noctalia.togglePanel("baizhu/catwalk:panel")
end

function onMiddleClick()
    noctalia.runAsync(externalMonitor)
end
