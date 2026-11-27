--!nonstrict
-- Month calendar desktop widget.
--
-- A plain month grid, like the DMS original: previous/next month, today
-- highlighted, days outside the month dimmed. The week starts on Monday by
-- default; the grid is always six rows so the widget height stays stable.

local util = require("../lib/util.luau")

local WEEK_START = noctalia.getConfig("calendar_week_start") or "monday"
local WIDTH = util.clamp(tonumber(noctalia.getConfig("calendar_width")) or 270, 180, 520)
local COLOR = noctalia.getConfig("calendar_color") or "primary"
local TEXT_COLOR = noctalia.getConfig("calendar_text_color") or "on_surface"
local SHADOW = noctalia.getConfig("calendar_shadow") == true

local monthOffset = 0

local function label(props)
    return ui.label(util.withShadow(props, SHADOW))
end

local function shownMonth()
    local today = os.date("*t")
    local month = today.month + monthOffset
    local year = today.year + math.floor((month - 1) / 12)
    month = (month - 1) % 12 + 1
    return year, month
end

local function gridStart()
    local year, month = shownMonth()
    local first = os.time({ year = year, month = month, day = 1, hour = 12 })
    local weekday = tonumber(os.date("%w", first)) or 0
    local offset = WEEK_START == "monday" and (weekday + 6) % 7 or weekday
    return first - offset * 86400
end

local function dateLabel(day, inMonth, isToday)
    return ui.column({
        flexGrow = 1,
        height = 30,
        fill = isToday and COLOR or nil,
        radius = 6,
        align = "center",
        justify = "center",
    }, {
        label({
            text = tostring(day),
            fontSize = 10,
            fontWeight = isToday and "bold" or "normal",
            color = isToday and "on_primary" or TEXT_COLOR,
            opacity = inMonth and 1 or 0.35,
            textAlign = "center",
            maxLines = 1,
        }),
    })
end

local function weekdayHeader(inner, gap)
    local monday = os.time({ year = 2024, month = 1, day = 1, hour = 12 })
    local base = WEEK_START == "monday" and monday or monday - 86400
    local row = {}
    for index = 0, 6 do
        row[#row + 1] = label({
            text = noctalia.formatTime("%a", base + index * 86400),
            fontSize = 9,
            color = TEXT_COLOR,
            opacity = 0.55,
            flexGrow = 1,
            textAlign = "center",
            maxLines = 1,
        })
    end
    return ui.row({ gap = gap, align = "center", width = inner }, row)
end

local function monthTitle()
    local year, month = shownMonth()
    local first = os.time({ year = year, month = month, day = 1, hour = 12 })
    return noctalia.formatTime("%B %Y", first)
end

local function render()
    local year, month = shownMonth()
    local inner = WIDTH - 12
    local gap = 2
    local today = os.date("*t")
    local start = gridStart()

    local header = {
        label({
            text = monthTitle(),
            fontSize = 14,
            fontWeight = "semibold",
            color = TEXT_COLOR,
            flexGrow = 1,
            maxLines = 1,
        }),
        ui.button({
            glyph = "chevron-left",
            variant = "ghost",
            controlSize = "sm",
            onClick = "onPreviousMonth",
        }),
        ui.button({
            glyph = "chevron-right",
            variant = "ghost",
            controlSize = "sm",
            onClick = "onNextMonth",
        }),
    }
    if monthOffset ~= 0 then
        table.insert(header, 2, ui.button({
            text = noctalia.tr("calendar.today"),
            variant = "ghost",
            controlSize = "sm",
            onClick = "onToday",
        }))
    end

    local children = {
        ui.row({ gap = 4, align = "center", width = inner }, header),
        weekdayHeader(inner, gap),
    }

    for rowIndex = 0, 5 do
        local row = {}
        for columnIndex = 0, 6 do
            local timestamp = start + (rowIndex * 7 + columnIndex) * 86400
            local date = os.date("*t", timestamp)
            local inMonth = date.month == month and date.year == year
            local isToday = date.year == today.year and date.month == today.month and date.day == today.day
            row[#row + 1] = dateLabel(date.day, inMonth, isToday)
        end
        children[#children + 1] = ui.row({ gap = gap, align = "center", width = inner }, row)
    end

    desktopWidget.render(ui.column({ width = WIDTH, gap = 4, padding = 6, align = "stretch" }, children))

    local now = noctalia.nowMs()
    noctalia.setUpdateInterval(math.max(100, 60000 - (now % 60000) + 20))
end

local function onPreviousMonth()
    monthOffset -= 1
    render()
end

local function onNextMonth()
    monthOffset += 1
    render()
end

local function onToday()
    monthOffset = 0
    render()
end

return {
    start = render,
    update = render,
    onPreviousMonth = onPreviousMonth,
    onNextMonth = onNextMonth,
    onToday = onToday,
}
