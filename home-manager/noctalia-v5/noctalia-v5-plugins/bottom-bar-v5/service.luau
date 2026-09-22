--!nonstrict
-- Shared backend for the secondary Noctalia bottom bar.

noctalia.setUpdateInterval(1000)

local color = require("./color_common.luau")
local pluginDir = noctalia.pluginDir() or ""
local powerScript = pluginDir .. "/power-info.sh"
local stateRoot = noctalia.getenv("XDG_STATE_HOME")
if stateRoot == nil or stateRoot == "" then stateRoot = noctalia.expandPath("~/.local/state") end
local pickerStateDir = stateRoot .. "/noctalia/bottom_bar"
local pickerStatePath = pickerStateDir .. "/colors.json"
local powerPending = false
local pickerPending = false
local profilePending = false
local mirrorCheckPending = false
local tick = 0

local powerStatus = {
    available = false,
    watts = "N/A",
    watts_value = 0,
    capacity = 0,
    status = "Unavailable",
    energy_now = 0,
    energy_full = 0,
    time_seconds = 0,
    profile = "unknown",
}
local pickerStatus = { busy = false, last = "", history = {} }
local mirrors = {}

local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", [["'"']]) .. "'"
end

local function publishPower()
    noctalia.state.set("power-status", powerStatus)
end

local function publishPicker()
    noctalia.state.set("picker-status", pickerStatus)
end

local function publishMirrors()
    noctalia.state.set("mirror-status", { mirrors = mirrors, count = #mirrors })
end

local function refreshPower()
    if powerPending or pluginDir == "" then return end
    powerPending = true
    noctalia.runAsync({ "bash", powerScript }, function(result)
        powerPending = false
        if result.exitCode ~= 0 then
            powerStatus.available = false
            powerStatus.watts = "N/A"
            publishPower()
            return
        end

        local decoded = noctalia.json.decode(result.stdout or "")
        if type(decoded) == "table" then
            decoded.profile = powerStatus.profile
            powerStatus = decoded
        end
        publishPower()
    end)
end

local function refreshProfile()
    if profilePending then return end
    profilePending = true
    noctalia.runAsync({ "powerprofilesctl", "get" }, function(result)
        profilePending = false
        if result.exitCode == 0 then
            powerStatus.profile = noctalia.string.trim(result.stdout or "")
            publishPower()
        end
    end)
end

local function savePickerState()
    noctalia.mkdirAll(pickerStateDir)
    local encoded = noctalia.json.encode({ last = pickerStatus.last, history = pickerStatus.history }, true)
    if encoded ~= nil then noctalia.writeFile(pickerStatePath, encoded) end
end

local function loadPickerState()
    local raw = noctalia.readFile(pickerStatePath)
    if raw == nil or raw == "" then return end
    local decoded = noctalia.json.decode(raw)
    if type(decoded) ~= "table" then return end
    local last = color.normalize(decoded.last)
    pickerStatus.last = last or ""
    pickerStatus.history = {}
    if type(decoded.history) == "table" then
        for _, value in ipairs(decoded.history) do
            local normalized = color.normalize(value)
            if normalized ~= nil and #pickerStatus.history < 8 then
                table.insert(pickerStatus.history, normalized)
            end
        end
    end
end

local function rememberColor(value)
    local normalized = color.normalize(value)
    if normalized == nil then return end
    local history = { normalized }
    for _, previous in ipairs(pickerStatus.history) do
        if previous ~= normalized and #history < 8 then table.insert(history, previous) end
    end
    pickerStatus.last = normalized
    pickerStatus.history = history
    savePickerState()
end

local function pickColor(reopenPanel, copyResult)
    if pickerPending then return end
    if not noctalia.commandExists("hyprpicker") then
        noctalia.notifyError("Color Picker", "hyprpicker is not installed")
        return
    end
    pickerPending = true
    pickerStatus.busy = true
    publishPicker()
    noctalia.runAsync({ "hyprpicker", "--format=hex", "--lowercase-hex", "--no-fancy" }, function(result)
        pickerPending = false
        pickerStatus.busy = false
        if result.exitCode == 0 then
            local selected = color.normalize(result.stdout or "")
            if selected ~= nil then
                rememberColor(selected)
                if copyResult then
                    noctalia.copyToClipboard(selected, "text/plain")
                    noctalia.notify("Color Picker", `{selected} copied to the clipboard`)
                end
            end
        end
        publishPicker()
        if reopenPanel then
            noctalia.runAsync({ "noctalia", "msg", "panel-open", "baizhu/bottom_bar:color-picker-panel" })
        end
    end)
end

local function clearPickerHistory()
    pickerStatus.last = ""
    pickerStatus.history = {}
    savePickerState()
    publishPicker()
end

local function removeMirrorByPid(pid)
    local nextMirrors = {}
    for _, mirror in ipairs(mirrors) do
        if tostring(mirror.pid) ~= tostring(pid) then
            table.insert(nextMirrors, mirror)
        end
    end
    mirrors = nextMirrors
    publishMirrors()
end

local function verifyMirrors()
    if mirrorCheckPending or #mirrors == 0 then return end
    mirrorCheckPending = true
    local checks = {}
    for _, mirror in ipairs(mirrors) do
        table.insert(checks, `kill -0 {shellQuote(mirror.pid)} 2>/dev/null && printf '%s\\n' {shellQuote(mirror.pid)} || true`)
    end
    noctalia.runAsync({ "bash", "-lc", table.concat(checks, "; ") }, function(result)
        mirrorCheckPending = false
        local alive = {}
        for pid in (result.stdout or ""):gmatch("[^\r\n]+") do
            alive[noctalia.string.trim(pid)] = true
        end
        local nextMirrors = {}
        for _, mirror in ipairs(mirrors) do
            if alive[tostring(mirror.pid)] then
                table.insert(nextMirrors, mirror)
            end
        end
        if #nextMirrors ~= #mirrors then
            mirrors = nextMirrors
            publishMirrors()
        end
    end)
end

local function startMirror(source, target)
    if type(source) ~= "string" or source == "" or type(target) ~= "string" or target == "" then
        noctalia.notifyError("Display Mirror", "Missing source or target display")
        return
    end
    if source == target then
        noctalia.notifyError("Display Mirror", "A display cannot mirror itself")
        return
    end
    if not noctalia.commandExists("wl-mirror") then
        noctalia.notifyError("Display Mirror", "wl-mirror is not installed")
        return
    end

    local command = `niri msg action focus-monitor {shellQuote(target)} >/dev/null 2>&1 || true; wl-mirror --fullscreen {shellQuote(source)} >/dev/null 2>&1 & echo $!`
    noctalia.runAsync({ "bash", "-lc", command }, function(result)
        local pid = noctalia.string.trim(result.stdout or "")
        if result.exitCode ~= 0 or not pid:match("^%d+$") then
            noctalia.notifyError("Display Mirror", noctalia.string.trim(result.stderr or "Unable to start wl-mirror"))
            return
        end
        table.insert(mirrors, { pid = pid, source = source, target = target })
        publishMirrors()
        noctalia.notify("Display Mirror", `Mirroring {source} → {target}`)
    end)
end

local function stopMirror(pid)
    if pid == nil then return end
    noctalia.runAsync({ "bash", "-lc", `kill {shellQuote(pid)} 2>/dev/null || true` })
    removeMirrorByPid(pid)
end

local function stopAllMirrors()
    for _, mirror in ipairs(mirrors) do
        noctalia.runAsync({ "bash", "-lc", `kill {shellQuote(mirror.pid)} 2>/dev/null || true` })
    end
    mirrors = {}
    publishMirrors()
    noctalia.notify("Display Mirror", "All mirrors stopped")
end

noctalia.state.watch("picker-command", function(payload)
    if type(payload) ~= "table" then return end
    if payload.action == "pick-instant" then
        pickColor(false, true)
    elseif payload.action == "pick-modal" then
        pickColor(true, false)
    elseif payload.action == "remember" then
        rememberColor(payload.color)
        publishPicker()
    elseif payload.action == "clear" then
        clearPickerHistory()
    end
end)

noctalia.state.watch("mirror-command", function(payload)
    if type(payload) ~= "table" then return end
    local action = payload.action
    if action == "start" then
        startMirror(payload.source, payload.target)
    elseif action == "stop" then
        stopMirror(payload.pid)
    elseif action == "stop-all" then
        stopAllMirrors()
    end
end)

function onIpc(event, _payload)
    if event == "pick" then
        pickColor(false, true)
    elseif event == "pick-modal" then
        pickColor(true, false)
    elseif event == "clear-colors" then
        clearPickerHistory()
    end
end

function update()
    tick += 1
    refreshPower()
    if tick % 5 == 0 then refreshProfile() end
    if tick % 3 == 0 then verifyMirrors() end
end

loadPickerState()
publishPower()
publishPicker()
publishMirrors()
refreshPower()
refreshProfile()
