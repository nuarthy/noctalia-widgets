--!nonstrict
-- Shared formatting and weather-code helpers. Every widget requires this module,
-- so it must not read plugin settings: each entry has its own settings scope.

local M = {}

function M.clamp(value, low, high)
    if value < low then
        return low
    end
    if value > high then
        return high
    end
    return value
end

function M.round(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

function M.trim(text)
    local out = tostring(text or ""):gsub("^%s+", "")
    out = out:gsub("%s+$", "")
    return out
end

-- "Tokyo=Asia/Tokyo" or "Asia/Tokyo" -> { label = "Tokyo", zone = "Asia/Tokyo" }
function M.parseZones(entries)
    local out = {}
    for _, raw in ipairs(entries or {}) do
        local line = M.trim(raw)
        if line ~= "" then
            local label, zone = line:match("^(.-)%s*=%s*(.+)$")
            if not zone then
                zone = line
                label = ""
            end
            zone = M.trim(zone)
            label = M.trim(label)
            if label == "" then
                label = M.autoLabel(zone)
            end
            out[#out + 1] = { label = label, zone = zone }
        end
    end
    return out
end

-- "America/New_York" -> "New York"; "UTC" -> "UTC".
function M.autoLabel(zone)
    local name = tostring(zone or "")
    local tail = name:match("([^/]+)$")
    if tail and tail ~= "" then
        name = tail
    end
    name = name:gsub("_", " ")
    return name
end

-- WMO weather interpretation codes used by Open-Meteo.
function M.weatherClass(code)
    local value = tonumber(code) or -1
    if value == 0 then
        return "clear"
    elseif value == 1 then
        return "mainly_clear"
    elseif value == 2 then
        return "partly"
    elseif value == 3 then
        return "overcast"
    elseif value == 45 or value == 48 then
        return "fog"
    elseif value == 51 or value == 53 or value == 55 then
        return "drizzle"
    elseif value == 56 or value == 57 then
        return "freezing"
    elseif value == 61 or value == 63 or value == 65 then
        return "rain"
    elseif value == 66 or value == 67 then
        return "freezing"
    elseif value == 71 or value == 73 or value == 75 or value == 77 then
        return "snow"
    elseif value == 80 or value == 81 or value == 82 then
        return "showers"
    elseif value == 85 or value == 86 then
        return "snow"
    elseif value == 95 or value == 96 or value == 99 then
        return "storm"
    end
    return "overcast"
end

-- Noctalia glyph names; the host maps the weather-* aliases to Tabler icons.
function M.weatherGlyph(class, isDay)
    if class == "clear" then
        return isDay and "weather-sun" or "weather-moon"
    elseif class == "mainly_clear" then
        return isDay and "weather-sun" or "weather-moon-stars"
    elseif class == "partly" then
        return isDay and "weather-cloud-sun" or "weather-cloud"
    elseif class == "fog" then
        return "weather-cloud-haze"
    elseif class == "drizzle" or class == "rain" or class == "showers" then
        return "weather-cloud-rain"
    elseif class == "freezing" or class == "snow" then
        return "weather-cloud-snow"
    elseif class == "storm" then
        return "weather-cloud-lightning"
    end
    return "weather-cloud"
end

function M.conditionText(class)
    return noctalia.tr("weather.condition." .. (class or "overcast"))
end

function M.unitSuffix(units)
    return units == "imperial" and "°F" or "°C"
end

function M.windSuffix(units)
    return units == "imperial" and "mph" or "km/h"
end

-- "+0900" -> "GMT+9", "-0430" -> "GMT-4:30", "+0000" -> "GMT"
function M.gmtOffset(zone)
    local offset
    if zone == nil or zone == "" then
        offset = noctalia.formatTime("%z")
    else
        offset = noctalia.formatTime("%z", nil, zone)
    end
    local sign, hours, minutes = tostring(offset or ""):match("^([+-])(%d%d)(%d%d)$")
    if not sign then
        return ""
    end
    local hour = tonumber(hours) or 0
    if hour == 0 and minutes == "00" then
        return "GMT"
    end
    if minutes == "00" then
        return "GMT" .. sign .. tostring(hour)
    end
    return "GMT" .. sign .. tostring(hour) .. ":" .. minutes
end

function M.formatDuration(milliseconds)
    local total = math.max(0, math.floor((tonumber(milliseconds) or 0) / 1000))
    local hours = math.floor(total / 3600)
    local minutes = math.floor((total % 3600) / 60)
    local seconds = total % 60
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, seconds)
    end
    return string.format("%d:%02d", minutes, seconds)
end

function M.formatUptime(seconds)
    local total = math.max(0, math.floor(tonumber(seconds) or 0))
    local days = math.floor(total / 86400)
    local hours = math.floor((total % 86400) / 3600)
    local minutes = math.floor((total % 3600) / 60)
    local parts = {}
    if days > 0 then
        parts[#parts + 1] = noctalia.tr("usercard.days", { count = days })
    end
    if hours > 0 then
        parts[#parts + 1] = noctalia.tr("usercard.hours", { count = hours })
    end
    if #parts == 0 then
        parts[#parts + 1] = noctalia.tr("usercard.minutes", { count = minutes })
    end
    return table.concat(parts, " ")
end

function M.ago(milliseconds)
    local elapsed = math.max(0, math.floor((tonumber(milliseconds) or 0) / 1000))
    if elapsed < 60 then
        return noctalia.tr("weather.now")
    elseif elapsed < 3600 then
        return noctalia.tr("weather.minutes_ago", { count = math.floor(elapsed / 60) })
    end
    return noctalia.tr("weather.hours_ago", { count = math.floor(elapsed / 3600) })
end

function M.batteryGlyph(percent, charging)
    if charging then
        return "battery-charging"
    end
    local value = tonumber(percent) or 0
    if value >= 90 then
        return "battery-4"
    elseif value >= 65 then
        return "battery-3"
    elseif value >= 35 then
        return "battery-2"
    elseif value >= 10 then
        return "battery-1"
    end
    return "battery"
end

function M.batteryStateText(status)
    local state = tostring(status or "")
    if state == "Charging" then
        return noctalia.tr("system.charging")
    elseif state == "Discharging" then
        return noctalia.tr("system.discharging")
    elseif state == "Full" then
        return noctalia.tr("system.full")
    elseif state == "Not charging" then
        return noctalia.tr("system.not_charging")
    end
    return state
end

-- Short stable hash used for downloaded artwork file names.
function M.hash(text)
    local value = 5381
    local source = tostring(text or "")
    for index = 1, #source do
        value = (value * 33 + string.byte(source, index)) % 4294967296
    end
    return tostring(value)
end

function M.exec(command)
    local argv = { "noctalia", "msg" }
    for _, part in ipairs(command) do
        argv[#argv + 1] = part
    end
    noctalia.runAsync(argv)
end

return M
