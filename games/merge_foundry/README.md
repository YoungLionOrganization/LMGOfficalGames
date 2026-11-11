# Merge Foundry 6.4.0

A robust 2048-style foundry game with touch swipes, keyboard controls, undo, earned hammer power-ups, score and best score. Classic Enhanced keeps the original Vol.4 interface/gameplay identity while adding LeoMiniGames v0.6.2 theme, save, lifecycle, localization and desktop/mobile integration.

## Build from the repository root

With Python 3.11 or newer and Qt 6's `rcc` installed, run

```sh
python tools/build_game.py merge_foundry --rcc /path/to/rcc
```

If `rcc` is on `PATH`, omit `--rcc`. The build writes `merge_foundry-6.4.0.rcc`
and its SHA-256 checksum to this game's `dist/` directory. Open the package in
LeoMiniGames 0.6.2 or newer.

The [GitHub Actions workflow](../../.github/workflows/merge_foundry.yml) builds the
RCC and attaches it to successful workflow runs.

## License

[GPL-3.0-or-later](LICENSE).
