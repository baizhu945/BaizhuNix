--!nonstrict
-- V4 MediaMini-style secondary-click menu.

local media = nil

local function run(action)
    noctalia.runAsync({ "noctalia", "msg", "media", action }, function(result)
        if result.exitCode ~= 0 then
            noctalia.notifyError("Media", noctalia.string.trim(result.stderr or "Media action failed"))
        end
    end)
    panel.close()
end

function render()
    media = noctalia.mediaInfo()
    local hasPlayer = type(media) == "table" and (media.busName or "") ~= ""
    local playing = hasPlayer and media.playbackStatus == "Playing"
    local title = hasPlayer and ((media.title or "") ~= "" and media.title or media.identity) or "没有媒体播放器"

    panel.render(ui.column({ gap = 8, padding = 10, align = "stretch" }, {
        ui.row({ gap = 8, align = "center" }, {
            ui.glyph({ name = "music", size = 20, color = "primary" }),
            ui.label({ text = title, fontWeight = "bold", flexGrow = 1, maxLines = 1 }),
            ui.button({ glyph = "x", variant = "ghost", onClick = function() panel.close() end }),
        }),
        ui.button({ glyph = playing and "player-pause" or "player-play", text = playing and "暂停" or "播放", enabled = hasPlayer, contentAlign = "start", onClick = function() run("toggle") end }),
        ui.button({ glyph = "player-skip-back", text = "上一首", enabled = hasPlayer and media.canGoPrevious == true, contentAlign = "start", onClick = function() run("previous") end }),
        ui.button({ glyph = "player-skip-forward", text = "下一首", enabled = hasPlayer and media.canGoNext == true, contentAlign = "start", onClick = function() run("next") end }),
        ui.button({ glyph = "settings", text = "小组件设置", variant = "ghost", contentAlign = "start", onClick = function()
            panel.close()
            noctalia.runAsync({ "noctalia", "msg", "settings-open-widget", "main", "media-mini" })
        end }),
    }))
end

function onOpen(_context)
    render()
end

noctalia.setUpdateInterval(1000)
function update()
    render()
end

render()
