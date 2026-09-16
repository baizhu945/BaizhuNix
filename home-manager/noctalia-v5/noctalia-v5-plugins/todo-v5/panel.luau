--!nonstrict
-- Practical v5 replacement for the v4 Todo List panel.
-- Data is shared with the bar widget through noctalia.state.

local store = require("./data.luau")
local data = store.load()

local showCompleted = data.show_completed ~= false
local priority = "medium"
local inputGeneration = 0
local editingId = nil
local nextId = math.floor(noctalia.nowMs())

local function save()
    data.show_completed = showCompleted
    store.save(data)
end

local function findTodo(id)
    for _, todo in ipairs(data.todos) do
        if tostring(todo.id) == tostring(id) then
            return todo
        end
    end
    return nil
end

local function activeCount()
    local count = 0
    for _, todo in ipairs(data.todos) do
        if todo.completed ~= true then
            count += 1
        end
    end
    return count
end

local function completedCount()
    local count = 0
    for _, todo in ipairs(data.todos) do
        if todo.completed == true then
            count += 1
        end
    end
    return count
end

local function currentPageTodos()
    local result = {}
    for _, todo in ipairs(data.todos) do
        local pageId = todo.pageId or 0
        if pageId == data.current_page_id and (showCompleted or todo.completed ~= true) then
            table.insert(result, todo)
        end
    end
    return result
end

local function addTodo(text)
    text = noctalia.string.trim(text or "")
    if text == "" then
        return
    end
    nextId += 1
    table.insert(data.todos, {
        id = nextId,
        text = text,
        completed = false,
        priority = priority,
        details = "",
        pageId = data.current_page_id or 0,
    })
    priority = "medium"
    inputGeneration += 1
    save()
    render()
end

local function toggleTodo(id, value)
    local todo = findTodo(id)
    if todo == nil then
        return
    end
    todo.completed = value == "true"
    save()
    render()
end

local function removeTodo(id)
    for index, todo in ipairs(data.todos) do
        if tostring(todo.id) == tostring(id) then
            table.remove(data.todos, index)
            break
        end
    end
    if tostring(editingId) == tostring(id) then
        editingId = nil
    end
    save()
    render()
end

local function clearCompleted()
    local remaining = {}
    for _, todo in ipairs(data.todos) do
        if todo.completed ~= true then
            table.insert(remaining, todo)
        end
    end
    data.todos = remaining
    editingId = nil
    save()
    render()
end

local function updateTodoText(id, text)
    local todo = findTodo(id)
    if todo ~= nil then
        text = noctalia.string.trim(text or "")
        if text ~= "" then
            todo.text = text
            save()
        end
    end
    editingId = nil
    render()
end

local function updateTodoDetails(id, text)
    local todo = findTodo(id)
    if todo ~= nil then
        todo.details = text or ""
        save()
    end
end

local function exportTodos()
    local lines = {
        "# Todo List",
        "",
    }
    for _, page in ipairs(data.pages) do
        local pageTodos = {}
        for _, todo in ipairs(data.todos) do
            if (todo.pageId or 0) == (page.id or 0) then
                table.insert(pageTodos, todo)
            end
        end
        if #pageTodos > 0 then
            table.insert(lines, `## {page.name}`)
            table.insert(lines, "")
            for _, todo in ipairs(pageTodos) do
                local mark = todo.completed == true and "x" or " "
                table.insert(lines, `- [{mark}] {todo.text}`)
                if todo.details ~= nil and todo.details ~= "" then
                    table.insert(lines, `  - {todo.details}`)
                end
            end
            table.insert(lines, "")
        end
    end

    local path = `~/Documents/todo_{noctalia.formatTime("%Y%m%d_%H%M%S")}.md`
    local ok = noctalia.writeFile(path, table.concat(lines, "\n"))
    if ok then
        noctalia.notify("Todo List", `Exported to {path}`)
    else
        noctalia.notifyError("Todo List", "Unable to write the export file")
    end
end

local function pageIndex()
    for index, page in ipairs(data.pages) do
        if (page.id or 0) == data.current_page_id then
            return index - 1
        end
    end
    return 0
end

local function pageNames()
    local result = {}
    for _, page in ipairs(data.pages) do
        table.insert(result, page.name or "General")
    end
    return result
end

function render()
    local todoRows = {}
    for _, todo in ipairs(currentPageTodos()) do
        local id = todo.id
        local isEditing = tostring(editingId) == tostring(id)
        local editorChildren = {}

        if isEditing then
            table.insert(editorChildren, ui.input({
                key = `text-{id}`,
                value = todo.text or "",
                placeholder = "Todo",
                submitOnEnter = true,
                onSubmit = function(value)
                    updateTodoText(id, value)
                end,
            }))
            table.insert(editorChildren, ui.input({
                key = `details-{id}`,
                value = todo.details or "",
                placeholder = "Details (optional)",
                multiline = true,
                height = 52,
                onChange = function(value)
                    updateTodoDetails(id, value)
                end,
            }))
        else
            table.insert(editorChildren, ui.label({
                text = todo.completed == true and `✓ {todo.text}` or (todo.text or ""),
                color = todo.completed == true and "on_surface_variant" or "on_surface",
                fontWeight = todo.completed == true and "regular" or "medium",
                flexGrow = 1,
            }))
            if todo.details ~= nil and todo.details ~= "" then
                table.insert(editorChildren, ui.label({
                    text = todo.details,
                    color = "on_surface_variant",
                    maxLines = 2,
                }))
            end
        end

        table.insert(todoRows, ui.row({ key = `todo-{id}`, gap = 8, align = "center", padding = 8, fill = "surface_variant/0.45", radius = 6 }, {
            ui.toggle({ checked = todo.completed == true, onChange = function(value)
                toggleTodo(id, value)
            end }),
            ui.column({ gap = 4, flexGrow = 1, align = "stretch" }, editorChildren),
            ui.button({ glyph = isEditing and "check" or "pencil", variant = "ghost", onClick = function()
                if isEditing then
                    editingId = nil
                else
                    editingId = id
                end
                render()
            end }),
            ui.button({ glyph = "copy", variant = "ghost", onClick = function()
                noctalia.copyToClipboard(todo.text or "", "text/plain")
            end }),
            ui.button({ glyph = "trash", variant = "ghost", onClick = function()
                removeTodo(id)
            end }),
        }))
    end

    if #todoRows == 0 then
        table.insert(todoRows, ui.label({
            text = showCompleted and "No todos on this page" or "No active todos on this page",
            color = "on_surface_variant",
            fontSize = 15,
        }))
    end

    panel.render(ui.column({ gap = 12, flexGrow = 1, align = "stretch" }, {
        ui.row({ gap = 8, align = "center" }, {
            ui.glyph({ name = "clipboard-check", size = 22, color = "primary" }),
            ui.label({ text = `Todo List  ·  {activeCount()} active`, fontSize = 17, fontWeight = "bold", flexGrow = 1 }),
            ui.button({ glyph = "download", tooltip = "Export", onClick = exportTodos }),
            ui.button({ glyph = "trash", tooltip = "Clear completed", enabled = completedCount() > 0, onClick = clearCompleted }),
            ui.button({ glyph = "close", onClick = "onClose" }),
        }),
        ui.row({ gap = 8, align = "center" }, {
            ui.select({ options = pageNames(), selectedIndex = pageIndex(), onChange = function(index)
                local selected = data.pages[(tonumber(index) or 0) + 1]
                if selected ~= nil then
                    data.current_page_id = selected.id or 0
                    save()
                    render()
                end
            end }),
            ui.select({ options = { "High", "Medium", "Low" }, selectedIndex = priority == "high" and 0 or (priority == "low" and 2 or 1), onChange = function(index)
                local i = tonumber(index) or 1
                priority = i == 0 and "high" or (i == 2 and "low" or "medium")
            end }),
            ui.toggle({ checked = showCompleted, onChange = function(value)
                showCompleted = value == "true"
                save()
                render()
            end }),
            ui.label({ text = "Show completed", color = "on_surface_variant", flexGrow = 1 }),
        }),
        ui.input({
            key = `new-todo-{inputGeneration}`,
            placeholder = "Add a todo and press Enter…",
            submitOnEnter = true,
            onSubmit = addTodo,
        }),
        ui.scroll({ flexGrow = 1, gap = 8, align = "stretch", fill = "surface_variant/0.25", radius = 8, padding = 8 }, todoRows),
    }))
end

noctalia.state.watch("data", function(value)
    if type(value) == "table" and type(value.todos) == "table" then
        data = value
        showCompleted = data.show_completed ~= false
        render()
    end
end)

function onOpen(_context)
    render()
end

function onClose()
    panel.close()
end

render()
