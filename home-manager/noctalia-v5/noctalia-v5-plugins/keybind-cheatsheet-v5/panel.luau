--!nonstrict
-- Lightweight native v5 port of the Niri keybind cheatsheet.
-- It intentionally reads the same KDL file as the v4 plugin and keeps the
-- useful hotkey-overlay-title text when it is present.

local configPath = noctalia.getConfig("niri_config_path") or "~/.config/niri/config.kdl"
local columnCount = math.max(1, math.floor(tonumber(noctalia.getConfig("column_count")) or 3))
local showUndescribed = noctalia.getConfig("show_undescribed") ~= false
local categories = {}
local search = ""
local loaded = false

local keyNames = {
    Mod = "Super",
    Super = "Super",
    Win = "Super",
    Ctrl = "Ctrl",
    Control = "Ctrl",
    Alt = "Alt",
    Shift = "Shift",
    Return = "Enter",
    Escape = "Esc",
    Print = "PrtSc",
}

local actionNames = {
    ["focus-column-left"] = "Focus column left",
    ["focus-column-right"] = "Focus column right",
    ["focus-window-down"] = "Focus window down",
    ["focus-window-up"] = "Focus window up",
    ["close-window"] = "Close window",
    ["toggle-window-floating"] = "Toggle floating",
    ["fullscreen-window"] = "Fullscreen window",
    ["maximize-column"] = "Maximize column",
    ["switch-preset-column-width"] = "Cycle column width",
    ["toggle-overview"] = "Toggle overview",
    ["show-hotkey-overlay"] = "Show hotkey overlay",
}

local function trim(value)
    return noctalia.string.trim(value or "")
end

local function formatKey(raw)
    local parts = {}
    for part in raw:gmatch("[^+]+") do
        table.insert(parts, keyNames[part] or part)
    end
    return table.concat(parts, " + ")
end

local function firstWord(action)
    return action:match("^([%w%-]+)") or ""
end

local function classify(action)
    if action:find("noctalia", 1, true) ~= nil then
        return "Noctalia"
    end
    if action:find("spawn", 1, true) ~= nil then
        return "Applications"
    end
    if action:find("workspace", 1, true) ~= nil then
        if action:find("move", 1, true) ~= nil then
            return "Workspace management"
        end
        return "Workspace navigation"
    end
    if action:find("focus", 1, true) ~= nil then
        return "Window focus"
    end
    if action:find("move", 1, true) ~= nil or action:find("consume", 1, true) ~= nil or action:find("expel", 1, true) ~= nil then
        return "Window management"
    end
    if action:find("screenshot", 1, true) ~= nil then
        return "Screenshots"
    end
    if action:find("volume", 1, true) ~= nil or action:find("brightness", 1, true) ~= nil then
        return "Hardware"
    end
    if action:find("quit", 1, true) ~= nil or action:find("reboot", 1, true) ~= nil then
        return "System"
    end
    return "Other"
end

local function describe(action)
    local word = firstWord(action)
    if actionNames[word] ~= nil then
        return actionNames[word]
    end
    local command = action:gsub("^spawn%-sh%s+", "Run "):gsub("^spawn%s+", "Run ")
    command = command:gsub("%-", " ")
    command = command:gsub("^%s+", "")
    return command
end

local function addCategory(name, key, description)
    local category = nil
    for _, existing in ipairs(categories) do
        if existing.title == name then
            category = existing
            break
        end
    end
    if category == nil then
        category = { title = name, binds = {} }
        table.insert(categories, category)
    end
    table.insert(category.binds, { keys = formatKey(key), description = description })
end

local function parse()
    categories = {}
    local text = noctalia.readFile(configPath) or ""
    local inBinds = false
    for line in text:gmatch("[^\n]+") do
        local stripped = trim(line)
        if not inBinds and stripped:match("^binds%s*{") then
            inBinds = true
        elseif inBinds and stripped:match("^}") then
            break
        elseif inBinds and not stripped:match("^//") then
            local key = stripped:match("^([%w_+%-]+)%s+")
            local body = stripped:match("{(.*)}")
            if key ~= nil and body ~= nil then
                local title = stripped:match('hotkey%-overlay%-title%s*=%s*"([^"]*)"') or ""
                local action = trim(body):gsub(";%s*$", "")
                if title == "" and not showUndescribed then
                    -- Skip binds without a user-facing description, like v4.
                else
                    addCategory(classify(action), key, title ~= "" and title or describe(action))
                end
            end
        end
    end
    loaded = true
end

local function matches(bind)
    if search == "" then
        return true
    end
    local needle = search:lower()
    return bind.keys:lower():find(needle, 1, true) ~= nil
        or bind.description:lower():find(needle, 1, true) ~= nil
end

local function categoryNode(category)
    local children = {
        ui.label({ text = category.title, color = "primary", fontSize = 15, fontWeight = "bold" }),
    }
    local count = 0
    for _, bind in ipairs(category.binds) do
        if matches(bind) then
            count += 1
            table.insert(children, ui.row({ key = `bind-{category.title}-{count}`, gap = 6, align = "center" }, {
                ui.label({ text = bind.keys, color = "on_primary", fontWeight = "bold", width = 160 }),
                ui.label({ text = bind.description, color = "on_surface", flexGrow = 1, maxLines = 2 }),
            }))
        end
    end
    if count == 0 then
        return nil
    end
    return ui.column({ key = `category-{category.title}`, gap = 5, align = "stretch" }, children)
end

function render()
    if not loaded then
        parse()
    end
    local columns = {}
    for index = 1, columnCount do
        columns[index] = {}
    end
    for index, category in ipairs(categories) do
        local node = categoryNode(category)
        if node ~= nil then
            table.insert(columns[((index - 1) % columnCount) + 1], node)
        end
    end

    local columnNodes = {}
    for index = 1, columnCount do
        table.insert(columnNodes, ui.column({ key = `column-{index}`, gap = 16, flexGrow = 1, align = "stretch" }, columns[index]))
    end

    panel.render(ui.column({ gap = 12, flexGrow = 1, align = "stretch" }, {
        ui.row({ gap = 8, align = "center" }, {
            ui.glyph({ name = "keyboard", size = 22, color = "primary" }),
            ui.label({ text = "Keybind Cheatsheet", fontSize = 17, fontWeight = "bold", flexGrow = 1 }),
            ui.button({ glyph = "refresh", onClick = "onRefresh" }),
            ui.button({ glyph = "close", onClick = "onClose" }),
        }),
        ui.input({ key = "search", value = search, placeholder = "Search keybinds…", onChange = "onSearch" }),
        ui.scroll({ flexGrow = 1, gap = 12, fill = "surface_variant/0.25", radius = 8, padding = 12 }, {
            ui.row({ gap = 24, align = "start" }, columnNodes),
        }),
    }))
end

function onOpen(_context)
    parse()
    render()
end

function onRefresh()
    parse()
    render()
end

function onSearch(value)
    search = value or ""
    render()
end

function onClose()
    panel.close()
end

render()
