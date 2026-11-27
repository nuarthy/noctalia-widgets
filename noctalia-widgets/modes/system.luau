--!nonstrict
-- System tile: CPU, RAM, battery, or all three.
--
-- The DMS collection shipped three separate widgets. Noctalia desktop widgets are
-- configured per instance, so one entry with a "metric" setting covers all three
-- and adds an "all" layout. CPU and RAM come from noctalia.systemStats(); the
-- battery comes from /sys/class/power_supply because the plugin API has no UPower
-- reader.

local util = require("../lib/util.luau")

local METRIC = noctalia.getConfig("system_metric") or "cpu"
local COLOR = noctalia.getConfig("system_color") or "primary"
local SHOW_DETAIL = noctalia.getConfig("system_show_detail") ~= false
local SHOW_BAR = noctalia.getConfig("system_show_bar") ~= false
local WARN = tonumber(noctalia.getConfig("system_warn_threshold")) or 90
local SHADOW = noctalia.getConfig("system_shadow") == true
local WIDTH = tonumber(noctalia.getConfig("system_width")) or 0

local function rootWidth()
    if WIDTH > 0 then
        return WIDTH
    elseif METRIC == "all" then
        return 230
    end
    return 150
end

local function label(props)
    return ui.label(util.withShadow(props, SHADOW))
end

local function readBattery()
    local entries = noctalia.listDir("/sys/class/power_supply") or {}
    local total = 0
    local count = 0
    local status = ""

    for _, name in ipairs(entries) do
        if tostring(name):match("^BAT") then
            local capacity = noctalia.readFile("/sys/class/power_supply/" .. name .. "/capacity")
            if type(capacity) == "string" and capacity ~= "" then
                total = total + (tonumber(util.trim(capacity)) or 0)
                count = count + 1
                local state = noctalia.readFile("/sys/class/power_supply/" .. name .. "/status")
                if type(state) == "string" and state ~= "" then
                    status = util.trim(state)
                end
            end
        end
    end

    if count == 0 then
        return nil
    end
    return {
        percent = util.clamp(total / count, 0, 100),
        status = status,
        charging = status == "Charging" or status == "Full",
    }
end

local function cpuColor(percent)
    if percent >= WARN then
        return "error"
    end
    return COLOR
end

local function batteryColor(percent, charging)
    if charging then
        return COLOR
    elseif percent <= 15 then
        return "error"
    elseif percent <= 35 then
        return "tertiary"
    end
    return COLOR
end

local function cpuDetail(cpu)
    if not SHOW_DETAIL or type(cpu) ~= "table" then
        return ""
    end
    local parts = {}
    if tonumber(cpu.tempC) then
        parts[#parts + 1] = tostring(util.round(cpu.tempC)) .. "°C"
    end
    if tonumber(cpu.freqMhz) and tonumber(cpu.freqMhz) > 0 then
        parts[#parts + 1] = string.format("%.1f GHz", tonumber(cpu.freqMhz) / 1000)
    end
    return table.concat(parts, " · ")
end

local function ramDetail(ram)
    if not SHOW_DETAIL or type(ram) ~= "table" then
        return ""
    end
    local used = tonumber(ram.usedMb) or 0
    local total = tonumber(ram.totalMb) or 0
    if total >= 1024 then
        return string.format("%.1f / %.1f GB", used / 1024, total / 1024)
    end
    return string.format("%d / %d MB", util.round(used), util.round(total))
end

local function bar(percent, color, width)
    return ui.progress({
        progress = util.clamp(percent, 0, 100) / 100,
        fill = color,
        track = "outline_variant/0.5",
        width = width,
        height = 5,
        radius = 3,
    })
end

local function singleView(glyph, name, percent, detail, color)
    local inner = rootWidth() - 12
    local children = {
        ui.row({ gap = 6, align = "center" }, {
            ui.glyph({ name = glyph, size = 14, color = color }),
            label({ text = name, fontSize = 11, fontWeight = "medium", color = "on_surface_variant", flexGrow = 1 }),
            detail ~= ""
                and label({ text = detail, fontSize = 9, color = "on_surface_variant", maxLines = 1 })
                or ui.spacer({}),
        }),
        ui.row({ gap = 0, align = "end" }, {
            label({
                text = tostring(util.round(percent)),
                fontSize = 42,
                fontWeight = "bold",
                color = color,
                maxLines = 1,
            }),
            label({ text = "%", fontSize = 16, fontWeight = "medium", color = color }),
        }),
    }
    if SHOW_BAR then
        children[#children + 1] = bar(percent, color, inner)
    end
    return ui.column({ width = rootWidth(), gap = 4, padding = 6, align = "stretch" }, children)
end

local function compactRow(glyph, name, percent, color)
    local children = { ui.row({ gap = 6, align = "center" }, {
        ui.glyph({ name = glyph, size = 12, color = color }),
        label({ text = name, fontSize = 10, color = "on_surface_variant", flexGrow = 1 }),
        label({ text = tostring(util.round(percent)) .. "%", fontSize = 11, fontWeight = "bold", color = color }),
    }) }
    if SHOW_BAR then
        children[#children + 1] = ui.progress({
            progress = util.clamp(percent, 0, 100) / 100,
            fill = color,
            track = "outline_variant/0.5",
            width = rootWidth() - 16,
            height = 3,
            radius = 2,
        })
    end
    return ui.column({ gap = 2 }, children)
end

local function messageView(title, detailText)
    local children = {
        ui.glyph({ name = "alert-circle", size = 24, color = "on_surface_variant" }),
        label({ text = title, fontSize = 12, fontWeight = "semibold", color = "on_surface", textAlign = "center" }),
    }
    if detailText ~= "" then
        children[#children + 1] = label({
            text = detailText,
            fontSize = 10,
            color = "on_surface_variant",
            textAlign = "center",
            maxLines = 3,
        })
    end
    return ui.column({ width = rootWidth(), gap = 6, padding = 12, align = "center" }, children)
end

local function render()
    local stats = METRIC ~= "battery" and noctalia.systemStats() or nil
    local battery = nil
    if METRIC == "battery" or METRIC == "all" then
        battery = readBattery()
    end

    if METRIC == "battery" then
        if battery == nil then
            desktopWidget.render(messageView(noctalia.tr("system.no_battery"), ""))
            return
        end
        local percent = battery.percent
        desktopWidget.render(singleView(
            util.batteryGlyph(percent, battery.charging),
            noctalia.tr("system.battery"),
            percent,
            SHOW_DETAIL and util.batteryStateText(battery.status) or "",
            batteryColor(percent, battery.charging)
        ))
        return
    end

    if stats == nil then
        desktopWidget.render(messageView(
            noctalia.tr("system.monitor_off"),
            noctalia.tr("system.monitor_off_hint")
        ))
        return
    end

    local cpu = stats.cpu or {}
    local ram = stats.ram or {}
    local cpuPercent = tonumber(cpu.usagePercent) or 0
    local ramPercent = tonumber(ram.usagePercent) or 0

    if METRIC == "cpu" then
        desktopWidget.render(singleView(
            "cpu",
            noctalia.tr("system.cpu"),
            cpuPercent,
            cpuDetail(cpu),
            cpuColor(cpuPercent)
        ))
        return
    end

    if METRIC == "ram" then
        desktopWidget.render(singleView(
            "database",
            noctalia.tr("system.ram"),
            ramPercent,
            ramDetail(ram),
            cpuColor(ramPercent)
        ))
        return
    end

    local rows = {
        compactRow("cpu", noctalia.tr("system.cpu"), cpuPercent, cpuColor(cpuPercent)),
        compactRow("database", noctalia.tr("system.ram"), ramPercent, cpuColor(ramPercent)),
    }
    if battery then
        rows[#rows + 1] = compactRow(
            util.batteryGlyph(battery.percent, battery.charging),
            noctalia.tr("system.battery"),
            battery.percent,
            batteryColor(battery.percent, battery.charging)
        )
    end
    desktopWidget.render(ui.column({ width = rootWidth(), gap = 7, padding = 8 }, rows))
end

local function start()
    -- CPU and RAM need a short sampling window; a battery-only tile does not.
    noctalia.setUpdateInterval(METRIC == "battery" and 30000 or 2000)
    render()
end

return {
    start = start,
    update = render,
}
