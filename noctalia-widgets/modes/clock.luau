--!nonstrict
-- Clock desktop widget: digital, stacked or compact.
--
-- The DMS original also drew an analog face. The declarative ui.* vocabulary has
-- no canvas or absolute positioning, so this port keeps the two text layouts and
-- adds a compact one instead. Everything else (date line, seconds, timezone,
-- palette color) is preserved.

local util = require("../lib/util.luau")

local STYLE = noctalia.getConfig("clock_style") or "digital"
local SHOW_SECONDS = noctalia.getConfig("clock_show_seconds") == true
local SHOW_DATE = noctalia.getConfig("clock_show_date") ~= false
local DATE_FORMAT = noctalia.getConfig("clock_date_format") or ""
if util.trim(DATE_FORMAT) == "" then
    DATE_FORMAT = "%a, %b %-d"
end
local TIME_FORMAT = noctalia.getConfig("clock_time_format") or ""
local COLOR = noctalia.getConfig("clock_color") or "primary"
local DATE_COLOR = noctalia.getConfig("clock_date_color") or "on_surface_variant"
local SHADOW = noctalia.getConfig("clock_shadow") == true
local WIDTH = tonumber(noctalia.getConfig("clock_width")) or 0

local timezone = noctalia.getConfig("clock_timezone") or ""
if timezone ~= "" and not noctalia.isValidTimezone(timezone) then
    timezone = ""
end

local function strftime(pattern, zone)
    return noctalia.formatTime(pattern, nil, zone ~= "" and zone or nil)
end

local function timeFormat()
    if TIME_FORMAT ~= "" then
        return TIME_FORMAT
    end
    return noctalia.timeFormat()
end

local function contains(text, token)
    return string.find(text, token, 1, true) ~= nil
end

local function isTwelveHour()
    local format = timeFormat()
    return contains(format, "%I")
        or contains(format, "%l")
        or contains(format, "%r")
        or contains(format, "%p")
end

local function formatHasSeconds()
    local format = timeFormat()
    return contains(format, "%S")
        or contains(format, "%T")
        or contains(format, "%r")
        or contains(format, "%X")
        or contains(format, "%c")
end

local function rootWidth()
    if WIDTH > 0 then
        return WIDTH
    elseif STYLE == "stacked" then
        return 160
    elseif STYLE == "compact" then
        return 150
    end
    return 250
end

local function textLabel(text, size, color, weight)
    local props = {
        text = text,
        fontSize = size,
        color = color,
        fontWeight = weight or "normal",
        textAlign = "center",
        maxLines = 1,
    }
    return ui.label(util.withShadow(props, SHADOW))
end

local function dateLabel()
    return textLabel(strftime(DATE_FORMAT, timezone), 13, DATE_COLOR, "medium")
end

local function secondsLabel(size)
    return textLabel(strftime("%S", timezone), size, DATE_COLOR, "medium")
end

local function digital()
    local size = SHOW_SECONDS and 46 or 52
    local children = {}

    if SHOW_DATE then
        children[#children + 1] = dateLabel()
    end

    local clockRow = {
        textLabel(strftime(timeFormat(), timezone), size, COLOR, "bold"),
    }
    if SHOW_SECONDS and not formatHasSeconds() then
        clockRow[#clockRow + 1] = secondsLabel(16)
    end

    children[#children + 1] = ui.row({ gap = 2, align = "end", justify = "center" }, clockRow)
    return ui.column({ width = rootWidth(), gap = 2, padding = 4, align = "center" }, children)
end

local function stacked()
    local hourFormat = isTwelveHour() and "%-I" or "%H"
    local children = {
        ui.column({ gap = 0, align = "center" }, {
            textLabel(strftime(hourFormat, timezone), 58, COLOR, "bold"),
            textLabel(strftime("%M", timezone), 58, COLOR, "bold"),
        }),
    }

    if SHOW_SECONDS then
        children[#children + 1] = secondsLabel(16)
    end
    if isTwelveHour() then
        children[#children + 1] = textLabel(strftime("%p", timezone), 12, DATE_COLOR, "semibold")
    end
    if SHOW_DATE then
        children[#children + 1] = dateLabel()
    end

    return ui.column({ width = rootWidth(), gap = 2, padding = 4, align = "center" }, children)
end

local function compact()
    local row = {
        textLabel(strftime(timeFormat(), timezone), 48, COLOR, "bold"),
    }
    if SHOW_SECONDS and not formatHasSeconds() then
        row[#row + 1] = secondsLabel(15)
    end
    return ui.column({ width = rootWidth(), gap = 0, padding = 4, align = "center" }, {
        ui.row({ gap = 2, align = "end", justify = "center" }, row),
    })
end

local function render()
    if STYLE == "stacked" then
        desktopWidget.render(stacked())
    elseif STYLE == "compact" then
        desktopWidget.render(compact())
    else
        desktopWidget.render(digital())
    end

    -- Wake on the next second or minute boundary so the display never lags
    -- behind by a full timer period.
    local now = noctalia.nowMs()
    local needsSeconds = SHOW_SECONDS or (STYLE ~= "stacked" and formatHasSeconds())
    local interval
    if needsSeconds then
        interval = 1000 - (now % 1000) + 20
    else
        interval = 60000 - (now % 60000) + 20
    end
    noctalia.setUpdateInterval(math.max(100, math.floor(interval)))
    desktopWidget.setWantsSecondTicks(needsSeconds)
end

return {
    start = render,
    update = render,
}
