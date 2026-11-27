--!nonstrict
-- Image Converter desktop widget. Noctalia has no OS file-drop API, so the
-- drop-style area opens a native file picker instead and converts immediately.
-- Two arrows change the target format; the result is written next to the input,
-- with ~/Pictures/Converted as the fallback directory.

local util = require("../lib/util.luau")

local FALLBACK_DIR = util.trim(noctalia.getConfig("converter_fallback_dir") or "")
if FALLBACK_DIR == "" then
    FALLBACK_DIR = "~/Pictures/Converted"
end
local WIDTH = util.clamp(tonumber(noctalia.getConfig("converter_width")) or 255, 200, 600)

local FORMATS = { "webp", "png", "jpg", "avif" }
local formatIndex = 1
local currentInput = nil
local status = "idle"
local statusName = ""
local converting = false
local resetAt = nil
local updateInterval = 0
local render

local function setInterval(value)
    if value ~= updateInterval then
        updateInterval = value
        noctalia.setUpdateInterval(value)
    end
end

local function currentFormat()
    return FORMATS[formatIndex]
end

local function fileName(path)
    if not path then
        return ""
    end
    return path:match("([^/\\]+)$") or path
end

local function splitPath(path)
    local dir, name = path:match("^(.*)/([^/]+)$")
    if not dir then
        return "", path
    end
    return dir, name
end

local function fallbackDir()
    local dir = noctalia.expandPath(FALLBACK_DIR)
    if dir ~= "" then
        noctalia.mkdirAll(dir)
    end
    return dir
end

local function outputPath(input, format, fallback)
    local dir, name = splitPath(input)
    local stem = name:gsub("%.[^%.]+$", "")
    local outputName = stem .. "." .. format
    if outputName == name then
        outputName = stem .. "-converted." .. format
    end
    if fallback then
        dir = fallbackDir()
    end
    if dir == "" then
        return "/" .. outputName
    end
    return dir .. "/" .. outputName
end

local function statusText()
    if status == "converting" then
        return noctalia.tr("converter.converting")
    elseif status == "saved" then
        return noctalia.tr("converter.saved", { name = statusName })
    elseif status == "saved_fallback" then
        return noctalia.tr("converter.saved_fallback", { name = statusName })
    elseif status == "failed" then
        return noctalia.tr("converter.failed")
    elseif status == "no_picker" then
        return noctalia.tr("converter.no_picker")
    end
    if currentInput then
        return noctalia.tr("converter.selected", { name = fileName(currentInput) })
    end
    return noctalia.tr("converter.choose")
end

local function pickerCommand()
    local filter = "Images | *.png *.jpg *.jpeg *.webp *.avif *.gif *.bmp *.tif *.tiff"
    local title = noctalia.tr("converter.choose_title")
    if noctalia.commandExists("zenity") then
        return { "zenity", "--file-selection", "--title=" .. title, "--file-filter=" .. filter }
    elseif noctalia.commandExists("kdialog") then
        return {
            "kdialog",
            "--getopenfilename",
            noctalia.expandPath("~"),
            "Images (*.png *.jpg *.jpeg *.webp *.avif *.gif *.bmp *.tif *.tiff)",
        }
    elseif noctalia.commandExists("yad") then
        return { "yad", "--file-selection", "--title=" .. title, "--file-filter=" .. filter }
    end
    return nil
end

local function magickCommand()
    if noctalia.commandExists("magick") then
        return "magick"
    elseif noctalia.commandExists("convert") then
        return "convert"
    end
    return nil
end

local function runTool(tool, input, output, done)
    local argv
    if tool == "ffmpeg" then
        argv = { "ffmpeg", "-y", "-i", input, output }
    else
        argv = { tool, input, output }
    end
    -- Conversion uses the same command timeout as any callback runAsync call.
    -- Give large images the maximum Noctalia allows instead of the 5s default.
    noctalia.runAsync(argv, function(result)
        done(result.exitCode == 0 and noctalia.fileExists(output))
    end, 60000)
end

local function tryTools(input, output, done)
    local tools = {}
    local magick = magickCommand()
    if magick then
        tools[#tools + 1] = magick
    end
    if noctalia.commandExists("ffmpeg") then
        tools[#tools + 1] = "ffmpeg"
    end

    local index = 1
    local function nextTool()
        if index > #tools then
            done(false)
            return
        end
        local tool = tools[index]
        index = index + 1
        runTool(tool, input, output, function(ok)
            if ok then
                done(true)
            else
                nextTool()
            end
        end)
    end
    nextTool()
end

local function finish(ok, name, fallback)
    converting = false
    if ok then
        status = fallback and "saved_fallback" or "saved"
        statusName = name or ""
    else
        status = "failed"
    end
    resetAt = noctalia.nowMs() + 5000
    setInterval(1000)
    render()
end

local function convertCurrent()
    if converting then
        return
    end
    if not currentInput or not noctalia.fileExists(currentInput) then
        status = "failed"
        render()
        return
    end

    local format = currentFormat()
    local primary = outputPath(currentInput, format, false)
    converting = true
    resetAt = nil
    status = "converting"
    render()

    tryTools(currentInput, primary, function(ok)
        if ok then
            finish(true, fileName(primary), false)
            return
        end
        local fallback = outputPath(currentInput, format, true)
        tryTools(currentInput, fallback, function(fallbackOk)
            finish(fallbackOk, fallbackOk and fileName(fallback) or "", true)
        end)
    end)
end

local function onChooseImage()
    if converting then
        return
    end
    local argv = pickerCommand()
    if not argv then
        status = "no_picker"
        resetAt = noctalia.nowMs() + 5000
        setInterval(1000)
        render()
        return
    end
    -- runAsync() kills a callback process after 5s by default. A file picker can
    -- easily stay open longer, so keep it alive for the 60s maximum.
    noctalia.runAsync(argv, function(result)
        if result.exitCode ~= 0 then
            return
        end
        local path = util.trim(result.stdout)
        if path == "" or not noctalia.fileExists(path) then
            return
        end
        currentInput = path
        status = "idle"
        convertCurrent()
    end, 60000)
end

local function onPrevFormat()
    if converting then
        return
    end
    formatIndex = ((formatIndex - 2) % #FORMATS) + 1
    render()
end

local function onNextFormat()
    if converting then
        return
    end
    formatIndex = (formatIndex % #FORMATS) + 1
    render()
end

render = function()
    local color = status == "failed" and "error" or "on_surface_variant"
    local format = currentFormat():upper()
    desktopWidget.render(ui.column({ width = WIDTH, gap = 8, padding = 6 }, {
        ui.column({
            width = WIDTH - 12,
            height = 150,
            fill = "surface_container/0.25",
            border = "outline_variant",
            borderWidth = 1,
            radius = 12,
            align = "center",
            justify = "center",
            gap = 6,
            onClick = "onChooseImage",
        }, {
            ui.glyph({ name = "image", size = 34, color = "on_surface_variant" }),
            ui.label({
                text = statusText(),
                fontSize = 11,
                color = color,
                maxLines = 2,
                textAlign = "center",
            }),
        }),
        ui.row({
            width = WIDTH - 12,
            gap = 6,
            align = "center",
            justify = "space_between",
        }, {
            ui.button({
                glyph = "chevron-left",
                variant = "primary",
                controlSize = "sm",
                onClick = "onPrevFormat",
            }),
            ui.label({
                text = noctalia.tr("converter.format") .. ": " .. format,
                fontSize = 11,
                color = "on_surface_variant",
                flexGrow = 1,
                textAlign = "center",
                maxLines = 1,
            }),
            ui.button({
                glyph = "chevron-right",
                variant = "primary",
                controlSize = "sm",
                onClick = "onNextFormat",
            }),
        }),
    }))
end

local function update()
    if resetAt and noctalia.nowMs() >= resetAt then
        resetAt = nil
        status = "idle"
        statusName = ""
        currentInput = nil
        setInterval(5000)
        render()
        return
    end
    render()
end

local function start()
    setInterval(5000)
    render()
end

return {
    start = start,
    update = update,
    onChooseImage = onChooseImage,
    onPrevFormat = onPrevFormat,
    onNextFormat = onNextFormat,
}
