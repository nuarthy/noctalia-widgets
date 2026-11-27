--!nonstrict
-- Card Media desktop widget entry.
local impl = require("./modes/media.luau")

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
