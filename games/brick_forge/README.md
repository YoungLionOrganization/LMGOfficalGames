# Brick Forge 6.4.0

<img src="assets/icon.png" width="80" height="80" alt="Brick Forge icon">

[![Build status](https://github.com/YoungLionOrganization/LMGOfficalGames/actions/workflows/brick_forge.yml/badge.svg?branch=main)](https://github.com/YoungLionOrganization/LMGOfficalGames/actions/workflows/brick_forge.yml)
[![License GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue)](LICENSE)
[![LeoMiniGames 0.6.2+](https://img.shields.io/badge/LeoMiniGames-0.6.2%2B-2358ab)](https://github.com/YoungLionOrganization/LeoMiniGames/releases)

[All games](../../README.md#games) · [Get LeoMiniGames](https://github.com/YoungLionOrganization/LeoMiniGames/releases)

A rebuilt Breakout campaign with guaranteed visible brick layouts, multiple level patterns, combo scoring, temporary power-ups, touch paddle control and capped difficulty scaling. Classic Enhanced keeps the original Vol.4 interface/gameplay identity while adding LeoMiniGames v0.6.2 theme, save, lifecycle, localization and desktop/mobile integration.

## Build from the repository root

With Python 3.11 or newer and Qt 6's `rcc` installed, run

```sh
python tools/build_game.py brick_forge --rcc /path/to/rcc
```

If `rcc` is on `PATH`, omit `--rcc`. The build writes `brick_forge-6.4.0.rcc`
and its SHA-256 checksum to this game's `dist/` directory. Open the package in
LeoMiniGames 0.6.2 or newer.

The [GitHub Actions workflow](../../.github/workflows/brick_forge.yml) builds the
RCC and attaches it to successful workflow runs.

## License

[GPL-3.0-or-later](LICENSE).
