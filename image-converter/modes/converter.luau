--!nonstrict
-- Image Converter desktop widget. Noctalia desktop widgets cannot receive OS
-- file drops, so the input is chosen in the widget settings and the card exposes
-- a Convert button. ImageMagick is preferred; FFmpeg is the fallback.

local util = require("../lib/util.luau")

local INPUT_SETTING = util.trim(noctalia.getConfig("converter_input") or "")
local FORMAT = tostring(noctalia.getConfig("converter_format") or "webp"):lower()
local SHOW_PREVIEW = noctalia.getConfig("converter_show_preview") ~= false
local WIDTH = util.clamp(tonumber(noctalia.getConfig("converter_width")) or 255, 200, 600)

local status = "idle"
local statusName = ""
local converting = false

local function inputPath()
    if INPUT_SETTING == "" then
        return nil
    end
    local path = noctalia.expandPath(INPUT_SETTING)
    if path == "" or not noctalia.fileExists(path) then
        return nil
    end
    local info = noctalia.fileInfo(path)
    if type(info) == "table" and info.isDir then
        return nil
    end
    return path
end

local function fileName(path)
    if not path then
        return ""
    end
    return path:match("([^/\\]+)$") or path
end

local function outputPath(input)
    local stem = input:gsub("%.[^./\\]+$", "")
    local output = stem .. "." .. FORMAT
    if output == input then
        output = stem .. "-converted." .. FORMAT
    end
    return output
end

local function statusText(input)
    if status == "converting" then
        return noctalia.tr("converter.converting")
    elseif status == "saved" then
        return noctalia.tr("converter.saved", { name = statusName })
    elseif status == "failed" then
        return noctalia.tr("converter.failed")
    elseif status == "missing" then
        return noctalia.tr("converter.no_input")
    end
    if input then
        return noctalia.tr("converter.ready")
    end
    return noctalia.tr("converter.no_input")
end

local function preview(input)
    if SHOW_PREVIEW and input then
        return ui.image({
            path = input,
            width = 64,
            height = 64,
            radius = 12,
            fit = "cover",
        })
    end
    return ui.column({
        width = 64,
        height = 64,
        fill = "surface_container_high",
        radius = 12,
        align = "center",
        justify = "center",
    }, {
        ui.glyph({ name = "image", size = 28, color = "on_surface_variant" }),
    })
end

local function render()
    local input = inputPath()
    local children = {
        ui.row({ gap = 10, align = "center" }, {
            preview(input),
            ui.column({ gap = 2, flexGrow = 1, align = "start" }, {
                ui.label({
                    text = noctalia.tr("converter.title"),
                    fontSize = 15,
                    fontWeight = "semibold",
                    color = "on_surface",
                    maxLines = 1,
                }),
                ui.label({
                    text = input and fileName(input) or noctalia.tr("converter.no_input"),
                    fontSize = 10,
                    color = "on_surface_variant",
                    maxLines = 1,
                }),
                ui.label({
                    text = noctalia.tr("converter.format") .. ": " .. FORMAT:upper(),
                    fontSize = 10,
                    color = "on_surface_variant",
                    maxLines = 1,
                }),
            }),
        }),
        ui.label({
            text = statusText(input),
            fontSize = 10,
            color = status == "failed" and "error" or "on_surface_variant",
            maxLines = 2,
        }),
        ui.row({ gap = 6, align = "center" }, {
            ui.button({
                text = noctalia.tr("converter.convert"),
                variant = "primary",
                controlSize = "sm",
                enabled = not converting and input ~= nil,
                onClick = "onConvert",
            }),
        }),
    }
    desktopWidget.render(ui.column({ width = WIDTH, gap = 7, padding = 8 }, children))
end

local function finish(ok, detail)
    converting = false
    if ok then
        status = "saved"
        statusName = detail or ""
    else
        status = "failed"
    end
    render()
end

local function runFfmpeg(input, output)
    if not noctalia.commandExists("ffmpeg") then
        finish(false)
        return
    end
    noctalia.runAsync({ "ffmpeg", "-y", "-i", input, output }, function(result)
        finish(result.exitCode == 0, fileName(output))
    end)
end

local function onConvert()
    if converting then
        return
    end
    local input = inputPath()
    if not input then
        status = "missing"
        render()
        return
    end

    local magick = nil
    if noctalia.commandExists("magick") then
        magick = "magick"
    elseif noctalia.commandExists("convert") then
        magick = "convert"
    end
    if not magick and not noctalia.commandExists("ffmpeg") then
        status = "failed"
        render()
        return
    end

    local output = outputPath(input)
    converting = true
    status = "converting"
    render()

    if magick then
        noctalia.runAsync({ magick, input, output }, function(result)
            if result.exitCode == 0 then
                finish(true, fileName(output))
            else
                runFfmpeg(input, output)
            end
        end)
    else
        runFfmpeg(input, output)
    end
end

local function start()
    noctalia.setUpdateInterval(5000)
    render()
end

return {
    start = start,
    update = render,
    onConvert = onConvert,
}
