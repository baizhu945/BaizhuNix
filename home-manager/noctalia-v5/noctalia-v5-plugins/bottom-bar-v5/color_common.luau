--!nonstrict

local M = {}

local function round(value)
    return math.floor(value + 0.5)
end

function M.normalize(value)
    if type(value) ~= "string" then return nil end
    local hex = noctalia.string.trim(value):upper()
    if hex:match("^#%x%x%x%x%x%x$") then return hex end
    return nil
end

function M.formats(value)
    local hex = M.normalize(value)
    if hex == nil then return nil end

    local r = tonumber(hex:sub(2, 3), 16) or 0
    local g = tonumber(hex:sub(4, 5), 16) or 0
    local b = tonumber(hex:sub(6, 7), 16) or 0
    local rf, gf, bf = r / 255, g / 255, b / 255
    local maximum = math.max(rf, gf, bf)
    local minimum = math.min(rf, gf, bf)
    local delta = maximum - minimum

    local hue = 0
    if delta > 0 then
        if maximum == rf then
            hue = 60 * (((gf - bf) / delta) % 6)
        elseif maximum == gf then
            hue = 60 * (((bf - rf) / delta) + 2)
        else
            hue = 60 * (((rf - gf) / delta) + 4)
        end
    end
    if hue < 0 then hue += 360 end

    local lightness = (maximum + minimum) / 2
    local hslSaturation = 0
    if delta > 0 then hslSaturation = delta / (1 - math.abs(2 * lightness - 1)) end

    local hsvSaturation = maximum == 0 and 0 or delta / maximum
    local key = 1 - maximum
    local cyan, magenta, yellow = 0, 0, 0
    if key < 1 then
        cyan = (1 - rf - key) / (1 - key)
        magenta = (1 - gf - key) / (1 - key)
        yellow = (1 - bf - key) / (1 - key)
    end

    return {
        hex = hex,
        r = r,
        g = g,
        b = b,
        hue = round(hue),
        saturation = round(hsvSaturation * 100),
        value = round(maximum * 100),
        rgb = `{r}, {g}, {b}`,
        rgb_css = `rgb({r}, {g}, {b})`,
        hsl = `{round(hue)}°, {round(hslSaturation * 100)}%, {round(lightness * 100)}%`,
        hsl_css = `hsl({round(hue)}, {round(hslSaturation * 100)}%, {round(lightness * 100)}%)`,
        hsv = `{round(hue)}°, {round(hsvSaturation * 100)}%, {round(maximum * 100)}%`,
        cmyk = `cmyk({round(cyan * 100)}%, {round(magenta * 100)}%, {round(yellow * 100)}%, {round(key * 100)}%)`,
    }
end

function M.fromHsv(hue, saturation, value)
    local h = (tonumber(hue) or 0) % 360
    local s = math.max(0, math.min(100, tonumber(saturation) or 0)) / 100
    local v = math.max(0, math.min(100, tonumber(value) or 0)) / 100
    local chroma = v * s
    local x = chroma * (1 - math.abs(((h / 60) % 2) - 1))
    local m = v - chroma
    local rf, gf, bf = 0, 0, 0
    if h < 60 then
        rf, gf, bf = chroma, x, 0
    elseif h < 120 then
        rf, gf, bf = x, chroma, 0
    elseif h < 180 then
        rf, gf, bf = 0, chroma, x
    elseif h < 240 then
        rf, gf, bf = 0, x, chroma
    elseif h < 300 then
        rf, gf, bf = x, 0, chroma
    else
        rf, gf, bf = chroma, 0, x
    end
    return string.format("#%02X%02X%02X", round((rf + m) * 255), round((gf + m) * 255), round((bf + m) * 255))
end

function M.withAlpha(value, opacity)
    local hex = M.normalize(value)
    if hex == nil then return "#00000000" end
    local alpha = round(math.max(0, math.min(100, tonumber(opacity) or 100)) * 2.55)
    return hex .. string.format("%02X", alpha)
end

return M
