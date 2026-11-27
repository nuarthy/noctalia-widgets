# noctalia-widgets

Ten separate Noctalia desktop widgets, ported from
[nuarthy/dms-widgets](https://github.com/nuarthy/dms-widgets). Each card is its
own plugin, so each name appears separately in the desktop-widget type picker.

| Widget | Plugin ID | What it shows |
| --- | --- | --- |
| Card Clock | `nuarthy/clock` | Digital, stacked or compact clock with date, seconds and timezone |
| Card Weather | `nuarthy/weather` | Current conditions and an Open-Meteo forecast |
| Card CPU | `nuarthy/cpu` | CPU usage with an optional bar and detail line |
| Card RAM | `nuarthy/ram` | RAM usage with an optional bar and detail line |
| Card Battery | `nuarthy/battery` | Battery percentage, state and remaining time |
| Card Media | `nuarthy/media` | MPRIS artwork, track details, progress and controls |
| Card World Clock | `nuarthy/world-clock` | Local time plus configurable IANA zones |
| Card Calendar | `nuarthy/calendar` | Six-row month grid with today highlighted |
| Card User Card | `nuarthy/user-card` | Avatar, name, uptime, weather and session actions |
| Card Image Converter | `nuarthy/image-converter` | Click to choose an image; convert to WebP, PNG, JPG or AVIF |

Noctalia versions before 5.5 label every desktop widget from one plugin with
the plugin's manifest name. Separate manifests are therefore required for
separate picker rows.

## Requirements

- Noctalia 5.4.0 or newer. Every manifest uses `plugin_api = 43`.
- `playerctl` for the Media widget on Noctalia 5.4. Noctalia 5.5+ uses the
  native `noctalia.mediaPlayer()` API.
- `[system.monitor]` enabled for the CPU and RAM widgets.
- An MPRIS player for the Media widget.
- `zenity`, `kdialog`, or `yad` for the Image Converter file picker.
- ImageMagick (`magick` or `convert`) or FFmpeg for Image Converter.
- Network access for Weather and User Card. Open-Meteo needs no API key.
- Text shadow requires Noctalia 5.5 or newer.

## Install

### Git source

Add this repository as a source, then enable the widgets you want:

```sh
noctalia msg plugins source add nuarthy-widgets git https://github.com/nuarthy/noctalia-widgets
noctalia msg plugins enable nuarthy/clock
noctalia msg plugins enable nuarthy/weather
noctalia msg plugins enable nuarthy/cpu
noctalia msg plugins enable nuarthy/ram
noctalia msg plugins enable nuarthy/battery
noctalia msg plugins enable nuarthy/media
noctalia msg plugins enable nuarthy/world-clock
noctalia msg plugins enable nuarthy/calendar
noctalia msg plugins enable nuarthy/user-card
noctalia msg plugins enable nuarthy/image-converter
```

### Local checkout with symlinks

Link each plugin directory into Noctalia's local source:

```sh
mkdir -p ~/.local/share/noctalia/plugins
ln -sfn ~/Projects/noctalia-widgets/clock        ~/.local/share/noctalia/plugins/clock
ln -sfn ~/Projects/noctalia-widgets/weather      ~/.local/share/noctalia/plugins/weather
ln -sfn ~/Projects/noctalia-widgets/cpu          ~/.local/share/noctalia/plugins/cpu
ln -sfn ~/Projects/noctalia-widgets/ram          ~/.local/share/noctalia/plugins/ram
ln -sfn ~/Projects/noctalia-widgets/battery      ~/.local/share/noctalia/plugins/battery
ln -sfn ~/Projects/noctalia-widgets/media        ~/.local/share/noctalia/plugins/media
ln -sfn ~/Projects/noctalia-widgets/world-clock  ~/.local/share/noctalia/plugins/world-clock
ln -sfn ~/Projects/noctalia-widgets/calendar     ~/.local/share/noctalia/plugins/calendar
ln -sfn ~/Projects/noctalia-widgets/user-card    ~/.local/share/noctalia/plugins/user-card
ln -sfn ~/Projects/noctalia-widgets/image-converter ~/.local/share/noctalia/plugins/image-converter
```

Then enable them:

```sh
noctalia msg plugins enable nuarthy/clock
noctalia msg plugins enable nuarthy/weather
noctalia msg plugins enable nuarthy/cpu
noctalia msg plugins enable nuarthy/ram
noctalia msg plugins enable nuarthy/battery
noctalia msg plugins enable nuarthy/media
noctalia msg plugins enable nuarthy/world-clock
noctalia msg plugins enable nuarthy/calendar
noctalia msg plugins enable nuarthy/user-card
noctalia msg plugins enable nuarthy/image-converter
```

Add each card from the desktop-widget editor. Every plugin appears under its
own name: **Card Clock**, **Card Weather**, **Card CPU**, and so on.

### Replacing the old single plugin

Earlier releases shipped one `nuarthy/noctalia-widgets` entry. Remove it before
using the split plugins:

```sh
noctalia msg plugins disable nuarthy/noctalia-widgets
rm ~/.local/share/noctalia/plugins/noctalia-widgets
```

## Scope

The upstream repository has 18 `wb-*` directories. They are not 18 working
cards:

- `notes`, `todo`, `timers`, `visualizer` and `customimage` are 40-line
  "Phase 2" placeholders.
- `board`, `presets` and `presets-button` manage DMS layouts. Noctalia's
  desktop editor owns layout, so these have no equivalent.
- Noctalia does not expose OS file drops to plugin desktop widgets. **Card
  Image Converter** opens a native file picker when clicked; the left and right
  arrows change the target format. The result goes next to the input, then to
  `~/Pictures/Converted` if that directory is not writable.

The ten cards above are the working, portable set. CPU, RAM and battery are
separate plugins instead of one mode-switched card.

## Layout

```
<widget>/
  plugin.toml
  widget.luau           entry wrapper
  modes/<mode>.luau     card implementation
  lib/util.luau         shared helpers (copied per plugin)
  translations/         en.json, ja.json
  weather_service.luau  Weather and User Card only
catalog.toml            source index
.agents/setup           Luau toolchain for a fresh orb
```

Each plugin is self-contained because Noctalia materializes one plugin
directory per ID.

## Checks

```sh
find . -name '*.luau' -not -path './.git/*' -exec luau-compile --binary {} \; >/dev/null
```

On a Noctalia host:

```sh
noctalia plugins lint .
```

MIT licensed.
