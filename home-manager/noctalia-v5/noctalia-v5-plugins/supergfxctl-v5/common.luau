--!nonstrict
-- Shared command/parsing helpers for the local SuperGFX port.

local M = {}

M.modeIcons = {
    Integrated = "cpu",
    Hybrid = "chart-circles",
    AsusMuxDgpu = "gauge",
    NvidiaNoModeset = "cpu-off",
    Vfio = "device-desktop-up",
    AsusEgpu = "external-link",
}

M.modeLabels = {
    Integrated = "Integrated",
    Hybrid = "Hybrid",
    AsusMuxDgpu = "ASUS MUX dGPU",
    NvidiaNoModeset = "NVIDIA (no modeset)",
    Vfio = "VFIO",
    AsusEgpu = "ASUS eGPU",
}

local function versionAtMost(version, major, minor, patch)
    local a, b, c = (version or ""):match("^(%d+)%.(%d+)%.(%d+)")
    a, b, c = tonumber(a), tonumber(b), tonumber(c)
    if a == nil then return false end
    if a ~= major then return a < major end
    if b ~= minor then return b < minor end
    return c <= patch
end

function M.parse(output)
    local lines = {}
    for line in output:gmatch("[^\n]+") do
        table.insert(lines, noctalia.string.trim(line))
    end
    if #lines < 2 then
        return { available = false, current = "", pending = "", action = "", supported = {} }
    end

    local supported = {}
    local supportedLine = lines[3] or ""
    for mode in supportedLine:gmatch("([%a][%w]+)") do
        supported[mode] = true
    end

    local version = lines[1] or ""
    local current = lines[2] or ""
    -- supergfxctl 5.2.7 on this ASUS machine only reports AsusMuxDgpu in
    -- --supported while it can also switch to Integrated and Hybrid. This is
    -- the exact compatibility patch used by the installed V4 plugin.
    if versionAtMost(version, 5, 2, 7) and current == "AsusMuxDgpu" then
        supported.Integrated = true
        supported.Hybrid = true
    end

    return {
        available = true,
        version = version,
        current = current,
        supported = supported,
        action = lines[4] or "No action required",
        pending = (lines[5] or "") == "Unknown" and "" or (lines[5] or ""),
    }
end

function M.icon(mode)
    return M.modeIcons[mode] or "device-desktop"
end

function M.label(mode)
    return M.modeLabels[mode] or mode
end

-- V4's patchPending option guessed the action required by supergfxctl when
-- its own pending-action output was unreliable. Keep the same matrix for the
-- current ASUS/NVIDIA machine and return the original user-facing strings.
local ACTIONS = {
    logout = "Logout required to complete mode change",
    reboot = "Reboot required to complete mode change",
    integrated = "You must switch to Integrated first",
    egpu = "The mode must be switched to Integrated or Hybrid first",
    none = "No action required",
}

local actionMatrix = {
    Integrated = {
        Hybrid = ACTIONS.logout,
        AsusEgpu = ACTIONS.logout,
        AsusMuxDgpu = ACTIONS.reboot,
    },
    Hybrid = {
        Integrated = ACTIONS.logout,
        AsusEgpu = ACTIONS.logout,
        AsusMuxDgpu = ACTIONS.logout,
        Vfio = ACTIONS.integrated,
    },
    NvidiaNoModeset = {
        AsusEgpu = ACTIONS.logout,
        AsusMuxDgpu = ACTIONS.reboot,
    },
    Vfio = {
        AsusEgpu = ACTIONS.logout,
        Hybrid = ACTIONS.logout,
        AsusMuxDgpu = ACTIONS.reboot,
    },
    AsusEgpu = {
        Integrated = ACTIONS.logout,
        Hybrid = ACTIONS.logout,
        NvidiaNoModeset = ACTIONS.logout,
        Vfio = ACTIONS.integrated,
        AsusMuxDgpu = ACTIONS.reboot,
    },
    AsusMuxDgpu = {
        Integrated = ACTIONS.reboot,
        Hybrid = ACTIONS.reboot,
        NvidiaNoModeset = ACTIONS.reboot,
        Vfio = ACTIONS.integrated,
        AsusEgpu = ACTIONS.reboot,
    },
}

function M.requiredAction(target, current)
    return (actionMatrix[target] and actionMatrix[target][current]) or ACTIONS.none
end

function M.actionGlyph(action)
    if action == ACTIONS.logout then return "logout" end
    if action == ACTIONS.reboot then return "reload" end
    if action == ACTIONS.integrated then return "cpu" end
    if action == ACTIONS.egpu then return "external-link-off" end
    return "check"
end

function M.actionLabel(action)
    if action == ACTIONS.none or action == nil or action == "" then return "" end
    return action
end

return M
