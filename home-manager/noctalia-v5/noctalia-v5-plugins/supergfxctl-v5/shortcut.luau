--!nonstrict
local gfx = require("./common.luau")
local available = false
local current = ""

noctalia.setUpdateInterval(3000)

local function render()
    shortcut.setIcon(gfx.icon(current))
    shortcut.setLabel(current == "" and "GPU" or gfx.label(current))
    shortcut.setActive(false)
    shortcut.setEnabled(available)
end

local function refresh()
    noctalia.runAsync({ "supergfxctl", "--version", "--get", "--supported", "--pend-action", "--pend-mode" }, function(result)
        if result.exitCode == 0 then
            local status = gfx.parse(result.stdout or "")
            available = status.available
            current = status.current
        else
            available = false
            current = ""
        end
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

render()
refresh()
