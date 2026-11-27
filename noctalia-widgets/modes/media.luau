--!nonstrict
-- Media desktop widget: artwork, title, artist, progress and transport controls.
--
-- The DMS original polled Quickshell's MprisController and drew a cava
-- visualizer. This port reads Noctalia's active MPRIS player through
-- noctalia.mediaPlayer() on Noctalia 5.5+, and falls back to `playerctl` on
-- Noctalia 5.4. Transport commands go through the shell IPC, so they control the
-- same player the bar and control center use. The visualizer is left to
-- Noctalia's built-in audio_visualizer widget; a plugin desktop widget has no
-- audio-spectrum callback.

local util = require("../lib/util.luau")

local SHOW_ART = noctalia.getConfig("media_show_art") ~= false
local SHOW_PROGRESS = noctalia.getConfig("media_show_progress") ~= false
local COLOR = noctalia.getConfig("media_color") or "primary"
local SHADOW = noctalia.getConfig("media_shadow") == true
local WIDTH = util.clamp(tonumber(noctalia.getConfig("media_width")) or 340, 240, 900)
local ART_SIZE = 100

local NATIVE_MEDIA = util.hasApi51()
local PLAYERCTL = not NATIVE_MEDIA and noctalia.commandExists("playerctl")
local PLAYERCTL_FORMAT =
    "{{playerName}}\t{{status}}\t{{title}}\t{{artist}}\t{{mpris:artUrl}}\t{{mpris:length}}\t{{position}}"

local player = nil
local artUrl = ""
local artPath = nil
local artRequest = ""
local lastTrackKey = ""
local updateInterval = 0
local refreshing = false
local warnedNoPlayerctl = false

local render

local function label(props)
    return ui.label(util.withShadow(props, SHADOW))
end

local function artDir()
    local base = noctalia.getenv("XDG_RUNTIME_DIR")
    if not base or base == "" then
        base = noctalia.pluginDataDir()
    end
    if not base or base == "" then
        return nil
    end
    local dir = base .. "/noctalia-widgets"
    noctalia.mkdirAll(dir)
    return dir
end

local function artExtension(url)
    local path = tostring(url or ""):match("^[^?]+") or ""
    local extension = path:match("%.([%w]+)$")
    if extension then
        extension = extension:lower()
        if extension == "jpeg" or extension == "jpg" or extension == "png" or extension == "webp" then
            return extension
        end
    end
    return "jpg"
end

local function cleanupArt(dir, current)
    local entries = noctalia.listDir(dir) or {}
    local now = os.time()
    for _, name in ipairs(entries) do
        if name ~= current and tostring(name):match("^art%-") then
            local path = dir .. "/" .. name
            local info = noctalia.fileInfo(path)
            if type(info) == "table" and now - (tonumber(info.mtime) or now) > 3600 then
                noctalia.removeFile(path)
            end
        end
    end
end

local function localArtPath(url)
    if url == "" then
        return nil
    end
    if url:sub(1, 7) == "file://" then
        local path = url:sub(8)
        path = path:gsub("^localhost", "")
        if path:sub(1, 1) ~= "/" then
            path = "/" .. path
        end
        local decoded = noctalia.string.urlDecode(path)
        if noctalia.fileExists(decoded) then
            return decoded
        elseif noctalia.fileExists(path) then
            return path
        end
        return nil
    end
    if url:sub(1, 1) == "/" and noctalia.fileExists(url) then
        return url
    end
    return nil
end

local function downloadArt(url, token)
    local dir = artDir()
    if not dir then
        return
    end
    local name = "art-" .. util.hash(url) .. "." .. artExtension(url)
    local path = dir .. "/" .. name
    if noctalia.fileExists(path) then
        artPath = path
        render()
        return
    end

    noctalia.download(url, path, function(success)
        if token ~= artRequest then
            return
        end
        if success then
            artPath = path
            cleanupArt(dir, name)
            render()
        else
            artPath = nil
            render()
        end
    end)
end

local function setArt(url)
    if url == artUrl then
        return
    end
    artUrl = url
    artRequest = tostring(noctalia.nowMs()) .. "-" .. util.hash(url)
    artPath = nil

    if not SHOW_ART or url == "" then
        return
    end
    local localPath = localArtPath(url)
    if localPath then
        artPath = localPath
        return
    end
    if url:match("^https?://") then
        downloadArt(url, artRequest)
    end
end

local function artNode()
    if artPath then
        return ui.image({
            path = artPath,
            width = ART_SIZE,
            height = ART_SIZE,
            radius = 12,
            fit = "cover",
        })
    end
    return ui.column({
        width = ART_SIZE,
        height = ART_SIZE,
        fill = "surface_container_high",
        radius = 12,
        align = "center",
        justify = "center",
    }, {
        ui.glyph({ name = "music", size = 34, color = "on_surface_variant" }),
    })
end

local function artistLine()
    if type(player.artists) == "table" and #player.artists > 0 then
        local names = {}
        for _, name in ipairs(player.artists) do
            names[#names + 1] = tostring(name)
        end
        return table.concat(names, ", ")
    end
    return noctalia.tr("media.unknown_artist")
end

local function playerView()
    local inner = WIDTH - 12
    local textWidth = SHOW_ART and (inner - ART_SIZE - 12) or inner
    local playing = player.status == "Playing"
    local title = noctalia.tr("media.unknown_title")
    if type(player.title) == "string" and player.title ~= "" then
        title = player.title
    end
    local children = {
        label({
            text = title,
            fontSize = 16,
            fontWeight = "semibold",
            color = "on_surface",
            maxWidth = textWidth,
            maxLines = 1,
        }),
        label({
            text = artistLine(),
            fontSize = 11,
            color = "on_surface_variant",
            maxWidth = textWidth,
            maxLines = 1,
        }),
    }

    if SHOW_PROGRESS then
        local length = tonumber(player.lengthMs) or 0
        local position = tonumber(player.positionMs) or 0
        local progress = length > 0 and util.clamp(position / length, 0, 1) or 0
        children[#children + 1] = ui.progress({
            progress = progress,
            fill = COLOR,
            track = "outline_variant/0.5",
            width = textWidth,
            height = 4,
            radius = 2,
        })
        children[#children + 1] = ui.row({ gap = 4, align = "center", justify = "space_between" }, {
            label({
                text = util.formatDuration(position),
                fontSize = 9,
                color = "on_surface_variant",
            }),
            label({
                text = length > 0 and util.formatDuration(length) or "--:--",
                fontSize = 9,
                color = "on_surface_variant",
            }),
        })
    end

    children[#children + 1] = ui.row({ gap = 6, align = "center" }, {
        ui.button({
            glyph = "media-prev",
            variant = "ghost",
            controlSize = "sm",
            onClick = "onPrevious",
        }),
        ui.button({
            glyph = playing and "media-pause" or "media-play",
            variant = "primary",
            controlSize = "sm",
            onClick = "onToggle",
        }),
        ui.button({
            glyph = "media-next",
            variant = "ghost",
            controlSize = "sm",
            onClick = "onNext",
        }),
    })

    local columns = { ui.column({ gap = 3, flexGrow = 1, align = "start" }, children) }
    if SHOW_ART then
        table.insert(columns, 1, artNode())
    end
    return ui.row({ gap = 12, align = "center", width = WIDTH, padding = 6 }, columns)
end

local function idleView()
    local inner = WIDTH - 12
    local textWidth = SHOW_ART and (inner - ART_SIZE - 12) or inner
    local columns = {
        ui.column({ gap = 3, flexGrow = 1, align = "start" }, {
            label({
                text = noctalia.tr("media.idle_title"),
                fontSize = 15,
                fontWeight = "semibold",
                color = "on_surface",
                maxWidth = textWidth,
                maxLines = 1,
            }),
            label({
                text = noctalia.tr("media.idle_subtitle"),
                fontSize = 11,
                color = "on_surface_variant",
                maxWidth = textWidth,
                maxLines = 2,
            }),
        }),
    }
    if SHOW_ART then
        table.insert(columns, 1, artNode())
    end
    return ui.row({ gap = 12, align = "center", width = WIDTH, padding = 6 }, columns)
end

render = function()
    if player then
        desktopWidget.render(playerView())
    else
        desktopWidget.render(idleView())
    end
end

local function setInterval(value)
    if value ~= updateInterval then
        updateInterval = value
        noctalia.setUpdateInterval(value)
    end
end

local function applyPlayer(nextPlayer)
    if nextPlayer then
        player = nextPlayer
        local key = table.concat({
            tostring(nextPlayer.busName),
            tostring(nextPlayer.trackId),
            tostring(nextPlayer.title),
            tostring((type(nextPlayer.artists) == "table" and nextPlayer.artists[1]) or ""),
        }, "|")
        local nextArt = tostring(nextPlayer.artUrl or "")
        if key ~= lastTrackKey or nextArt ~= artUrl then
            lastTrackKey = key
            setArt(nextArt)
        end
        setInterval(nextPlayer.status == "Playing" and 1000 or 3000)
    else
        player = nil
        lastTrackKey = ""
        artUrl = ""
        artRequest = ""
        artPath = nil
        setInterval(3000)
    end
    render()
end

local function refreshPlayerctl()
    if refreshing then
        return
    end
    refreshing = true
    local started = noctalia.runAsync({ "playerctl", "metadata", "--format", PLAYERCTL_FORMAT }, function(result)
        refreshing = false
        applyPlayer(result.exitCode == 0 and util.parsePlayerctl(result.stdout) or nil)
    end)
    if not started then
        refreshing = false
        applyPlayer(nil)
    end
end

local function refreshPlayer()
    if NATIVE_MEDIA then
        applyPlayer(noctalia.mediaPlayer())
        return
    end
    if not PLAYERCTL then
        if not warnedNoPlayerctl then
            warnedNoPlayerctl = true
            noctalia.log("media: playerctl not found; install it for Noctalia 5.4 MPRIS support")
        end
        applyPlayer(nil)
        return
    end
    refreshPlayerctl()
end

local function onPrevious()
    util.exec({ "media", "previous" })
end

local function onToggle()
    util.exec({ "media", "toggle" })
end

local function onNext()
    util.exec({ "media", "next" })
end

local function start()
    noctalia.setUpdateInterval(1000)
    refreshPlayer()
end

return {
    start = start,
    update = refreshPlayer,
    onPrevious = onPrevious,
    onToggle = onToggle,
    onNext = onNext,
}
