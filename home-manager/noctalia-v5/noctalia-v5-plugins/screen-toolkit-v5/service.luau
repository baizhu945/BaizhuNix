--!nonstrict
-- The v5 shell cannot host the old QML overlays, so this service keeps the
-- useful IPC entry points and delegates to the installed Wayland tools.

local function detached(command, title)
    if noctalia.runAsync(command) then
        noctalia.notify("Screen Toolkit", title)
    else
        noctalia.notifyError("Screen Toolkit", `Unable to start {title}`)
    end
end

function onIpc(event, payload)
    if event == "toggle" then
        noctalia.togglePanel("baizhu/screen_toolkit:panel")
    elseif event == "annotate" or event == "annotateFullscreen" then
        detached("chameleos --stroke-width 4 >/dev/null 2>&1 & sleep 0.1; chamel toggle", "Annotation mode")
    elseif event == "exit" or event == "recordStop" then
        detached("chamel exit", "Annotation closed")
    elseif event == "ocr" then
        detached("deepseek-ocr", "OCR")
    elseif event == "pin" then
        detached("file=$HOME/Pictures/Screenshots/noctalia-pin-$(date +%s).png; grim -g \"$(slurp)\" \"$file\" && mpv --ontop --force-window=yes --keep-open=yes \"$file\"", "Pinned screenshot")
    elseif event == "screenshot" then
        detached("grim -g \"$(slurp)\" -c \"$HOME/Pictures/Screenshots/$(date +%s_grim.png)\"", "Region screenshot")
    else
        noctalia.notifyError("Screen Toolkit", `Unknown action: {event}`)
    end
end

noctalia.setUpdateInterval(60000)
function update()
end
