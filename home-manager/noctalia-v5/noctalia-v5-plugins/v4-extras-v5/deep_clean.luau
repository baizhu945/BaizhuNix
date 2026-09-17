--!nonstrict
-- Direct replacement for V4's Deep Clean custom shortcut.

shortcut.setIcon("archive")
shortcut.setLabel("Deep Clean")
shortcut.setActive(false)
shortcut.setEnabled(true)

function onClick()
    if not noctalia.runAsync({ "nix-clean" }, function(result)
        if result.exitCode == 0 then
            noctalia.notify("Deep Clean", "Clean completed")
        else
            noctalia.notifyError("Deep Clean", noctalia.string.trim(result.stderr or "Clean failed"))
        end
    end) then
        noctalia.notifyError("Deep Clean", "Unable to start nix-clean")
    end
end
