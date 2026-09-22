--!nonstrict

local status = { busy = false, last = "", history = {} }

local function render()
    local hasColor = type(status.last) == "string" and status.last ~= ""
    barWidget.setGlyph(status.busy and "loader-2" or "palette")
    barWidget.setGlyphColor(hasColor and "primary" or "on_surface")
    barWidget.setTooltip(status.busy and "正在取色…" or (hasColor and `取色器 · 最近 {status.last}` or "取色器"))
end

function onClick()
    noctalia.togglePanel("baizhu/bottom_bar:color-picker-panel")
end

function onRightClick()
    noctalia.state.set("picker-command", { action = "pick-instant" })
end

noctalia.state.watch("picker-status", function(value)
    if type(value) == "table" then status = value end
    render()
end)

local initial = noctalia.state.get("picker-status")
if type(initial) == "table" then status = initial end
render()
