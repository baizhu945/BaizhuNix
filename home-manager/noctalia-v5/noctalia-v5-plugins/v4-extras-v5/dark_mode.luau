--!nonstrict
-- Direct replacement for V4's stateful Dark Mode shortcut.

local function render()
    local dark = noctalia.isDarkMode()
    shortcut.setIcon(dark and "moon-filled" or "sun")
    shortcut.setLabel("Dark Mode")
    shortcut.setActive(dark)
    shortcut.setEnabled(true)
end

function onClick()
    noctalia.runAsync({ "noctalia", "msg", "theme-mode-toggle" }, function(result)
        if result.exitCode ~= 0 then
            noctalia.notifyError("Dark Mode", noctalia.string.trim(result.stderr or "Toggle failed"))
        end
    end)
end

noctalia.setUpdateInterval(1000)
function update()
    render()
end

render()
