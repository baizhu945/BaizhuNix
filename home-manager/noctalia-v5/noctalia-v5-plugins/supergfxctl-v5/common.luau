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
    return {
        available = true,
        version = lines[1] or "",
        current = lines[2] or "",
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

return M
