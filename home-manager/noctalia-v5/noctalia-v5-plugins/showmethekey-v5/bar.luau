--!nonstrict
-- Port of the v4 showmethekey text-stream bar widget.

local command = "showmethekey-cli | python3 ~/.local/bin/showmethekey-cli.py"
barWidget.setColor("primary")
barWidget.setVisible(false)

local function applyLine(line)
    local object = noctalia.json.decode(line)
    if object == nil or type(object) ~= "table" then
        return
    end
    local text = object.text or ""
    barWidget.setText(text)
    barWidget.setVisible(text ~= "")
    if text == "" then
        barWidget.clearTooltip()
    else
        barWidget.setTooltip(text)
    end
end

if not noctalia.runStream(command, applyLine) then
    noctalia.notifyError("Show Me The Key", "Unable to start showmethekey-cli stream")
end

function onClick()
    noctalia.runAsync("showmethekey-toggle")
end
