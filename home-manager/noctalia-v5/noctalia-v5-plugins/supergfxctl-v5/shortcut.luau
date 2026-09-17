--!nonstrict
local gfx = require("./common.luau")
local available = false
local current = ""
local pending = ""
local action = ""
local supported = {}
local polling = noctalia.getConfig("polling") == true
local pollingInterval = math.max(1000, math.floor(tonumber(noctalia.getConfig("polling_interval")) or 3000))
local patchPending = noctalia.getConfig("patch_pending") ~= false
local debug = noctalia.getConfig("debug") == true

noctalia.setUpdateInterval(polling and pollingInterval or 60000)

local function render()
    shortcut.setIcon(gfx.icon(current))
    local label = current == "" and "GPU" or gfx.label(current)
    if pending ~= "" and pending ~= current then
        label ..= ` → {gfx.label(pending)}`
    end
    shortcut.setLabel(label)
    shortcut.setActive(false)
    shortcut.setEnabled(available)
end

local function applyStatus(status)
    if type(status) ~= "table" then return end
    available = status.available == true
    current = status.current or ""
    pending = status.pending or ""
    action = status.action or ""
    supported = status.supported or supported
    render()
end

local function refresh()
    if debug then noctalia.log("refreshing SuperGFX status") end
    noctalia.runAsync({ "supergfxctl", "--version", "--get", "--supported", "--pend-action", "--pend-mode" }, function(result)
        if result.exitCode == 0 then
            local status = gfx.parse(result.stdout or "")
            available = status.available
            current = status.current
            pending = status.pending or ""
            action = status.action or ""
            supported = status.supported or {}
            if patchPending and pending ~= "" then
                action = gfx.requiredAction(pending, current)
            end
        else
            available = false
            current = ""
            pending = ""
            action = ""
            supported = {}
        end
        noctalia.state.set("status", {
            available = available,
            current = current,
            pending = pending,
            action = action,
            supported = supported,
        })
        render()
    end)
end

function update()
    refresh()
end

function onClick()
    if available then
        noctalia.togglePanel("baizhu/supergfxctl:panel")
    end
end

noctalia.state.watch("status", applyStatus)
render()
refresh()
