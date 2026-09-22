--!nonstrict
-- Noctalia-native color modal with custom HSV controls, Material colors,
-- recent picks, opacity, eyedropper, and copy fields.

local color = require("./color_common.luau")
local status = { busy = false, last = "", history = {} }
local currentHex = "#EFEDF1"
local hue = 270
local saturation = 2
local value = 95
local opacity = 100

local materialRows = {
    { "#F44336", "#E91E63", "#9C27B0", "#673AB7", "#3F51B5", "#2196F3", "#03A9F4", "#00BCD4", "#009688", "#4CAF50", "#8BC34A", "#CDDC39", "#FFEB3B", "#FFC107", "#FF9800", "#FF5722", "#D32F2F" },
    { "#C2185B", "#7B1FA2", "#512DA8", "#303F9F", "#1976D2", "#0288D1", "#0097A7", "#00796B", "#388E3C", "#689F38", "#AFB42B", "#FBC02D", "#FFA000", "#F57C00", "#E64A19", "#C62828", "#AD1457" },
    { "#6A1B9A", "#4527A0", "#283593", "#1565C0", "#0277BD", "#00838F", "#00695C", "#2E7D32", "#558B2F", "#9E9D24", "#F9A825", "#FF8F00", "#EF6C00", "#D84315", "#FAFAFA", "#BDBDBD", "#212121" },
}

local function syncFromHex(valueToUse)
    local formats = color.formats(valueToUse)
    if formats == nil then return false end
    currentHex = formats.hex
    hue = formats.hue
    saturation = formats.saturation
    value = formats.value
    return true
end

local function syncFromHsv()
    currentHex = color.fromHsv(hue, saturation, value)
end

local function rememberCurrent()
    noctalia.state.set("picker-command", { action = "remember", color = currentHex })
end

local function copy(label, copiedValue)
    if copiedValue == nil or copiedValue == "" then return end
    noctalia.copyToClipboard(copiedValue, "text/plain")
    rememberCurrent()
    noctalia.notify("取色器", `{label} 已复制：{copiedValue}`)
end

local function pickFromScreen()
    -- Close the modal first so neither the panel nor its dimmed backdrop is
    -- present in hyprpicker's frozen frame.  Start the picker only after the
    -- normal panel close animation has completed; the service reopens this
    -- same panel after a pick or cancellation.
    panel.close()
    noctalia.runAsync({
        "bash",
        "-lc",
        "sleep 0.35; noctalia msg plugin baizhu/bottom_bar:service all pick-modal",
    })
end

local function selectColor(selected)
    if syncFromHex(selected) then render() end
end

local function applyHex(text)
    if syncFromHex(text) then
        render()
    else
        noctalia.notifyError("取色器", "请输入 #RRGGBB 格式的颜色")
    end
end

local function materialPalette()
    local rows = {}
    for rowIndex, colors in ipairs(materialRows) do
        local swatches = {}
        for columnIndex, swatch in ipairs(colors) do
            table.insert(swatches, ui.box({
                key = `material-{rowIndex}-{columnIndex}`,
                fill = swatch,
                width = 34,
                height = 34,
                radius = 4,
                border = currentHex == swatch and "primary" or "outline",
                borderWidth = currentHex == swatch and 3 or 1,
                onClick = function() selectColor(swatch) end,
            }))
        end
        table.insert(rows, ui.row({ gap = 5, align = "center" }, swatches))
    end
    return ui.column({ gap = 5, align = "start" }, rows)
end

local function recentPalette()
    local swatches = {}
    if type(status.history) == "table" then
        for index, swatch in ipairs(status.history) do
            if index > 5 then break end
            table.insert(swatches, ui.box({
                key = `recent-{index}-{swatch}`,
                fill = swatch,
                width = 48,
                height = 42,
                radius = 6,
                border = currentHex == swatch and "primary" or "outline",
                borderWidth = currentHex == swatch and 3 or 1,
                onClick = function() selectColor(swatch) end,
            }))
        end
    end
    while #swatches < 5 do
        table.insert(swatches, ui.box({ fill = "surface_variant/0.45", width = 48, height = 42, radius = 6, border = "outline", borderWidth = 1 }))
    end
    return ui.row({ gap = 7, align = "center" }, swatches)
end

local function sliderRow(label, minimum, maximum, sliderValue, onChange)
    return ui.row({ gap = 9, align = "center" }, {
        ui.label({ text = label, width = 34, color = "on_surface_variant" }),
        ui.slider({ min = minimum, max = maximum, step = 1, value = sliderValue, flexGrow = 1, onChange = onChange }),
        ui.label({ text = tostring(math.floor(sliderValue + 0.5)), width = 42, textAlign = "end" }),
    })
end

local function copyField(label, fieldValue, onSubmit)
    local controls = {
        ui.label({ text = label, color = "on_surface_variant" }),
    }
    if onSubmit ~= nil then
        table.insert(controls, ui.input({ key = `field-{label}-{fieldValue}`, value = fieldValue, onSubmit = onSubmit, controlSize = "sm" }))
    else
        table.insert(controls, ui.button({ text = fieldValue, variant = "outline", contentAlign = "start", controlSize = "sm", onClick = function() copy(label, fieldValue) end }))
    end
    table.insert(controls, ui.button({ glyph = "copy", tooltip = `复制 {label}`, variant = "ghost", controlSize = "sm", onClick = function() copy(label, fieldValue) end }))
    return ui.column({ gap = 5, flexGrow = 1, align = "stretch" }, controls)
end

function render()
    local formats = color.formats(currentHex) or color.formats("#EFEDF1")
    local preview = color.withAlpha(currentHex, opacity)

    panel.render(ui.column({ gap = 12, flexGrow = 1, align = "stretch" }, {
        ui.row({ gap = 8, align = "center" }, {
            ui.column({ gap = 2, flexGrow = 1, align = "stretch" }, {
                ui.label({ text = "选择颜色", fontSize = 18, fontWeight = "bold" }),
                ui.label({ text = "从调色板中选择颜色，或使用屏幕吸管", color = "on_surface_variant" }),
            }),
            ui.button({ glyph = "color-picker", tooltip = "从屏幕取色", enabled = not status.busy, onClick = pickFromScreen }),
            ui.button({ glyph = "x", onClick = "onClose" }),
        }),

        ui.row({ gap = 14, align = "stretch", padding = 10, fill = "surface_variant/0.22", radius = 10 }, {
            ui.column({ gap = 8, width = 175, align = "stretch" }, {
                ui.box({ fill = preview, width = 175, height = 132, radius = 10, border = "outline", borderWidth = 1 }),
                ui.label({ text = currentHex, fontSize = 18, fontWeight = "bold", color = "primary", textAlign = "center" }),
            }),
            ui.column({ gap = 7, flexGrow = 1, align = "stretch" }, {
                sliderRow("色相", 0, 359, hue, function(nextValue) hue = tonumber(nextValue) or hue; syncFromHsv(); render() end),
                sliderRow("饱和", 0, 100, saturation, function(nextValue) saturation = tonumber(nextValue) or saturation; syncFromHsv(); render() end),
                sliderRow("明度", 0, 100, value, function(nextValue) value = tonumber(nextValue) or value; syncFromHsv(); render() end),
                sliderRow("透明", 0, 100, opacity, function(nextValue) opacity = tonumber(nextValue) or opacity; render() end),
            }),
        }),

        ui.label({ text = "Material 配色", fontWeight = "bold" }),
        materialPalette(),

        ui.row({ gap = 18, align = "start" }, {
            ui.column({ gap = 7, align = "stretch" }, {
                ui.label({ text = "最近拾取的颜色", fontWeight = "bold" }),
                recentPalette(),
            }),
            ui.spacer({ flexGrow = 1 }),
            ui.column({ gap = 7, width = 165, align = "stretch" }, {
                ui.label({ text = "不透明度", fontWeight = "bold" }),
                ui.row({ gap = 8, align = "center" }, {
                    ui.progress({ progress = opacity / 100, fill = "primary", track = "surface_variant", flexGrow = 1, height = 8 }),
                    ui.label({ text = `{math.floor(opacity + 0.5)}%`, width = 44, textAlign = "end" }),
                }),
            }),
        }),

        ui.row({ gap = 12, align = "stretch" }, {
            copyField("十六进制", formats.hex, applyHex),
            copyField("RGB", formats.rgb, nil),
            copyField("色相、饱和度、明度", formats.hsl, nil),
        }),
    }))
end

function onOpen(_context)
    if type(status.last) == "string" and status.last ~= "" then syncFromHex(status.last) end
    render()
end

function onClose()
    panel.close()
end

noctalia.state.watch("picker-status", function(nextStatus)
    if type(nextStatus) == "table" then
        local previousLast = status.last
        status = nextStatus
        if status.last ~= nil and status.last ~= "" and status.last ~= previousLast then syncFromHex(status.last) end
    end
    render()
end)

local initial = noctalia.state.get("picker-status")
if type(initial) == "table" then status = initial end
if type(status.last) == "string" and status.last ~= "" then syncFromHex(status.last) end
render()
