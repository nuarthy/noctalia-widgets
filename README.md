# noctalia-widgets

Noctalia 5.4+ plugin that ports [nuarthy/dms-widgets](https://github.com/nuarthy/dms-widgets)
from DankMaterialShell to Noctalia's declarative desktop widgets. It ships one
desktop entry with seven modes (clock, weather, system, media, world clock,
calendar, user card) and a shared weather service.

The plugin lives in [`noctalia-widgets/`](noctalia-widgets/); `catalog.toml`
indexes it so this repository can be added as a Noctalia plugin source:

```sh
noctalia msg plugins source add nuarthy-widgets git https://github.com/nuarthy/noctalia-widgets
noctalia msg plugins enable nuarthy/noctalia-widgets
```

To work on it locally, add the checkout as a path source instead:

```sh
noctalia msg plugins source add nuarthy-widgets path ~/Projects/noctalia-widgets
noctalia msg plugins enable nuarthy/noctalia-widgets
```

Then add a **Desktop Widgets** instance from **Settings → Desktop Widgets** and
set its **Mode**. Add one instance per card.

See [noctalia-widgets/README.md](noctalia-widgets/README.md) for the widget
list, settings, the shared weather service, and the differences from the DMS
original.

## Layout

```
noctalia-widgets/          plugin directory (id nuarthy/noctalia-widgets)
  plugin.toml              entries and typed settings
  widget.luau              one desktop entry, dispatches on the Mode setting
  modes/                   one module per widget mode
  weather_service.luau     headless Open-Meteo service
  lib/util.luau            formatting and weather-code helpers
  translations/            en.json, ja.json
  thumbnail.webp           960x540 store card
catalog.toml               source index
.agents/setup              Luau toolchain for a fresh orb
```

## Checks

```sh
find noctalia-widgets -name '*.luau' -exec luau-compile --binary {} \; >/dev/null
```

On a Noctalia host:

```sh
noctalia plugins lint noctalia-widgets
```

The repository is static Luau and TOML; it cannot render without a running
Noctalia session.

MIT licensed.
