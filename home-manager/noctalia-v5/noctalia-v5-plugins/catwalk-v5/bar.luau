--!nonstrict
-- CPU-reactive port of the v4 Catwalk widget.

local threshold = tonumber(noctalia.getConfig("minimum_threshold")) or 10
local activeFrame = 1
local idleFrame = 1
local tick = 0
local lastInterval = 0

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
        tick += 1
        if tick % 4 == 0 then
            idleFrame = (idleFrame % #idleIcons) + 1
        end
        setInterval(400)
        barWidget.setImage(idleIcons[idleFrame], false, 18, 18)
    end
    barWidget.setTooltip(`CPU {math.floor(cpu)}%`)
end

function update()
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
