# Star Defender 6.4.0

A substantially rebuilt space shooter with responsive touch movement, auto-fire, multiple enemy classes, bosses, shields, weapon upgrades, pickups and escalating waves. Classic Enhanced keeps the original Vol.4 interface/gameplay identity while adding LeoMiniGames v0.6.2 theme, save, lifecycle, localization and desktop/mobile integration.

## Build from the repository root

With Python 3.11 or newer and Qt 6's `rcc` installed, run

```sh
python tools/build_game.py star_defender --rcc /path/to/rcc
```

If `rcc` is on `PATH`, omit `--rcc`. The build writes `star_defender-6.4.0.rcc`
and its SHA-256 checksum to this game's `dist/` directory. Open the package in
LeoMiniGames 0.6.2 or newer.

The [GitHub Actions workflow](../../.github/workflows/star_defender.yml) builds the
RCC and attaches it to successful workflow runs.

## License

[GPL-3.0-or-later](LICENSE).
