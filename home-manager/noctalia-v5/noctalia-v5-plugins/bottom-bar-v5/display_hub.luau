--!nonstrict

local mirrorStatus = { mirrors = {}, count = 0 }

local function rememberTarget()
    local target = noctalia.focusedOutputName()
    noctalia.state.set("mirror-target", target or "")
end

local function openHub(section)
    rememberTarget()
    noctalia.state.set("display-hub-section", section or "")
    noctalia.togglePanel("baizhu/bottom_bar:display-hub-panel")
end

local function render()
    local count = tonumber(mirrorStatus.count) or 0
    local children = {
        ui.glyph({ name = "device-desktop", size = 14, color = "on_surface" }),
        ui.glyph({ name = "screen-share", size = 12, color = count > 0 and "primary" or "on_surface_variant" }),
    }
    if count > 0 then table.insert(children, ui.label({ text = tostring(count), color = "primary", fontWeight = "bold" })) end
    barWidget.render(ui.row({ gap = 4, align = "center", paddingH = 6 }, children))
    barWidget.setTooltip(count > 0 and `显示与镜像 · {count} 个活动镜像` or "显示管理与复制显示")
end

function onClick()
    openHub("")
end

function onRightClick()
    openHub("mirror")
end

function onMiddleClick()
    openHub("display")
end

noctalia.state.watch("mirror-status", function(value)
    if type(value) == "table" then mirrorStatus = value end
    render()
end)

local initial = noctalia.state.get("mirror-status")
if type(initial) == "table" then mirrorStatus = initial end
render()
