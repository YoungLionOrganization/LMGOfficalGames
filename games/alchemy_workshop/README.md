# Alchemy Workshop 6.4.0

Clear three-step alchemy management: gather ingredients, choose recipes, brew with quality/mastery, complete multi-craft guild orders, upgrade workshop/cauldron/storage and manage a persistent economy.

## Build from the repository root

With Python 3.11 or newer and Qt 6's `rcc` installed, run

```sh
python tools/build_game.py alchemy_workshop --rcc /path/to/rcc
```

If `rcc` is on `PATH`, omit `--rcc`. The build writes `alchemy_workshop-6.4.0.rcc`
and its SHA-256 checksum to this game's `dist/` directory. Open the package in
LeoMiniGames 0.6.2 or newer.

The [GitHub Actions workflow](../../.github/workflows/alchemy_workshop.yml) builds the
RCC and attaches it to successful workflow runs.

## License

[GPL-3.0-or-later](LICENSE).
