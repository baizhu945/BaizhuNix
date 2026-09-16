--!nonstrict
-- Persistent store for the Todo List. Noctalia's shared state is process-local,
-- so the JSON file keeps the V4 todos across V5 restarts.

local M = {}
local dataDir = noctalia.pluginDataDir() or "~/.local/state/noctalia/plugins/data/baizhu/todo"
local dataPath = `{dataDir}/todos.json`

local function defaultData()
    return {
        todos = {},
        pages = {{ id = 0, name = "General" }},
        current_page_id = 0,
        show_completed = true,
    }
end

local function validData(value)
    return type(value) == "table" and type(value.todos) == "table"
end

local function legacyData()
    local text = noctalia.readFile("~/.config/noctalia/settings.json")
    if text == nil or text == "" then
        return nil
    end
    local root = noctalia.json.decode(text)
    if root == nil or type(root) ~= "table" or root.bar == nil or root.bar.widgets == nil then
        return nil
    end
    local sections = { root.bar.widgets.left, root.bar.widgets.center, root.bar.widgets.right }
    for _, section in ipairs(sections) do
        if type(section) == "table" then
            for _, item in ipairs(section) do
                if type(item) == "table" and item.id == "plugin:todo" and type(item.defaultSettings) == "table" then
                    local old = item.defaultSettings
                    return {
                        todos = old.todos or {},
                        pages = old.pages or {{ id = 0, name = "General" }},
                        current_page_id = old.current_page_id or 0,
                        show_completed = old.showCompleted ~= false,
                    }
                end
            end
        end
    end
    return nil
end

function M.load()
    local live = noctalia.state.get("data")
    if validData(live) then
        return live
    end

    local saved = noctalia.readFile(dataPath)
    local parsed = saved ~= nil and saved ~= "" and noctalia.json.decode(saved) or nil
    local data = validData(parsed) and parsed or legacyData() or defaultData()
    if type(data.pages) ~= "table" or #data.pages == 0 then
        data.pages = {{ id = 0, name = "General" }}
    end
    if data.current_page_id == nil then
        data.current_page_id = data.pages[1].id or 0
    end
    if data.show_completed == nil then
        data.show_completed = true
    end
    noctalia.state.set("data", data)
    local encoded = noctalia.json.encode(data)
    if encoded ~= nil then
        noctalia.writeFile(dataPath, encoded)
    end
    return data
end

function M.save(data)
    noctalia.state.set("data", data)
    local encoded = noctalia.json.encode(data)
    if encoded ~= nil then
        noctalia.writeFile(dataPath, encoded)
    end
end

return M
