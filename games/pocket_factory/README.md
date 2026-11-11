# Pocket Factory 3.2.0

<img src="assets/icon.png" width="80" height="80" alt="Pocket Factory icon">

[![Build status](https://github.com/YoungLionOrganization/LMGOfficalGames/actions/workflows/pocket_factory.yml/badge.svg?branch=main)](https://github.com/YoungLionOrganization/LMGOfficalGames/actions/workflows/pocket_factory.yml)
[![License GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue)](LICENSE)
[![LeoMiniGames 0.6.2+](https://img.shields.io/badge/LeoMiniGames-0.6.2%2B-2358ab)](https://github.com/YoungLionOrganization/LeoMiniGames/releases)

[All games](../../README.md#games) · [Get LeoMiniGames](https://github.com/YoungLionOrganization/LeoMiniGames/releases)

Deepened factory management with six production lines, inventories, managers, research, contracts, storage upgrades, offline income and Crown prestige progression.

This is the GPL-licensed 3.2.0 edition from Volume 4. Its original license notice is in [LICENSE-NOTICE.txt](LICENSE-NOTICE.txt).

## Build from the repository root

With Python 3.11 or newer and Qt 6's `rcc` installed, run

```sh
python tools/build_game.py pocket_factory --rcc /path/to/rcc
```

If `rcc` is on `PATH`, omit `--rcc`. The build writes `pocket_factory-3.2.0.rcc`
and its SHA-256 checksum to this game's `dist/` directory. Open the package in
LeoMiniGames 0.6.2 or newer.

The [GitHub Actions workflow](../../.github/workflows/pocket_factory.yml) builds the
RCC and attaches it to successful workflow runs.

## License

[GPL-3.0-or-later](LICENSE).
