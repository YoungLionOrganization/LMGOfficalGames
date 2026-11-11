# Snake Circuit 6.4.0

<img src="assets/icon.png" width="80" height="80" alt="Snake Circuit icon">

[![Build status](https://github.com/YoungLionOrganization/LMGOfficalGames/actions/workflows/snake_circuit.yml/badge.svg?branch=main)](https://github.com/YoungLionOrganization/LMGOfficalGames/actions/workflows/snake_circuit.yml)
[![License GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue)](LICENSE)
[![LeoMiniGames 0.6.2+](https://img.shields.io/badge/LeoMiniGames-0.6.2%2B-2358ab)](https://github.com/YoungLionOrganization/LeoMiniGames/releases)

[All games](../../README.md#games) · [Get LeoMiniGames](https://github.com/YoungLionOrganization/LeoMiniGames/releases)

Classic Vol.4 Snake campaign preserved with reliable desktop focus, WASD/arrows, Space/P pause, R restart, mouse/swipe controls, obstacles, levels, scoring and autosave.

## Build from the repository root

With Python 3.11 or newer and Qt 6's `rcc` installed, run

```sh
python tools/build_game.py snake_circuit --rcc /path/to/rcc
```

If `rcc` is on `PATH`, omit `--rcc`. The build writes `snake_circuit-6.4.0.rcc`
and its SHA-256 checksum to this game's `dist/` directory. Open the package in
LeoMiniGames 0.6.2 or newer.

The [GitHub Actions workflow](../../.github/workflows/snake_circuit.yml) builds the
RCC and attaches it to successful workflow runs.

## License

[GPL-3.0-or-later](LICENSE).
