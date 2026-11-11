# Tower Grid 6.4.0

A grid-based lane defense game with Basic, Cannon and Frost towers, tower upgrades, enemy classes, economy and escalating waves. Classic Enhanced keeps the original Vol.4 interface/gameplay identity while adding LeoMiniGames v0.6.2 theme, save, lifecycle, localization and desktop/mobile integration.

## Build from the repository root

With Python 3.11 or newer and Qt 6's `rcc` installed, run

```sh
python tools/build_game.py tower_grid --rcc /path/to/rcc
```

If `rcc` is on `PATH`, omit `--rcc`. The build writes `tower_grid-6.4.0.rcc`
and its SHA-256 checksum to this game's `dist/` directory. Open the package in
LeoMiniGames 0.6.2 or newer.

The [GitHub Actions workflow](../../.github/workflows/tower_grid.yml) builds the
RCC and attaches it to successful workflow runs.

## License

[GPL-3.0-or-later](LICENSE).
