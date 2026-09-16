--!nonstrict
-- Compact bar tile for the v4 Todo List.

local store = require("./data.luau")
local data = store.load()
noctalia.setUpdateInterval(1000)

local function activeCount()
    local count = 0
    if type(data.todos) == "table" then
        for _, todo in ipairs(data.todos) do
            if todo.completed ~= true then
                count += 1
            end
        end
    end
    return count
end

local function render()
    local count = activeCount()
    barWidget.setGlyph("clipboard-check")
    barWidget.setColor("on_surface")
    barWidget.setText(tostring(count))
    barWidget.setTooltip(`Todo: {count} active`)
end

noctalia.state.watch("data", function(value)
    if type(value) == "table" then
        data = value
        render()
    end
end)

function update()
    render()
end

function onClick()
    noctalia.togglePanel("baizhu/todo:panel")
end
