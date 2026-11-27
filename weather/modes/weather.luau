--!nonstrict
-- Weather desktop widget. The headless weather service does the network work and
-- publishes "nw.weather"; this widget only renders that snapshot.
--
-- Refreshing is a request to the service (bump "nw.weather.refresh"), so a click
-- here and a click on the user card share one request.

local util = require("../lib/util.luau")

local SHOW_FORECAST = noctalia.getConfig("weather_show_forecast") ~= false
local FORECAST_DAYS = util.clamp(tonumber(noctalia.getConfig("weather_forecast_days")) or 3, 1, 6)
local SHOW_DETAILS = noctalia.getConfig("weather_show_details") ~= false
local SHOW_FEELS = noctalia.getConfig("weather_show_feels") ~= false
local COLOR = noctalia.getConfig("weather_color") or "primary"
local SHADOW = noctalia.getConfig("weather_shadow") == true
local WIDTH = util.clamp(tonumber(noctalia.getConfig("weather_width")) or 280, 240, 640)

local data = noctalia.state.get("nw.weather")

local function label(props)
    return ui.label(util.withShadow(props, SHADOW))
end

local function refresh()
    local value = noctalia.state.get("nw.weather.refresh") or 0
    noctalia.state.set("nw.weather.refresh", value + 1)
end

local function detail(glyph, value, caption)
    return ui.column({ gap = 1, flexGrow = 1, align = "start" }, {
        ui.row({ gap = 3, align = "center" }, {
            ui.glyph({ name = glyph, size = 12, color = "on_surface_variant" }),
            label({ text = value, fontSize = 12, fontWeight = "semibold", color = "on_surface" }),
        }),
        label({ text = caption, fontSize = 10, color = "on_surface_variant" }),
    })
end

local function forecastRow(days)
    local small = math.min(#days, FORECAST_DAYS) > 4
    local valueSize = small and 10 or 11
    local children = {}
    for index, day in ipairs(days) do
        if index > FORECAST_DAYS then
            break
        end
        children[#children + 1] = ui.column({ gap = 1, flexGrow = 1, align = "center" }, {
            label({ text = day.day or "", fontSize = 10, color = "on_surface_variant" }),
            ui.glyph({
                name = util.weatherGlyph(day.class, true),
                size = 18,
                color = COLOR,
            }),
            ui.row({ gap = 3, align = "center", justify = "center" }, {
                label({
                    text = tostring(util.round(day.hi)) .. "°",
                    fontSize = valueSize,
                    fontWeight = "semibold",
                    color = "on_surface",
                }),
                label({
                    text = tostring(util.round(day.lo)) .. "°",
                    fontSize = valueSize,
                    color = "on_surface_variant",
                }),
            }),
        })
    end
    return ui.row({ gap = 4, align = "center", justify = "space_between" }, children)
end

local function contentView()
    local units = data.units or "metric"
    local unit = util.unitSuffix(units)
    local condition = util.conditionText(data.class or util.weatherClass(data.code))
    local children = {
        ui.row({ gap = 10, align = "center" }, {
            ui.glyph({
                name = util.weatherGlyph(data.class or util.weatherClass(data.code), data.isDay ~= false),
                size = 40,
                color = COLOR,
            }),
            ui.column({ gap = 0, flexGrow = 1, align = "stretch" }, {
                ui.row({ gap = 2, align = "end" }, {
                    label({
                        text = tostring(util.round(data.temp)),
                        fontSize = 38,
                        fontWeight = "bold",
                        color = COLOR,
                        maxLines = 1,
                    }),
                    label({ text = unit, fontSize = 14, fontWeight = "medium", color = "on_surface_variant" }),
                }),
                label({ text = condition, fontSize = 13, fontWeight = "medium", color = "on_surface_variant", maxLines = 1 }),
            }),
            ui.button({
                glyph = "refresh",
                variant = "ghost",
                controlSize = "sm",
                onClick = "onRefresh",
            }),
        }),
        ui.row({ gap = 4, align = "center" }, {
            ui.glyph({ name = "map-pin", size = 12, color = "on_surface_variant" }),
            label({
                text = tostring(data.city or ""),
                fontSize = 11,
                color = "on_surface_variant",
                flexGrow = 1,
                maxLines = 1,
            }),
            SHOW_FEELS
                and label({
                    text = noctalia.tr("weather.feels", { temp = tostring(util.round(data.feels)) .. unit }),
                    fontSize = 11,
                    color = "on_surface_variant",
                    maxLines = 1,
                })
                or ui.spacer({}),
        }),
    }

    if SHOW_DETAILS then
        children[#children + 1] = ui.row({ gap = 8, align = "center" }, {
            detail("droplets", tostring(util.round(data.humidity)) .. "%", noctalia.tr("weather.humidity")),
            detail(
                "wind",
                tostring(util.round(data.wind)) .. " " .. util.windSuffix(units),
                noctalia.tr("weather.wind")
            ),
            detail("umbrella", tostring(util.round(data.precipProb)) .. "%", noctalia.tr("weather.precip")),
        })
    end

    if SHOW_FORECAST and type(data.forecast) == "table" and #data.forecast > 0 then
        children[#children + 1] = ui.separator({ spacing = 2, color = "outline_variant/0.4" })
        children[#children + 1] = forecastRow(data.forecast)
    end

    local age = label({
        text = noctalia.tr("weather.updated", { age = util.ago(noctalia.nowMs() - (tonumber(data.updatedMs) or 0)) }),
        fontSize = 9,
        color = "on_surface_variant",
    })
    if type(data.error) == "string" and data.error ~= "" then
        children[#children + 1] = ui.row({ gap = 3, align = "center" }, {
            ui.glyph({ name = "alert-circle", size = 10, color = "error" }),
            label({ text = data.error, fontSize = 9, color = "error", flexGrow = 1, maxLines = 1 }),
            age,
        })
    else
        children[#children + 1] = age
    end

    return ui.column({ width = WIDTH, gap = 6, padding = 6, align = "stretch" }, children)
end

local function messageView(glyph, title, detailText, showButton)
    local children = {
        ui.glyph({ name = glyph, size = 30, color = "on_surface_variant" }),
        label({
            text = title,
            fontSize = 15,
            fontWeight = "semibold",
            color = "on_surface",
            textAlign = "center",
        }),
    }
    if detailText and detailText ~= "" then
        children[#children + 1] = label({
            text = detailText,
            fontSize = 11,
            color = "on_surface_variant",
            textAlign = "center",
            maxLines = 2,
        })
    end
    if showButton then
        children[#children + 1] = ui.button({
            text = noctalia.tr("weather.refresh"),
            glyph = "refresh",
            variant = "secondary",
            controlSize = "sm",
            onClick = "onRefresh",
        })
    end
    return ui.column({ width = WIDTH, gap = 8, padding = 12, align = "center" }, children)
end

local function render()
    if type(data) ~= "table" then
        desktopWidget.render(messageView("cloud", noctalia.tr("weather.loading"), "", false))
        return
    end
    if data.ok ~= true then
        desktopWidget.render(messageView(
            "cloud-off",
            noctalia.tr("weather.unavailable"),
            tostring(data.error or ""),
            true
        ))
        return
    end
    desktopWidget.render(contentView())
end

local function onRefresh()
    refresh()
end

local function start()
    data = noctalia.state.get("nw.weather") or data
    noctalia.state.watch("nw.weather", function(value)
        data = value
        render()
    end)
    noctalia.setUpdateInterval(60000)
    render()
end

return {
    start = start,
    update = render,
    onRefresh = onRefresh,
}
