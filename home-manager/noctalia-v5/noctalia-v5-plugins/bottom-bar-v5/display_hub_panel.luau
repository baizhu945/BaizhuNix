--!nonstrict
-- Unified accordion panel for output configuration and display mirroring.

noctalia.setUpdateInterval(30000)

local outputs = {}
local loading = false
local displayExpanded = false
local mirrorExpanded = false
local mirrorTarget = ""
local mirrorStatus = { mirrors = {}, count = 0 }
local ddcAvailable = noctalia.commandExists("ddcutil")

local stateRoot = noctalia.getenv("XDG_STATE_HOME")
if stateRoot == nil or stateRoot == "" then stateRoot = noctalia.expandPath("~/.local/state") end
local stateDir = stateRoot .. "/noctalia/bottom_bar"
local statePath = stateDir .. "/display-values.json"
local values = { brightness = {}, contrast = {} }

local function loadValues()
    local raw = noctalia.readFile(statePath)
    if raw == nil or raw == "" then return end
    local decoded = noctalia.json.decode(raw)
    if type(decoded) == "table" then
        values = decoded
        if type(values.brightness) ~= "table" then values.brightness = {} end
        if type(values.contrast) ~= "table" then values.contrast = {} end
    end
end

local function saveValues()
    noctalia.mkdirAll(stateDir)
    local encoded = noctalia.json.encode(values, true)
    if encoded ~= nil then noctalia.writeFile(statePath, encoded) end
end

local function outputValue(kind, name)
    local bucket = values[kind]
    local stored = type(bucket) == "table" and tonumber(bucket[name]) or nil
    return stored or 50
end

local function setOutputValue(kind, name, nextValue)
    values[kind][name] = math.max(0, math.min(100, tonumber(nextValue) or 50))
end

local function modeLabel(mode)
    local hz = (tonumber(mode.refresh_rate) or 0) / 1000
    return string.format("%dx%d @ %.2fHz", tonumber(mode.width) or 0, tonumber(mode.height) or 0, hz)
end

local function refreshOutputs()
    if loading then return end
    loading = true
    render()
    noctalia.runAsync({ "niri", "msg", "--json", "outputs" }, function(result)
        loading = false
        if result.exitCode ~= 0 then
            noctalia.notifyError("显示中心", noctalia.string.trim(result.stderr or "无法读取 Niri 输出"))
            render()
            return
        end
        local decoded = noctalia.json.decode(result.stdout or "")
        local nextOutputs = {}
        if type(decoded) == "table" then
            for name, info in pairs(decoded) do
                table.insert(nextOutputs, {
                    name = name,
                    model = info.model or name,
                    serial = info.serial or info.serial_number or "",
                    enabled = info.current_mode ~= nil,
                    current_mode = tonumber(info.current_mode) or 0,
                    scale = info.logical and tonumber(info.logical.scale) or 1,
                    modes = type(info.modes) == "table" and info.modes or {},
                })
            end
        end
        table.sort(nextOutputs, function(a, b) return a.name < b.name end)
        outputs = nextOutputs
        render()
    end)
end

local function activeOutputCount()
    local count = 0
    for _, output in ipairs(outputs) do
        if output.enabled then count += 1 end
    end
    return count
end

local function runNiri(args, title)
    local command = { "niri", "msg", "output" }
    for _, item in ipairs(args) do table.insert(command, tostring(item)) end
    noctalia.runAsync(command, function(result)
        if result.exitCode ~= 0 then
            noctalia.notifyError(title, noctalia.string.trim(result.stderr or "Niri 输出命令失败"))
        end
        refreshOutputs()
    end)
end

local function toggleOutput(output, enabled)
    if not enabled and activeOutputCount() <= 1 then
        noctalia.notifyError("显示管理", "不能关闭最后一个活动显示器")
        render()
        return
    end
    runNiri({ output.name, enabled and "on" or "off" }, "显示管理")
end

local function setScale(output, scale)
    local nextScale = math.max(0.5, math.min(3.0, scale))
    runNiri({ output.name, "scale", string.format("%.2f", nextScale) }, "显示缩放")
end

local function setMode(output, zeroBasedIndex)
    local mode = output.modes[zeroBasedIndex + 1]
    if mode == nil then return end
    local hz = (tonumber(mode.refresh_rate) or 0) / 1000
    local spec = string.format("%dx%d@%.3f", tonumber(mode.width) or 0, tonumber(mode.height) or 0, hz)
    runNiri({ output.name, "mode", spec }, "显示模式")
end

local function applyDdc(output, code, nextValue, title)
    if not ddcAvailable or output.name:match("^eDP") then return end
    local command = { "ddcutil", "setvcp", tostring(code), tostring(math.floor(nextValue + 0.5)) }
    if output.serial ~= "" then
        table.insert(command, "--sn")
        table.insert(command, output.serial)
    elseif output.model ~= "" then
        table.insert(command, "--model")
        table.insert(command, output.model)
    end
    table.insert(command, "--noverify")
    noctalia.runAsync(command, function(result)
        if result.exitCode ~= 0 then
            noctalia.notifyError(title, noctalia.string.trim(result.stderr or "ddcutil 执行失败"))
        end
    end)
end

local function monitorCard(output)
    local options = {}
    for _, mode in ipairs(output.modes) do table.insert(options, modeLabel(mode)) end
    local brightness = outputValue("brightness", output.name)
    local contrast = outputValue("contrast", output.name)
    local canDdc = ddcAvailable and not output.name:match("^eDP")

    return ui.column({ key = `display-{output.name}`, gap = 9, padding = 12, fill = "surface_variant/0.32", radius = 10, align = "stretch" }, {
        ui.row({ gap = 8, align = "center" }, {
            ui.glyph({ name = "device-desktop", size = 20, color = output.enabled and "primary" or "on_surface_variant" }),
            ui.column({ gap = 2, flexGrow = 1, align = "stretch" }, {
                ui.label({ text = output.model, fontWeight = "bold", maxLines = 1 }),
                ui.label({ text = output.name, color = "on_surface_variant", maxLines = 1 }),
            }),
            ui.toggle({ checked = output.enabled, onChange = function(value) toggleOutput(output, value == "true") end }),
        }),
        ui.row({ gap = 8, align = "center", visible = output.enabled }, {
            ui.label({ text = "模式", color = "on_surface_variant", width = 64 }),
            ui.select({ options = options, selectedIndex = output.current_mode, flexGrow = 1, controlSize = "sm", onChange = function(index) setMode(output, tonumber(index) or 0) end }),
        }),
        ui.row({ gap = 8, align = "center", visible = output.enabled }, {
            ui.label({ text = "缩放", color = "on_surface_variant", width = 64 }),
            ui.button({ glyph = "minus", controlSize = "sm", onClick = function() setScale(output, output.scale - 0.25) end }),
            ui.label({ text = string.format("%.2fx", output.scale), textAlign = "center", flexGrow = 1 }),
            ui.button({ glyph = "plus", controlSize = "sm", onClick = function() setScale(output, output.scale + 0.25) end }),
        }),
        ui.row({ gap = 8, align = "center", visible = output.enabled }, {
            ui.glyph({ name = "brightness", size = 16, color = "on_surface_variant" }),
            ui.label({ text = "亮度", color = "on_surface_variant", width = 54 }),
            ui.slider({ min = 0, max = 100, step = 1, value = brightness, flexGrow = 1, enabled = canDdc,
                onChange = function(nextValue) setOutputValue("brightness", output.name, nextValue) end,
                onDragEnd = function()
                    local current = outputValue("brightness", output.name)
                    saveValues()
                    applyDdc(output, 10, current, "显示器亮度")
                    render()
                end,
            }),
            ui.label({ text = `{math.floor(brightness + 0.5)}%`, width = 42, textAlign = "end" }),
        }),
        ui.row({ gap = 8, align = "center", visible = output.enabled }, {
            ui.glyph({ name = "contrast", size = 16, color = "on_surface_variant" }),
            ui.label({ text = "对比度", color = "on_surface_variant", width = 54 }),
            ui.slider({ min = 0, max = 100, step = 1, value = contrast, flexGrow = 1, enabled = canDdc,
                onChange = function(nextValue) setOutputValue("contrast", output.name, nextValue) end,
                onDragEnd = function()
                    local current = outputValue("contrast", output.name)
                    saveValues()
                    applyDdc(output, 12, current, "显示器对比度")
                    render()
                end,
            }),
            ui.label({ text = `{math.floor(contrast + 0.5)}%`, width = 42, textAlign = "end" }),
        }),
    })
end

local function mirrorCandidates()
    local result = {}
    local targetDisplays = {}
    local targetAlreadySource = false
    local mirrors = type(mirrorStatus.mirrors) == "table" and mirrorStatus.mirrors or {}
    for _, mirror in ipairs(mirrors) do
        if mirror.target ~= nil then targetDisplays[mirror.target] = true end
        if mirror.source == mirrorTarget then targetAlreadySource = true end
    end
    if targetAlreadySource then return result end
    for _, output in ipairs(outputs) do
        if output.enabled and output.name ~= mirrorTarget and not targetDisplays[output.name] then
            table.insert(result, output.name)
        end
    end
    return result
end

local function startMirror(source)
    if mirrorTarget == "" then
        noctalia.notifyError("复制显示", "无法确定目标显示器")
        return
    end
    noctalia.state.set("mirror-command", { action = "start", source = source, target = mirrorTarget })
    panel.close()
end

local function stopMirror(pid)
    noctalia.state.set("mirror-command", { action = "stop", pid = pid })
end

local function stopAllMirrors()
    noctalia.state.set("mirror-command", { action = "stop-all" })
end

local function displaySectionNodes()
    local nodes = {}
    if #outputs == 0 then
        table.insert(nodes, ui.label({ text = loading and "正在扫描显示器…" or "未检测到显示器", color = "on_surface_variant", textAlign = "center" }))
    else
        for _, output in ipairs(outputs) do table.insert(nodes, monitorCard(output)) end
    end
    table.insert(nodes, ui.label({
        text = ddcAvailable and "外接显示器的亮度与对比度通过 DDC/CI 调整。" or "未安装 ddcutil，无法调整外接显示器亮度与对比度。",
        color = ddcAvailable and "on_surface_variant" or "warning",
        fontSize = 12,
    }))
    return nodes
end

local function mirrorSectionNodes()
    local nodes = {
        ui.label({ text = mirrorTarget ~= "" and `目标显示器：{mirrorTarget}` or "尚未确定目标显示器", color = "on_surface_variant" }),
    }
    local mirrors = type(mirrorStatus.mirrors) == "table" and mirrorStatus.mirrors or {}
    if #mirrors > 0 then
        table.insert(nodes, ui.label({ text = "活动镜像", fontWeight = "bold" }))
        for _, mirror in ipairs(mirrors) do
            table.insert(nodes, ui.row({ key = `mirror-{mirror.pid}`, gap = 8, align = "center", padding = 10, fill = "primary/0.12", radius = 9 }, {
                ui.glyph({ name = "screen-share", size = 18, color = "primary" }),
                ui.column({ gap = 2, flexGrow = 1, align = "stretch" }, {
                    ui.label({ text = `{mirror.source} → {mirror.target}`, fontWeight = "bold", maxLines = 1 }),
                    ui.label({ text = `PID {mirror.pid}`, color = "on_surface_variant", fontSize = 12 }),
                }),
                ui.button({ text = "停止", glyph = "player-stop", variant = "destructive", controlSize = "sm", onClick = function() stopMirror(mirror.pid) end }),
            }))
        end
        table.insert(nodes, ui.button({ text = "停止全部镜像", glyph = "player-stop", variant = "ghost", onClick = stopAllMirrors }))
    end

    table.insert(nodes, ui.label({ text = "选择要复制的来源显示器", fontWeight = "bold" }))
    local candidates = mirrorCandidates()
    if #candidates == 0 then
        table.insert(nodes, ui.label({ text = loading and "正在读取显示器…" or "当前没有可用于复制的显示器。", color = "on_surface_variant", textAlign = "center" }))
    else
        for _, outputName in ipairs(candidates) do
            table.insert(nodes, ui.button({ key = `source-{outputName}`, text = outputName, glyph = "device-desktop", variant = "outline", contentAlign = "start", onClick = function() startMirror(outputName) end }))
        end
    end
    table.insert(nodes, ui.label({ text = "所选来源将通过 wl-mirror 全屏显示在目标显示器上。", color = "on_surface_variant", fontSize = 12 }))
    return nodes
end

local function toggleDisplaySection()
    displayExpanded = not displayExpanded
    render()
end

local function toggleMirrorSection()
    mirrorExpanded = not mirrorExpanded
    render()
end

function render()
    local mirrorCount = tonumber(mirrorStatus.count) or 0
    local body = {
        ui.button({
            glyph = "device-desktop",
            text = displayExpanded and "显示管理  ▲" or "显示管理  ▼",
            variant = displayExpanded and "secondary" or "outline",
            contentAlign = "start",
            controlSize = "lg",
            onClick = toggleDisplaySection,
        }),
    }
    if displayExpanded then
        for _, node in ipairs(displaySectionNodes()) do table.insert(body, node) end
    end

    table.insert(body, ui.button({
        glyph = "screen-share",
        text = mirrorExpanded and `复制显示 · {mirrorCount} 个活动镜像  ▲` or `复制显示 · {mirrorCount} 个活动镜像  ▼`,
        variant = mirrorExpanded and "secondary" or (mirrorCount > 0 and "primary" or "outline"),
        contentAlign = "start",
        controlSize = "lg",
        onClick = toggleMirrorSection,
    }))
    if mirrorExpanded then
        for _, node in ipairs(mirrorSectionNodes()) do table.insert(body, node) end
    end

    panel.render(ui.column({ gap = 12, flexGrow = 1, align = "stretch" }, {
        ui.row({ gap = 8, align = "center" }, {
            ui.glyph({ name = "device-desktop", size = 22, color = "primary" }),
            ui.column({ gap = 2, flexGrow = 1, align = "stretch" }, {
                ui.label({ text = "显示中心", fontSize = 17, fontWeight = "bold" }),
                ui.label({ text = loading and "正在扫描显示器…" or `{activeOutputCount()} 个活动显示器 · {mirrorCount} 个活动镜像`, color = "on_surface_variant" }),
            }),
            ui.button({ glyph = "refresh", enabled = not loading, onClick = refreshOutputs }),
            ui.button({ glyph = "x", onClick = "onClose" }),
        }),
        ui.scroll({ flexGrow = 1, gap = 10, align = "stretch", fill = "surface_variant/0.16", radius = 10, padding = 8 }, body),
    }))
end

function onOpen(_context)
    local requested = noctalia.state.get("display-hub-section")
    if requested == "display" then
        displayExpanded = true
        mirrorExpanded = false
    elseif requested == "mirror" then
        displayExpanded = false
        mirrorExpanded = true
    end
    noctalia.state.set("display-hub-section", "")
    local rememberedTarget = noctalia.state.get("mirror-target")
    mirrorTarget = type(rememberedTarget) == "string" and rememberedTarget or ""
    if mirrorTarget == "" then mirrorTarget = noctalia.focusedOutputName() or "" end
    refreshOutputs()
end

function update()
    refreshOutputs()
end

function onClose()
    panel.close()
end

noctalia.state.watch("mirror-status", function(value)
    if type(value) == "table" then mirrorStatus = value end
    render()
end)

loadValues()
local initial = noctalia.state.get("mirror-status")
if type(initial) == "table" then mirrorStatus = initial end
render()
