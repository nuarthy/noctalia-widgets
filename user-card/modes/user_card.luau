--!nonstrict
-- User card desktop widget: avatar, name, uptime, weather and session actions.
--
-- The DMS original opened the DMS settings and power-menu panels. Noctalia has
-- equivalents over IPC: settings-toggle opens the shell settings window and
-- panel-toggle session opens the configured session menu (lock, suspend,
-- reboot, shut down). Lock goes through the same session path Noctalia uses.

local util = require("../lib/util.luau")

local NAME_OVERRIDE = util.trim(noctalia.getConfig("usercard_name") or "")
local AVATAR_OVERRIDE = util.trim(noctalia.getConfig("usercard_avatar") or "")
local SHOW_WEATHER = noctalia.getConfig("usercard_show_weather") ~= false
local SHOW_UPTIME = noctalia.getConfig("usercard_show_uptime") ~= false
local SHOW_ACTIONS = noctalia.getConfig("usercard_show_actions") ~= false
local COLOR = noctalia.getConfig("usercard_color") or "primary"
local SHADOW = noctalia.getConfig("usercard_shadow") == true
local WIDTH = util.clamp(tonumber(noctalia.getConfig("usercard_width")) or 330, 240, 800)

local USER = noctalia.getenv("USER") or ""
local HOME = noctalia.expandPath("~")
local weather = noctalia.state.get("nw.weather")

local function label(props)
    return ui.label(util.withShadow(props, SHADOW))
end

local function accountsInfo()
    if USER == "" then
        return nil, nil
    end
    local text = noctalia.readFile("/var/lib/AccountsService/users/" .. USER)
    if type(text) ~= "string" or text == "" then
        return nil, nil
    end
    local name = text:match("\nName=([^\n]*)") or text:match("^Name=([^\n]*)")
    local icon = text:match("\nIcon=([^\n]*)") or text:match("^Icon=([^\n]*)")
    return util.trim(name or ""), util.trim(icon or "")
end

local function passwdName()
    if USER == "" then
        return ""
    end
    local text = noctalia.readFile("/etc/passwd")
    if type(text) ~= "string" then
        return ""
    end
    for line in text:gmatch("[^\n]+") do
        local user, gecos = line:match("^([^:]*):[^:]*:[^:]*:[^:]*:([^:]*):")
        if user == USER and gecos then
            local name = util.trim(gecos:match("^([^,]*)") or "")
            if name ~= "" then
                return name
            end
        end
    end
    return ""
end

local function displayName()
    if NAME_OVERRIDE ~= "" then
        return NAME_OVERRIDE
    end
    local accountName = accountsInfo()
    if accountName and accountName ~= "" then
        return accountName
    end
    local systemName = passwdName()
    if systemName ~= "" then
        return systemName
    end
    if USER ~= "" then
        return USER
    end
    return "user"
end

local function avatarPath()
    if AVATAR_OVERRIDE ~= "" then
        local path = noctalia.expandPath(AVATAR_OVERRIDE)
        if noctalia.fileExists(path) then
            return path
        end
    end

    local _, icon = accountsInfo()
    if icon and icon ~= "" and (icon:sub(1, 1) == "/" or icon:sub(1, 1) == "~") then
        local path = noctalia.expandPath(icon)
        if noctalia.fileExists(path) then
            return path
        end
    end

    for _, candidate in ipairs({ HOME .. "/.face", HOME .. "/.face.icon" }) do
        if noctalia.fileExists(candidate) then
            return candidate
        end
    end
    return nil
end

local function firstCharacter(text)
    if text == nil or text == "" then
        return "?"
    end
    if type(text) == "string" and utf8 and utf8.len(text) then
        local nextOffset = utf8.offset(text, 2)
        if nextOffset then
            return text:sub(1, nextOffset - 1)
        end
    end
    return text:sub(1, 1)
end

local function avatarNode(name)
    local path = avatarPath()
    if path then
        return ui.image({ path = path, width = 76, height = 76, radius = 16, fit = "cover" })
    end
    return ui.column({
        width = 76,
        height = 76,
        fill = "surface_container_high",
        radius = 16,
        align = "center",
        justify = "center",
    }, {
        label({
            text = firstCharacter(name):upper(),
            fontSize = 30,
            fontWeight = "bold",
            color = COLOR,
            textAlign = "center",
        }),
    })
end

local function uptimeSeconds()
    local text = noctalia.readFile("/proc/uptime")
    if type(text) == "string" then
        local seconds = text:match("^(%d+)")
        if seconds then
            return tonumber(seconds)
        end
    end
    return nil
end

local function weatherRow()
    if not SHOW_WEATHER or type(weather) ~= "table" or weather.ok ~= true then
        return nil
    end
    local unit = util.unitSuffix(weather.units or "metric")
    local text = tostring(util.round(weather.temp)) .. unit .. "  " .. util.conditionText(weather.class)
    return ui.row({ gap = 4, align = "center" }, {
        ui.glyph({
            name = util.weatherGlyph(weather.class, weather.isDay ~= false),
            size = 12,
            color = COLOR,
        }),
        label({
            text = text,
            fontSize = 10,
            color = "on_surface_variant",
            flexGrow = 1,
            maxLines = 1,
        }),
    })
end

local function weatherDetailRow()
    if not SHOW_WEATHER or type(weather) ~= "table" or weather.ok ~= true then
        return nil
    end
    local units = weather.units or "metric"
    local function stat(glyph, text)
        return ui.row({ gap = 3, align = "center" }, {
            ui.glyph({ name = glyph, size = 9, color = "on_surface_variant" }),
            label({ text = text, fontSize = 9, color = "on_surface_variant", maxLines = 1 }),
        })
    end
    return ui.row({ gap = 6, align = "center" }, {
        stat("droplets", tostring(util.round(weather.humidity)) .. "%"),
        stat("wind", tostring(util.round(weather.wind)) .. " " .. util.windSuffix(units)),
        stat("umbrella", tostring(util.round(weather.precipProb)) .. "%"),
    })
end

local function actionButton(glyph, callback)
    return ui.button({
        glyph = glyph,
        variant = "secondary",
        controlSize = "sm",
        onClick = callback,
    })
end

local function contentColumn(name)
    local info = {
        label({
            text = name,
            fontSize = 17,
            fontWeight = "semibold",
            color = "on_surface",
            maxLines = 1,
        }),
    }

    if SHOW_UPTIME then
        local seconds = uptimeSeconds()
        if seconds then
            info[#info + 1] = ui.row({ gap = 4, align = "center" }, {
                ui.glyph({ name = "clock", size = 10, color = "on_surface_variant" }),
                label({
                    text = util.formatUptime(seconds),
                    fontSize = 10,
                    color = "on_surface_variant",
                    maxLines = 1,
                }),
            })
        end
    end

    local weatherLine = weatherRow()
    if weatherLine then
        info[#info + 1] = weatherLine
        local weatherDetails = weatherDetailRow()
        if weatherDetails then
            info[#info + 1] = weatherDetails
        end
    end

    if SHOW_ACTIONS then
        info[#info + 1] = ui.row({ gap = 5, align = "center" }, {
            actionButton("lock", "onLock"),
            actionButton("settings", "onSettings"),
            actionButton("power", "onPower"),
        })
    end

    return ui.column({ gap = 3, flexGrow = 1, align = "stretch" }, info)
end

local function render()
    local name = displayName()
    desktopWidget.render(ui.row({
        gap = 12,
        align = "center",
        width = WIDTH,
        padding = 6,
    }, {
        avatarNode(name),
        contentColumn(name),
    }))
end

local function onLock()
    util.exec({ "session", "lock" })
end

local function onSettings()
    util.exec({ "settings-toggle" })
end

local function onPower()
    util.exec({ "panel-toggle", "session" })
end

local function start()
    weather = noctalia.state.get("nw.weather") or weather
    noctalia.state.watch("nw.weather", function(value)
        weather = value
        render()
    end)
    noctalia.setUpdateInterval(30000)
    render()
end

return {
    start = start,
    update = render,
    onLock = onLock,
    onSettings = onSettings,
    onPower = onPower,
}
