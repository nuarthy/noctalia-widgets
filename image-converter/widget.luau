--!nonstrict
-- Card Image Converter desktop widget entry.
local impl = require("./modes/converter.luau")

function update()
    if impl.update then
        impl.update()
    end
end

function onConvert()
    if impl.onConvert then
        impl.onConvert()
    end
end

impl.start()
