--!nonstrict
-- Native v5 port of the Niri portion of the V4 Keybind Cheatsheet.
-- The current desktop is Niri, so keep the parser focused on the active KDL
-- source while retaining V4's grouping, descriptions, search, and key-pill
-- visual language.

local configPath = noctalia.getConfig("niri_config_path") or "~/.config/niri/config.kdl"
local columnCount = math.max(1, math.floor(tonumber(noctalia.getConfig("column_count")) or 3))
local showUndescribed = noctalia.getConfig("show_undescribed") ~= false
local mergeSequentialBinds = noctalia.getConfig("merge_sequential_binds") ~= false
local splitLargeWorkspaceCategory = noctalia.getConfig("split_large_workspace_category") ~= false
local workspaceSplitThreshold = math.max(4, math.floor(tonumber(noctalia.getConfig("workspace_split_threshold")) or 12))
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
    KP_Enter = "Num Enter",
    Escape = "Esc",
    Print = "PrtSc",
    Page_Down = "PgDn",
    Page_Up = "PgUp",
    BracketLeft = "[",
    BracketRight = "]",
    Comma = ",",
    Period = ".",
    Minus = "-",
    Equal = "=",
    XF86AudioRaiseVolume = "Vol Up",
    XF86AudioLowerVolume = "Vol Down",
    XF86AudioMute = "Mute",
    XF86AudioMicMute = "Mic Mute",
    XF86MonBrightnessUp = "Bright Up",
    XF86MonBrightnessDown = "Bright Down",
}

local actionNames = {
    ["close-window"] = "Close window",
    ["fullscreen-window"] = "Fullscreen window",
    ["toggle-window-floating"] = "Toggle floating",
    ["switch-focus-between-floating-and-tiling"] = "Switch floating / tiling focus",
    ["maximize-column"] = "Maximize column",
    ["center-visible-columns"] = "Center visible columns",
    ["switch-preset-column-width"] = "Cycle column width",
    ["switch-preset-window-height"] = "Cycle window height",
    ["reset-window-height"] = "Reset window height",
    ["toggle-overview"] = "Toggle overview",
    ["toggle-keyboard-shortcuts-inhibit"] = "Toggle shortcut inhibition",
    ["show-hotkey-overlay"] = "Show hotkey overlay",
    ["focus-column-left"] = "Focus column left",
    ["focus-column-right"] = "Focus column right",
    ["focus-column-first"] = "Focus first column",
    ["focus-column-last"] = "Focus last column",
    ["focus-window-up"] = "Focus window up",
    ["focus-window-down"] = "Focus window down",
    ["move-column-left"] = "Move column left",
    ["move-column-right"] = "Move column right",
    ["move-window-up"] = "Move window up",
    ["move-window-down"] = "Move window down",
    ["focus-monitor-left"] = "Focus monitor left",
    ["focus-monitor-right"] = "Focus monitor right",
    ["focus-monitor-up"] = "Focus monitor up",
    ["focus-monitor-down"] = "Focus monitor down",
    ["move-column-to-monitor-left"] = "Move column to monitor left",
    ["move-column-to-monitor-right"] = "Move column to monitor right",
    ["move-column-to-monitor-up"] = "Move column to monitor up",
    ["move-column-to-monitor-down"] = "Move column to monitor down",
    ["focus-workspace-up"] = "Focus workspace up",
    ["focus-workspace-down"] = "Focus workspace down",
    ["focus-workspace"] = "Focus Workspace",
    ["move-column-to-workspace"] = "Move Column To Workspace",
    ["move-workspace-up"] = "Move workspace up",
    ["move-workspace-down"] = "Move workspace down",
    ["consume-or-expel-window-left"] = "Consume / expel window left",
    ["consume-or-expel-window-right"] = "Consume / expel window right",
    ["consume-window-into-column"] = "Consume window into column",
    ["expel-window-from-column"] = "Expel window from column",
    ["quit"] = "Quit compositor",
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
    local word = firstWord(action)
    if action:find("noctalia", 1, true) ~= nil or action:find("showmethekey", 1, true) ~= nil then
        return "Noctalia"
    end
    if word == "spawn" or word == "spawn-sh" then
        return "Applications"
    end
    if word:find("screenshot", 1, true) ~= nil then
        return "Screenshots"
    end
    if word:find("workspace", 1, true) ~= nil then
        return action:find("move", 1, true) and "Move Workspaces" or "Workspace Navigation"
    end
    if word:find("monitor", 1, true) ~= nil then
        return "Monitor Navigation"
    end
    if word:find("focus", 1, true) ~= nil then
        return "Window Focus"
    end
    if word:find("move", 1, true) ~= nil or word:find("consume", 1, true) ~= nil or word:find("expel", 1, true) ~= nil then
        return "Window Management"
    end
    if word:find("column", 1, true) ~= nil or word:find("window", 1, true) ~= nil then
        return "Window Management"
    end
    if word:find("volume", 1, true) ~= nil or word:find("brightness", 1, true) ~= nil then
        return "Hardware"
    end
    if word == "quit" or word == "power-off-monitors" then
        return "System"
    end
    return "Other"
end

local function describe(action)
    local word = firstWord(action)
    if actionNames[word] ~= nil then
        return actionNames[word]
    end
    local command = action
        :gsub("^spawn%-sh%s+", "Run ")
        :gsub("^spawn%s+", "Run ")
        :gsub("^power%-off%-monitors$", "Power off monitors")
    -- Keep hyphens in command arguments such as `-e`; only known dispatcher
    -- names above are humanized. V4 preserves unknown command lines verbatim.
    command = command:gsub("[%\"']", "")
    return trim(command)
end

local function addCategory(name, rawKey, description, identity, action)
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
    for _, bind in ipairs(category.binds) do
        if bind.identity == identity then
            return
        end
    end
    table.insert(category.binds, {
        rawKey = rawKey,
        keys = formatKey(rawKey),
        description = description,
        identity = identity,
        action = action or "",
    })
end

local function parseFile(path, inheritedCategory, depth, visited)
    if depth > 24 then return end
    path = noctalia.expandPath(path)
    if visited[path] then return end
    visited[path] = true
    local text = noctalia.readFile(path) or ""
    local inBinds = false
    local categoryName = inheritedCategory or ""

    for line in text:gmatch("[^\n]+") do
        local stripped = trim(line)
        local includePath = stripped:match("^include%s+[\"<]([^\">]+)[\">]")
        if includePath ~= nil then
            local child = includePath
            if child:sub(1, 1) ~= "/" then
                local parent = path:match("^(.+)/[^/]+$") or "."
                child = parent .. "/" .. child
            end
            parseFile(child, categoryName, depth + 1, visited)
        end

        local commentCategory = stripped:match('^//%s*#%s*["\']([^"\']+)["\']')
        if commentCategory ~= nil then
            categoryName = trim(commentCategory)
        end

        if stripped:match("^binds%s*{") then
            inBinds = true
        elseif inBinds and stripped:match("^}") then
            inBinds = false
        elseif inBinds and not stripped:match("^//") and stripped ~= "" then
            local rawKey, attributes, body = stripped:match("^([%w_+%-]+)%s*(.-)%s*{(.*)}%s*$")
            if rawKey ~= nil and body ~= nil then
                local title = attributes:match('hotkey%-overlay%-title%s*=%s*["\']([^"\']*)["\']') or ""
                local action = trim(body):gsub(";%s*$", "")
                if title == "" and not showUndescribed then
                    -- V4 setting: omit bindings without an explicit title.
                else
                    local category = categoryName ~= "" and categoryName or classify(action)
                    local shown = title ~= "" and title or describe(action)
                    addCategory(category, rawKey, shown, rawKey .. "\0" .. action, action)
                end
            end
        end
    end
end

local function mergeSequential()
    if not mergeSequentialBinds then return end
    for _, category in ipairs(categories) do
        local plain = {}
        local groups = {}
        local groupOrder = {}
        for _, bind in ipairs(category.binds) do
            local prefix, number = bind.rawKey:match("^(.-%+)(%d+)$")
            local verb = firstWord(bind.action or "")
            if prefix ~= nil and number ~= nil and verb ~= "" then
                local key = prefix .. "\0" .. verb
                if groups[key] == nil then
                    groups[key] = { prefix = prefix, verb = verb, items = {} }
                    table.insert(groupOrder, key)
                end
                table.insert(groups[key].items, { number = tonumber(number), bind = bind })
            else
                table.insert(plain, bind)
            end
        end

        for _, key in ipairs(groupOrder) do
            local group = groups[key]
            table.sort(group.items, function(a, b) return a.number < b.number end)
            local first = group.items[1]
            local last = group.items[#group.items]
            local contiguous = #group.items > 1
            for index = 2, #group.items do
                if group.items[index].number ~= group.items[index - 1].number + 1 then
                    contiguous = false
                end
            end
            if contiguous then
                local range = `{first.number}-{last.number}`
                local description = actionNames[group.verb] or first.bind.description:gsub("%s+%d+$", "")
                table.insert(plain, {
                    rawKey = group.prefix .. range,
                    keys = formatKey(group.prefix .. range),
                    description = `{description} {range}`,
                    identity = `merged\0{key}\0{range}`,
                    action = group.verb,
                })
            else
                for _, item in ipairs(group.items) do table.insert(plain, item.bind) end
            end
        end
        category.binds = plain
    end
end

local function splitLargeWorkspaceCategories()
    if not splitLargeWorkspaceCategory then return end
    local split = {}
    for _, category in ipairs(categories) do
        local isWorkspace = category.title:lower():find("workspace", 1, true) ~= nil
        if isWorkspace and #category.binds > workspaceSplitThreshold then
            local part = 1
            for start = 1, #category.binds, workspaceSplitThreshold do
                local binds = {}
                for index = start, math.min(#category.binds, start + workspaceSplitThreshold - 1) do
                    table.insert(binds, category.binds[index])
                end
                table.insert(split, { title = `{category.title} {part}`, binds = binds })
                part += 1
            end
        else
            table.insert(split, category)
        end
    end
    categories = split
end

local function parse()
    categories = {}
    parseFile(configPath, nil, 0, {})
    mergeSequential()
    splitLargeWorkspaceCategories()
    loaded = true
end

local function matches(bind)
    if search == "" then return true end
    local needle = search:lower()
    return bind.keys:lower():find(needle, 1, true) ~= nil
        or bind.description:lower():find(needle, 1, true) ~= nil
end

local function keyFill(rawKey)
    if rawKey:find("XF86", 1, true) then return "#4ECDC4" end
    if rawKey:find("Print", 1, true) then return "#95E1D3" end
    if rawKey:match("%d") then return "#A8DADC" end
    if rawKey:find("Alt", 1, true) then return "#FF6B6B" end
    if rawKey:find("Ctrl", 1, true) then return "secondary" end
    if rawKey:find("Shift", 1, true) then return "tertiary" end
    if rawKey:find("Mod", 1, true) or rawKey:find("Super", 1, true) then return "primary" end
    return "#6C757D"
end

local function categoryNode(category)
    local children = {
        ui.label({ text = category.title, color = "primary", fontSize = 15, fontWeight = "bold" }),
    }
    local count = 0
    for _, bind in ipairs(category.binds) do
        if matches(bind) then
            count += 1
            table.insert(children, ui.row({ key = `bind-{category.title}-{count}`, gap = 8, align = "center" }, {
                ui.row({ fill = keyFill(bind.rawKey), radius = 5, width = 170, paddingH = 8, paddingV = 4, align = "center" }, {
                    ui.label({ text = bind.keys, color = "#FFFFFF", fontWeight = "bold", maxLines = 1 }),
                }),
                ui.label({ text = bind.description, color = "on_surface", flexGrow = 1, maxLines = 2 }),
            }))
        end
    end
    if count == 0 then return nil end
    return ui.column({ key = `category-{category.title}`, gap = 6, align = "stretch" }, children)
end

function render()
    if not loaded then parse() end
    local columns = {}
    for index = 1, columnCount do columns[index] = {} end
    for index, category in ipairs(categories) do
        local node = categoryNode(category)
        if node ~= nil then
            table.insert(columns[((index - 1) % columnCount) + 1], node)
        end
    end

    local columnNodes = {}
    for index = 1, columnCount do
        table.insert(columnNodes, ui.column({ key = `column-{index}`, gap = 18, flexGrow = 1, align = "stretch" }, columns[index]))
    end

    panel.render(ui.column({ gap = 12, flexGrow = 1, align = "stretch" }, {
        ui.row({ gap = 8, align = "center" }, {
            ui.glyph({ name = "keyboard", size = 22, color = "primary" }),
            ui.label({ text = "Keybind Cheatsheet", fontSize = 17, fontWeight = "bold", flexGrow = 1 }),
            ui.button({ glyph = "refresh", tooltip = "Refresh", onClick = "onRefresh" }),
            ui.button({ glyph = "x", onClick = "onClose" }),
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
