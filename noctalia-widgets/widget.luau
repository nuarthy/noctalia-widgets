--!nonstrict
-- Desktop widget entry: one picker item with a Mode setting.
--
-- Noctalia labels every desktop widget from a plugin with the plugin's manifest
-- name, so seven separate entries would appear as seven identical rows in the
-- type picker. The entry therefore ships one mode-switched widget and loads the
-- selected mode's module. Each instance keeps its own settings.
--
-- Modules are required statically so `noctalia plugins lint` follows every one
-- and sees the settings each mode reads. A module's top-level code only defines
-- functions; start() is called for the selected mode and registers its watches.

local clock = require("./modes/clock.luau")
local weather = require("./modes/weather.luau")
local system = require("./modes/system.luau")
local media = require("./modes/media.luau")
local worldClock = require("./modes/world_clock.luau")
local calendar = require("./modes/calendar.luau")
local userCard = require("./modes/user_card.luau")

local MODES = {
    clock = clock,
    weather = weather,
    system = system,
    media = media,
    world_clock = worldClock,
    calendar = calendar,
    user_card = userCard,
}

local impl = MODES[noctalia.getConfig("mode") or "clock"] or MODES.clock

function update()
    if impl.update then
        impl.update()
    end
end

function onRefresh()
    if impl.onRefresh then
        impl.onRefresh()
    end
end

function onPrevious()
    if impl.onPrevious then
        impl.onPrevious()
    end
end

function onToggle()
    if impl.onToggle then
        impl.onToggle()
    end
end

function onNext()
    if impl.onNext then
        impl.onNext()
    end
end

function onPreviousMonth()
    if impl.onPreviousMonth then
        impl.onPreviousMonth()
    end
end

function onNextMonth()
    if impl.onNextMonth then
        impl.onNextMonth()
    end
end

function onToday()
    if impl.onToday then
        impl.onToday()
    end
end

function onLock()
    if impl.onLock then
        impl.onLock()
    end
end

function onSettings()
    if impl.onSettings then
        impl.onSettings()
    end
end

function onPower()
    if impl.onPower then
        impl.onPower()
    end
end

impl.start()
