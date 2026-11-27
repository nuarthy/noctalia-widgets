--!nonstrict
-- World clock desktop widget: local time plus configured IANA zones.
--
-- The DMS original hard-coded Tokyo, Shenyang, New York and London and shelled
-- out to `TZ=... date`. Noctalia exposes formatTime(pattern, nil, timezone), so
-- the same offsets come straight from the host clock and the zone list is a
-- widget setting.

local util = require("../lib/util.luau")

local ZONES = util.parseZones(noctalia.getConfig("world_zones") or {})
local SHOW_LOCAL = noctalia.getConfig("world_show_local") ~= false
local SHOW_DATE = noctalia.getConfig("world_show_date") ~= false
local SHOW_GMT = noctalia.getConfig("world_show_gmt") ~= false
local DATE_FORMAT = noctalia.getConfig("world_date_format") or ""
if util.trim(DATE_FORMAT) == "" then
    DATE_FORMAT = "%A, %B %-d"
end
local TIME_FORMAT = noctalia.getConfig("world_time_format") or ""
local COLOR = noctalia.getConfig("world_color") or "primary"
local SECONDARY = noctalia.getConfig("world_secondary_color") or "on_surface_variant"
local SHADOW = noctalia.getConfig("world_shadow") == true
local WIDTH = util.clamp(tonumber(noctalia.getConfig("world_width")) or 300, 200, 800)
local COLUMNS = tonumber(noctalia.getConfig("world_columns")) == 1 and 1 or 2

local localLabel = util.trim(noctalia.getConfig("world_local_label") or "")
if localLabel == "" then
    local shellAddress = noctalia.getSetting("location.address")
    if type(shellAddress) == "string" then
        localLabel = util.trim(shellAddress)
    end
end
if localLabel == "" then
    localLabel = noctalia.tr("world.local")
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

local function formatHasSeconds()
    local format = timeFormat()
    return contains(format, "%S")
        or contains(format, "%T")
        or contains(format, "%r")
        or contains(format, "%X")
        or contains(format, "%c")
end

local function label(props)
    props.shadow = SHADOW
    return ui.label(props)
end

local function localView()
    local children = {
        ui.row({ gap = 4, align = "center" }, {
            ui.glyph({ name = "map-pin", size = 12, color = SECONDARY }),
            label({
                text = localLabel,
                fontSize = 11,
                color = SECONDARY,
                flexGrow = 1,
                maxLines = 1,
            }),
        }),
        label({
            text = noctalia.formatTime(timeFormat()),
            fontSize = 46,
            fontWeight = "bold",
            color = COLOR,
            textAlign = "end",
            maxLines = 1,
        }),
    }
    if SHOW_DATE then
        children[#children + 1] = label({
            text = noctalia.formatTime(DATE_FORMAT),
            fontSize = 11,
            color = SECONDARY,
            textAlign = "end",
            maxLines = 1,
        })
    end
    return ui.column({ gap = 0, align = "stretch" }, children)
end

local function zoneCell(zone, width)
    local valid = noctalia.isValidTimezone(zone.zone)
    local time = valid and noctalia.formatTime(timeFormat(), nil, zone.zone) or "--:--"
    return ui.column({ width = width, gap = 0, align = "start" }, {
        ui.row({ gap = 4, align = "center", width = width }, {
            label({
                text = zone.label,
                fontSize = 11,
                color = SECONDARY,
                flexGrow = 1,
                maxLines = 1,
            }),
            SHOW_GMT
                and label({
                    text = valid and util.gmtOffset(zone.zone) or "",
                    fontSize = 9,
                    color = SECONDARY,
                    maxLines = 1,
                })
                or ui.spacer({}),
        }),
        label({
            text = time,
            fontSize = 22,
            fontWeight = "semibold",
            color = COLOR,
            maxLines = 1,
        }),
    })
end

local function zonesView()
    local inner = WIDTH - 12
    local gap = 8
    local cellWidth = COLUMNS == 2 and math.floor((inner - gap) / 2) or inner
    local children = {}

    for index = 1, #ZONES, COLUMNS do
        local row = {}
        for offset = 0, COLUMNS - 1 do
            local zone = ZONES[index + offset]
            if zone then
                row[#row + 1] = zoneCell(zone, cellWidth)
            end
        end
        children[#children + 1] = ui.row({ gap = gap, align = "start", width = inner }, row)
    end

    return ui.column({ gap = 6, align = "stretch" }, children)
end

local function render()
    local children = {}
    if SHOW_LOCAL then
        children[#children + 1] = localView()
    end
    if #ZONES > 0 then
        if SHOW_LOCAL then
            children[#children + 1] = ui.separator({ spacing = 2, color = "outline_variant/0.4" })
        end
        children[#children + 1] = zonesView()
    elseif not SHOW_LOCAL then
        children[#children + 1] = label({
            text = noctalia.tr("world.no_zones"),
            fontSize = 11,
            color = SECONDARY,
            textAlign = "center",
            maxLines = 2,
        })
    end

    desktopWidget.render(ui.column({ width = WIDTH, gap = 6, padding = 6, align = "stretch" }, children))

    local now = noctalia.nowMs()
    if formatHasSeconds() then
        noctalia.setUpdateInterval(math.max(100, 1000 - (now % 1000) + 20))
        desktopWidget.setWantsSecondTicks(true)
    else
        noctalia.setUpdateInterval(math.max(100, 60000 - (now % 60000) + 20))
        desktopWidget.setWantsSecondTicks(false)
    end
end

return {
    start = render,
    update = render,
}
