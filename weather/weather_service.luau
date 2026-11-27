--!nonstrict
-- Weather service for this plugin's weather consumer.
--
-- The widget and service are separate Luau VMs, so they cannot share Lua memory.
-- This headless entry owns the network work and publishes one snapshot on
-- "nw.weather"; the widget watches it. A manual refresh is requested by bumping
-- "nw.weather.refresh".
--
-- The last successful snapshot is cached in the plugin data directory, so a
-- restart or an offline start still shows the previous data (marked stale).

local util = require("./lib/util.luau")

local REFRESH_MINUTES = math.max(5, tonumber(noctalia.getConfig("weather_refresh")) or 15)
local UNITS = noctalia.getConfig("weather_units") or "metric"
local CACHE_FILE = "weather-cache.json"
local CACHE_VERSION = 1

local LOCATION = util.trim(noctalia.getConfig("weather_location") or "")
if LOCATION == "" then
    local shellAddress = noctalia.getSetting("location.address")
    if type(shellAddress) == "string" then
        LOCATION = util.trim(shellAddress)
    end
end
if LOCATION == "" then
    LOCATION = "Jakarta"
end

local CITY = LOCATION
local coords = nil
local fetching = false
local fetchStartedMs = 0
local lastSuccessMs = 0

local function dataDir()
    local dir = noctalia.pluginDataDir()
    if dir and dir ~= "" then
        noctalia.mkdirAll(dir)
        return dir
    end
    return nil
end

local function cachePath()
    local dir = dataDir()
    if dir then
        return dir .. "/" .. CACHE_FILE
    end
    return nil
end

local function cacheKey()
    return table.concat({ CACHE_VERSION, LOCATION, UNITS }, "|")
end

local function publish(payload)
    payload.units = UNITS
    payload.city = payload.city or CITY
    payload.updatedMs = payload.updatedMs or noctalia.nowMs()
    noctalia.state.set("nw.weather", payload)
end

local function fail(message)
    noctalia.log("[widgets] weather: " .. tostring(message))
    local previous = noctalia.state.get("nw.weather")
    if type(previous) == "table" and previous.ok == true then
        local kept = {}
        for key, value in pairs(previous) do
            kept[key] = value
        end
        kept.stale = true
        kept.error = message
        publish(kept)
    else
        publish({ ok = false, error = message, city = CITY })
    end
end

local function writeCache(payload)
    local path = cachePath()
    if not path then
        return
    end
    local encoded = noctalia.json.encode({
        version = CACHE_VERSION,
        key = cacheKey(),
        coords = coords,
        payload = payload,
    })
    if encoded then
        noctalia.writeFile(path, encoded)
    end
end

local function loadCache()
    local path = cachePath()
    if not path then
        return
    end
    local text = noctalia.readFile(path)
    if type(text) ~= "string" or text == "" then
        return
    end
    local cached = noctalia.json.decode(text)
    if type(cached) ~= "table" or cached.key ~= cacheKey() then
        return
    end
    if type(cached.coords) == "table" then
        local lat = tonumber(cached.coords.lat)
        local lon = tonumber(cached.coords.lon)
        if lat ~= nil and lon ~= nil then
            coords = { lat = lat, lon = lon, name = cached.coords.name }
        end
    end
    if type(cached.payload) == "table" then
        local payload = cached.payload
        payload.stale = true
        publish(payload)
    end
end

local function requestForecast()
    local url = table.concat({
        "https://api.open-meteo.com/v1/forecast?latitude=" .. tostring(coords.lat),
        "longitude=" .. tostring(coords.lon),
        "current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m,wind_direction_10m",
        "daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max",
        "forecast_days=6",
        "timezone=auto",
        UNITS == "imperial"
            and "temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch"
            or "wind_speed_unit=kmh&precipitation_unit=mm",
    }, "&")

    noctalia.http({ url = url, headers = { "User-Agent: noctalia-widgets" } }, function(response)
        fetching = false
        if not response.ok then
            fail("network unavailable")
            return
        end
        if response.status ~= 200 then
            fail("HTTP " .. tostring(response.status))
            return
        end

        local data = noctalia.json.decode(response.body)
        if type(data) ~= "table" then
            fail("invalid forecast response")
            return
        end

        local current = data.current or {}
        local daily = data.daily or {}
        local forecast = {}
        for index, date in ipairs(daily.time or {}) do
            local year, month, day = tostring(date):match("^(%d+)-(%d+)-(%d+)$")
            local dayName = tostring(date)
            if year then
                local epoch = os.time({
                    year = tonumber(year),
                    month = tonumber(month),
                    day = tonumber(day),
                    hour = 12,
                })
                dayName = os.date("%a", epoch)
            end

            local code = tonumber((daily.weather_code or {})[index]) or 0
            forecast[#forecast + 1] = {
                date = tostring(date),
                day = dayName,
                code = code,
                class = util.weatherClass(code),
                hi = tonumber((daily.temperature_2m_max or {})[index]) or 0,
                lo = tonumber((daily.temperature_2m_min or {})[index]) or 0,
                precipProb = tonumber((daily.precipitation_probability_max or {})[index]) or 0,
            }
        end

        local code = tonumber(current.weather_code) or 0
        local isDay = current.is_day == 1 or current.is_day == true
        local today = forecast[1] or {}
        lastSuccessMs = noctalia.nowMs()

        local payload = {
            ok = true,
            stale = false,
            city = coords.name or CITY,
            latitude = coords.lat,
            longitude = coords.lon,
            temp = tonumber(current.temperature_2m) or 0,
            feels = tonumber(current.apparent_temperature) or tonumber(current.temperature_2m) or 0,
            code = code,
            class = util.weatherClass(code),
            isDay = isDay,
            humidity = tonumber(current.relative_humidity_2m) or 0,
            wind = tonumber(current.wind_speed_10m) or 0,
            windDir = tonumber(current.wind_direction_10m) or 0,
            precip = tonumber(current.precipitation) or 0,
            precipProb = today.precipProb or 0,
            hi = today.hi or 0,
            lo = today.lo or 0,
            forecast = forecast,
            updatedMs = lastSuccessMs,
        }
        publish(payload)
        writeCache(payload)
    end)
end

local function geocode(query)
    local url = "https://geocoding-api.open-meteo.com/v1/search?name="
        .. noctalia.string.urlEncode(query)
        .. "&count=1&language=en&format=json"

    noctalia.http({ url = url, headers = { "User-Agent: noctalia-widgets" } }, function(response)
        if not response.ok then
            fetching = false
            fail("network unavailable")
            return
        end
        if response.status ~= 200 then
            fetching = false
            fail("HTTP " .. tostring(response.status))
            return
        end
        local data = noctalia.json.decode(response.body)
        local result = type(data) == "table" and type(data.results) == "table" and data.results[1] or nil
        if type(result) ~= "table" then
            fetching = false
            fail("location not found")
            return
        end
        local lat = tonumber(result.latitude)
        local lon = tonumber(result.longitude)
        if lat == nil or lon == nil then
            fetching = false
            fail("location not found")
            return
        end
        coords = {
            lat = lat,
            lon = lon,
            name = result.name or query,
        }
        CITY = coords.name
        requestForecast()
    end)
end

local function parseCoordinates(text)
    local lat, lon = tostring(text):match("^%s*(-?%d+%.?%d*)%s*,%s*(-?%d+%.?%d*)%s*$")
    if lat and lon then
        return { lat = tonumber(lat), lon = tonumber(lon), name = noctalia.tr("world.local") }
    end
    return nil
end

local function fetch(force)
    local now = noctalia.nowMs()
    if fetching and now - fetchStartedMs < 60000 then
        return
    end
    if not force and now - lastSuccessMs < 5000 then
        return
    end
    fetching = true
    fetchStartedMs = now

    if coords == nil then
        coords = parseCoordinates(LOCATION)
    end
    if coords then
        requestForecast()
    else
        geocode(LOCATION)
    end
end

function update()
    fetch(false)
end

noctalia.state.watch("nw.weather.refresh", function()
    fetch(true)
end)

loadCache()
noctalia.setUpdateInterval(REFRESH_MINUTES * 60000)
fetch(true)
