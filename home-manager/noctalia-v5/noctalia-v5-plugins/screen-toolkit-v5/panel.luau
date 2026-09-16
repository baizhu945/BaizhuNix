--!nonstrict
local function run(command, title)
    if noctalia.runAsync(command) then
        panel.close()
        noctalia.notify("Screen Toolkit", title)
    else
        noctalia.notifyError("Screen Toolkit", `Unable to start {title}`)
    end
end

function render()
    panel.render(ui.column({ gap = 12, flexGrow = 1, align = "stretch" }, {
        ui.row({ gap = 8, align = "center" }, {
            ui.glyph({ name = "screenshot", size = 22, color = "primary" }),
            ui.label({ text = "Screen Toolkit", fontSize = 17, fontWeight = "bold", flexGrow = 1 }),
            ui.button({ glyph = "close", onClick = "onClose" }),
        }),
        ui.button({ glyph = "pencil", text = "Full-screen annotation", variant = "outline", onClick = function()
            run("chameleos --stroke-width 4 >/dev/null 2>&1 & sleep 0.1; chamel toggle", "Annotation mode")
        end }),
        ui.button({ glyph = "screenshot", text = "Region screenshot", variant = "outline", onClick = function()
            run("mkdir -p \"$HOME/Pictures/Screenshots\"; grim -g \"$(slurp)\" -c \"$HOME/Pictures/Screenshots/$(date +%s_grim.png)\"", "Region screenshot")
        end }),
        ui.button({ glyph = "pin", text = "Pin a screenshot", variant = "outline", onClick = function()
            run("mkdir -p \"$HOME/Pictures/Screenshots\"; file=$HOME/Pictures/Screenshots/noctalia-pin-$(date +%s).png; grim -g \"$(slurp)\" \"$file\" && mpv --ontop --force-window=yes --keep-open=yes \"$file\"", "Pinned screenshot")
        end }),
        ui.button({ glyph = "scan", text = "OCR selection", variant = "outline", onClick = function()
            run({ "deepseek-ocr" }, "OCR")
        end }),
        ui.button({ glyph = "close", text = "Close annotation", variant = "ghost", onClick = function()
            run({ "chamel", "exit" }, "Annotation closed")
        end }),
    }))
end

function onOpen(_context)
    render()
end

function onClose()
    panel.close()
end

render()
