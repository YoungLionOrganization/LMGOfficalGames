# Astro Courier 6.4.0

Expanded turn-based space courier with theme-aware SVG map assets, fog/scanning, pirates and combat, hazards/salvage, station contracts, ship upgrades, deadlines and multi-sector progression.

## Build from the repository root

With Python 3.11 or newer and Qt 6's `rcc` installed, run

```sh
python tools/build_game.py astro_courier --rcc /path/to/rcc
```

If `rcc` is on `PATH`, omit `--rcc`. The build writes `astro_courier-6.4.0.rcc`
and its SHA-256 checksum to this game's `dist/` directory. Open the package in
LeoMiniGames 0.6.2 or newer.

The [GitHub Actions workflow](../../.github/workflows/astro_courier.yml) builds the
RCC and attaches it to successful workflow runs.

## License

[GPL-3.0-or-later](LICENSE).
