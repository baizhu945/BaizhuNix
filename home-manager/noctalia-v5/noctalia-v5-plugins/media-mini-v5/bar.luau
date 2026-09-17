--!nonstrict
-- Faithful V5 port of V4 Modules/Bar/Widgets/MediaMini.qml.
-- The spectrum is layered behind the complete content lane; the album image is
-- inset inside a two-pixel track/progress ring instead of using V5's flat fill.

local contentWidth = math.max(80, math.floor(tonumber(noctalia.getConfig("content_width")) or 135))
-- V4's spectrumMirrored=false selects 64 PwAudioSpectrum bands.
local spectrumBands = math.max(8, math.floor(tonumber(noctalia.getConfig("audio_spectrum_bands")) or 64))
local contentHeight = 25
local artSize = 19
local progressWidth = 2
local values = {}
local media = nil
local artUrl = ""
local artPath = ""
local artGeneration = 0
local dataDir = noctalia.pluginDataDir() or "/tmp"

local function parseCsv(csv)
    local result = {}
    for value in (csv or ""):gmatch("[^,]+") do
        table.insert(result, tonumber(value) or 0)
    end
    return result
end

local function displayTitle(info)
    if type(info) ~= "table" then return "" end
    local title = info.title or ""
    local artist = info.artist or ""
    if title ~= "" and artist ~= "" then return `{title} - {artist}` end
    if title ~= "" then return title end
    if artist ~= "" then return artist end
    return info.identity or ""
end

local function projectedProgress(info)
    if type(info) ~= "table" then return 0 end
    local length = tonumber(info.lengthUs) or 0
    if length <= 0 then return 0 end
    local position = tonumber(info.positionUs) or 0
    if info.playbackStatus == "Playing" then
        local sampledAt = tonumber(info.sampledAtMs) or noctalia.nowMs()
        position += math.max(0, noctalia.nowMs() - sampledAt) * 1000
    end
    return math.clamp(position / length, 0, 1)
end

local function requestArtwork(url)
    if url == artUrl then return end
    artUrl = url or ""
    artGeneration += 1
    local generation = artGeneration
    artPath = ""

    if artUrl == "" then return end
    if artUrl:sub(1, 7) == "file://" then
        artPath = noctalia.string.urlDecode(artUrl:sub(8))
        return
    end
    if artUrl:sub(1, 1) == "/" or artUrl:sub(1, 2) == "~/" then
        artPath = noctalia.expandPath(artUrl)
        return
    end
    if artUrl:match("^https?://") == nil then return end

    local destination = `{dataDir}/artwork-{generation}.img`
    noctalia.download(artUrl, destination, function(ok)
        if generation ~= artGeneration then
            if ok then noctalia.removeFile(destination) end
            return
        end
        if ok then
            artPath = destination
            render()
        end
    end)
end

local function artworkNode(progress)
    local center
    if artPath ~= "" and noctalia.fileExists(artPath) then
        center = ui.row({ width = artSize, height = artSize, justify = "center", align = "center" }, {
            ui.image({
                key = `art-{artGeneration}`,
                path = artPath,
                width = artSize - progressWidth * 4,
                height = artSize - progressWidth * 4,
                radius = (artSize - progressWidth * 4) / 2,
                fit = "cover",
            }),
        })
    else
        center = ui.row({ width = artSize, height = artSize, justify = "center", align = "center" }, {
            ui.glyph({ name = "disc", size = artSize - progressWidth * 4, color = "on_surface_variant" }),
        })
    end

    return ui.row({ width = artSize, height = artSize, gap = -artSize, align = "center" }, {
        ui.ring({ key = "track", size = artSize, thickness = progressWidth, progress = 1, color = "on_surface/0.4" }),
        ui.ring({ key = "progress", size = artSize, thickness = progressWidth, progress = progress, color = "primary" }),
        center,
    })
end

function render()
    media = noctalia.mediaInfo()
    local hasPlayer = type(media) == "table" and (media.busName or "") ~= ""
    barWidget.setVisible(hasPlayer)
    if not hasPlayer then
        barWidget.clearTooltip()
        return
    end

    requestArtwork(media.artUrl or "")
    local title = displayTitle(media)
    local progress = projectedProgress(media)
    local spectrumVisible = noctalia.getConfig("audio_spectrum") == true and media.playbackStatus == "Playing" and #values > 0
    local graphValues = spectrumVisible and values or { 0, 0 }

    local background = ui.row({
        key = "background-wave-wrap",
        width = contentWidth,
        height = contentHeight,
        justify = "center",
        align = "center",
    }, {
        ui.graph({
            key = "background-wave",
            width = contentWidth - 6,
            height = contentHeight - 6,
            values = graphValues,
            color = "primary",
            lineWidth = 0,
            fillOpacity = 0,
            opacity = 0.4,
            wave = true,
        }),
    })

    local foreground = ui.row({
        key = "foreground",
        width = contentWidth,
        height = contentHeight,
        gap = 6,
        align = "center",
    }, {
        artworkNode(progress),
        ui.label({
            key = "title",
            text = title,
            color = media.playbackStatus == "Playing" and "primary" or "on_surface_variant",
            maxWidth = contentWidth - artSize - 6,
            maxLines = 1,
        }),
    })

    -- Negative gap intentionally overlays the second fixed-width lane on the
    -- first. Flex supports signed gaps; this reproduces V4's z=0 visualizer and
    -- z=1 artwork/title without adding a separate widget to the right.
    barWidget.render(ui.row({ width = contentWidth, height = contentHeight, gap = -contentWidth, align = "center" }, {
        background,
        foreground,
    }))
    barWidget.setTooltip(title)
end

function update()
    render()
end

function onAudioSpectrum(valuesCsv, _stateCsv)
    values = parseCsv(valuesCsv)
    while #values > spectrumBands do table.remove(values) end
    render()
end

function onClick()
    noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "control-center", "media" })
end

function onRightClick()
    noctalia.togglePanel("baizhu/media_mini:menu")
end

noctalia.setUpdateInterval(250)
render()
