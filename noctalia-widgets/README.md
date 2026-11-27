# Desktop Widgets

Desktop widgets for [Noctalia](https://noctalia.dev), ported from
[nuarthy/dms-widgets](https://github.com/nuarthy/dms-widgets). One desktop
entry ships seven modes and one shared weather service:

| Mode | What it shows |
| --- | --- |
| `clock` | Digital, stacked or compact clock with an optional date, seconds, timezone and palette color |
| `weather` | Current conditions, humidity, wind, rain chance and a 1–6 day forecast |
| `system` | CPU, RAM, battery, or all three as compact rows |
| `media` | MPRIS artwork, title, artist, playback progress and previous/play/next |
| `world_clock` | Local time plus configurable IANA zones with live GMT offsets |
| `calendar` | Six-row month grid, Monday or Sunday start, today highlighted |
| `user_card` | Avatar, name, uptime, weather, and lock/settings/power actions |

## Plugin

| Field | Value |
| --- | --- |
| ID | `nuarthy/noctalia-widgets` |
| Desktop widget | `widget` (select a Mode: `clock`, `weather`, `system`, `media`, `world_clock`, `calendar`, `user_card`) |
| Service | `weather_service` (headless Open-Meteo client) |
| Plugin API | 51 |

Noctalia labels every plugin desktop widget with the plugin name, so seven
separate entries would appear as seven identical rows in the type picker. This
plugin therefore ships one `widget` entry with a Mode setting. Add one instance
per card and choose its mode; every instance keeps its own settings. The
service starts with the plugin because both `weather` and `user_card` read its
snapshot.

The UI strings ship in English and Japanese (`translations/`).

## Requirements

- Noctalia 5.5.0 or newer (`plugin_api = 51`, needed for `noctalia.mediaPlayer()`).
- Network access for the weather service (Open-Meteo, no API key).
- `[system.monitor]` enabled under **Settings → System Monitor** for the CPU and
  RAM tiles. The battery tile reads `/sys/class/power_supply` directly.
- An MPRIS player for the media widget.

## Usage

Add this repository as a plugin source and enable the plugin:

```sh
noctalia msg plugins source add nuarthy-widgets git https://github.com/nuarthy/noctalia-widgets
noctalia msg plugins enable nuarthy/noctalia-widgets
```

For a local checkout, add the checkout as a path source instead:

```sh
noctalia msg plugins source add nuarthy-widgets path ~/Projects/noctalia-widgets
noctalia msg plugins enable nuarthy/noctalia-widgets
```

Then open **Settings → Desktop Widgets**, add a **Desktop Widgets** instance,
and set **Mode**. Place, resize and rotate the card in the editor; the script
owns only the content. Add another instance for each further card.

## Settings

Weather settings are plugin-level, so the weather widget and the user card share
one request:

| Setting | Default | Meaning |
| --- | --- | --- |
| Weather location | empty | City name or `latitude,longitude`. Empty uses the shell `location.address`, then Jakarta. |
| Units | metric | Metric (°C, km/h) or imperial (°F, mph). |
| Refresh interval | 15 min | Minutes between Open-Meteo requests. |

Everything else is per instance and filtered by the selected mode. The important
ones:

- **clock** — style, date and time formats, timezone, seconds, colors, width.
- **weather** — forecast on/off, day count, details, feels-like, color, width.
- **system** — metric (CPU/RAM/battery/all), warning threshold, details, bar.
- **media** — artwork, progress bar, color, width.
- **world_clock** — `Label=IANA/Zone` list, local block, date, GMT offsets, columns.
- **calendar** — week start, width, accent and text colors.
- **user_card** — name and avatar overrides, weather/uptime/action toggles.

Jobs that outlive a click go through Noctalia's own IPC, so the user card and
media widget agree with the bar and control center:

```sh
noctalia msg media toggle      # media widget play/pause
noctalia msg session lock      # user card lock
noctalia msg panel-toggle session   # user card power
noctalia msg settings-toggle   # user card settings
```

## Weather service

The `weather_service` entry is headless. It:

1. Resolves the location with Open-Meteo's geocoding API, unless the setting is
   already `latitude,longitude`.
2. Fetches current conditions and six forecast days.
3. Publishes the snapshot on the plugin's `nw.weather` state channel.
4. Caches the last good snapshot in the plugin data directory, so an offline
   start shows the previous data marked stale instead of an empty card.

The refresh button on the weather mode bumps `nw.weather.refresh`; the service
handles the request, so all instances share one fetch. Open-Meteo requests are
only made while the plugin is enabled.

## Differences from the DMS collection

| DMS widget | Here | Why |
| --- | --- | --- |
| `wb-clock` | Mode `clock` | The analog face is omitted: `ui.*` has no canvas or absolute positioning. Digital, stacked and compact are kept. |
| `wb-weather` | Mode `weather` | Same card, driven by the shared service. |
| `wb-cpu`, `wb-ram`, `wb-battery` | Mode `system` | One mode with a Metric setting; `all` adds a compact three-row layout. |
| `wb-media` | Mode `media` | Artwork, metadata and transport are kept. The cava visualizer is left to Noctalia's built-in `audio_visualizer` desktop widget; plugin desktop widgets have no audio-spectrum callback. |
| `wb-worldclock` | Mode `world_clock` | Zones are settings now; the `TZ=... date` subprocess is gone. |
| `wb-calendar` | Mode `calendar` | Same grid with a configurable week start. |
| `wb-usercard` | Mode `user_card` | Same information; actions open Noctalia's session menu and settings. |
| `wb-converter` | not ported | Noctalia desktop widgets do not accept external file drag-and-drop, and the declarative API has no file-drop target. |
| `wb-board`, `wb-presets`, `wb-presets-button` | not ported | Noctalia's desktop-widget editor owns placement and layouts; plugins cannot read or write widget positions. |
| `wb-notes`, `wb-todo`, `wb-timers`, `wb-visualizer`, `wb-customimage` | not ported | These were phase-2 placeholders. Noctalia ships a timer, an audio visualizer and a sticker widget, and an official notes plugin. |

## Development

The plugin is Luau plus TOML, with no build step. Compile every script with the
[Luau CLI](https://github.com/luau-lang/luau):

```sh
find noctalia-widgets -name '*.luau' -exec luau-compile --binary {} \;
```

On a machine running Noctalia, cross-check declared settings against the code:

```sh
noctalia plugins lint noctalia-widgets
```

`luau-analyze` reports the host-provided globals (`noctalia`, `ui`,
`desktopWidget`) as unknown; that is expected. Point luau-lsp at
[`noctalia.d.luau`](https://github.com/noctalia-dev/official-plugins/blob/main/noctalia.d.luau)
for real diagnostics.

MIT licensed.
