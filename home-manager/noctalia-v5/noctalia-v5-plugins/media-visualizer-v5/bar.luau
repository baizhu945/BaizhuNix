--!nonstrict
-- Compact wave replacement for v4 MediaMini.showVisualizer.

local visible = false
local values = {}
local frame = 0
local spectrumEnabled = noctalia.getConfig("audio_spectrum") == true
local spectrumBands = math.max(4, math.floor(tonumber(noctalia.getConfig("audio_spectrum_bands")) or 32))

local function parseCsv(csv)
    local result = {}
    for value in csv:gmatch("[^,]+") do
        table.insert(result, tonumber(value) or 0)
    end
    return result
end

local function render()
    if not visible then
        barWidget.setVisible(false)
        return
    end
    barWidget.setVisible(true)
    barWidget.render(ui.graph({
        width = 48,
        height = 22,
        values = values,
        color = "primary",
        color2 = "secondary",
        lineWidth = 1.5,
        fillOpacity = 0.08,
    }))
    barWidget.setTooltip("Audio visualizer")
end

function update()
    render()
end

function onAudioSpectrum(valuesCsv, stateCsv)
    local state = parseCsv(stateCsv)
    local mprisPlaying = (state[2] or 0) == 1
    visible = spectrumEnabled and mprisPlaying
    if visible then
        values = parseCsv(valuesCsv)
        while #values > spectrumBands do
            table.remove(values)
        end
        frame += 1
        if #values == 0 then
            visible = false
        end
    else
        values = {}
    end
    render()
end
