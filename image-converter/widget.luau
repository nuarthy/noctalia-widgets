--!nonstrict
-- Card Image Converter desktop widget entry.
local impl = require("./modes/converter.luau")

function update()
    if impl.update then
        impl.update()
    end
end

function onChooseImage()
    if impl.onChooseImage then
        impl.onChooseImage()
    end
end

function onPrevFormat()
    if impl.onPrevFormat then
        impl.onPrevFormat()
    end
end

function onNextFormat()
    if impl.onNextFormat then
        impl.onNextFormat()
    end
end

impl.start()
