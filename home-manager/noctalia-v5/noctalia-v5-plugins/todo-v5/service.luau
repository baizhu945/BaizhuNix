--!nonstrict
-- Shared persistent state for the v5 Todo List port.

local store = require("./data.luau")
store.load()

-- Keep the service alive so state watchers are always available, without rewriting state.
noctalia.setUpdateInterval(60000)
function update()
end
