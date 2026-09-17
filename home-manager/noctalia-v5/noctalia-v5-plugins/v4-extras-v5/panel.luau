--!nonstrict
local function run(command, title)
    if noctalia.runAsync(command) then
        noctalia.notify("V4 Extras", title)
    else
        noctalia.notifyError("V4 Extras", `Unable to run {title}`)
    end
end

function render()
    panel.render(ui.column({ gap = 12, flexGrow = 1, align = "stretch" }, {
        ui.row({ gap = 8, align = "center" }, {
            ui.glyph({ name = "dots", size = 22, color = "primary" }),
            ui.label({ text = "V4 Extras", fontSize = 17, fontWeight = "bold", flexGrow = 1 }),
            ui.button({ glyph = "x", onClick = "onClose" }),
        }),
        ui.button({ glyph = "archive", text = "Deep Clean", variant = "outline", onClick = function()
            run({ "nix-clean" }, "Deep Clean")
        end }),
        ui.button({ glyph = "moon", text = "Toggle dark mode", variant = "outline", onClick = function()
            run({ "noctalia", "msg", "theme-mode-toggle" }, "Toggle dark mode")
        end }),
        ui.button({ glyph = "device-desktop", text = "GPU mode…", variant = "outline", onClick = function()
            noctalia.togglePanel("baizhu/supergfxctl:panel")
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
