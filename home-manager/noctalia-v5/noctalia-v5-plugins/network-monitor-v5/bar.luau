--!nonstrict
-- Combined V4 SystemMonitor network view. Keeping RX and TX in one plugin
-- widget preserves the original single-capsule placement rather than creating
-- two adjacent v5 sysmon capsules.

local externalMonitor = noctalia.getConfig("external_monitor") or "resources || missioncenter || jdsystemmonitor || corestats || system-monitoring-center || gnome-system-monitor || plasma-systemmonitor || mate-system-monitor || ukui-system-monitor || deepin-system-monitor || pantheon-system-monitor"

local function formatSpeed(value)
    -- Exact V4 SystemStatService.formatSpeed semantics: decimal (1000-based)
    -- units, one decimal below 10, integer otherwise, and a one-letter unit
    -- fallback when the display would exceed five characters.
    local units = { "KB", "MB", "GB" }
    local speed = tonumber(value) or 0
    local scaled = speed / 1000
    local unitIndex = 1
    while scaled >= 1000 and unitIndex < #units do
        scaled /= 1000
        unitIndex += 1
    end
    local number = scaled < 10 and string.format("%.1f", scaled) or string.format("%.0f", scaled)
    local result = number .. units[unitIndex]
    if #result > 5 then
        result = number .. units[unitIndex]:sub(1, 1)
    end
    return result
end

local function render()
    local stats = noctalia.systemStats()
    local rx = 0
    local tx = 0
    if stats ~= nil and stats.net ~= nil then
        rx = stats.net.rxBytesPerSec or 0
        tx = stats.net.txBytesPerSec or 0
    end

    local function speedRow(glyph, value)
        -- V4 uses Style.marginXS=3 between its 13px glyph and label.
        return ui.row({ gap = 3, align = "center" }, {
            ui.glyph({ name = glyph, size = 13, color = "primary" }),
            ui.label({
                text = formatSpeed(value),
                color = "on_surface",
                fontFamily = "NotoMono Nerd Font Mono",
                maxLines = 1,
            }),
        })
    end

    local container = barWidget.isVertical() and ui.column or ui.row
    barWidget.render(container({ gap = 9, align = "center", paddingH = 1.5 }, {
        speedRow("download-speed", rx),
        speedRow("upload-speed", tx),
    }))
    barWidget.setTooltip(`Download {formatSpeed(rx)}/s  ·  Upload {formatSpeed(tx)}/s`)
end

noctalia.setUpdateInterval(3000)

function update()
    render()
end

function onClick()
    noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "control-center", "system" })
end

function onMiddleClick()
    noctalia.runAsync(externalMonitor)
end

render()
