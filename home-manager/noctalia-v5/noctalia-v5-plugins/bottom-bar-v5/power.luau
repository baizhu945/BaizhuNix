--!nonstrict

local status = { available = false, watts = "N/A" }

local function render()
    local text = status.watts or "N/A"
    barWidget.render(ui.row({ gap = 6, align = "center", paddingH = 7 }, {
        ui.glyph({ name = "bolt", size = 14, color = status.available and "on_surface" or "on_surface_variant" }),
        ui.label({ text = text, color = "primary", maxLines = 1 }),
    }))
    barWidget.setTooltip(`Power usage: {text}`)
end

function onClick()
    noctalia.togglePanel("baizhu/bottom_bar:power-info")
end

noctalia.state.watch("power-status", function(value)
    if type(value) == "table" then status = value end
    render()
end)

local initial = noctalia.state.get("power-status")
if type(initial) == "table" then status = initial end
render()
