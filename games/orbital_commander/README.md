# Orbital Commander 6.4.0

The original Vol.4 active planetary-defense game, substantially expanded with five threat classes plus Dreadnought bosses, shield/credit economy, missile/shield/drone research, autosave, stats and full desktop/touch controls while retaining the classic HUD, battlefield and command-bar layout.

## Build from the repository root

With Python 3.11 or newer and Qt 6's `rcc` installed, run

```sh
python tools/build_game.py orbital_commander --rcc /path/to/rcc
```

If `rcc` is on `PATH`, omit `--rcc`. The build writes `orbital_commander-6.4.0.rcc`
and its SHA-256 checksum to this game's `dist/` directory. Open the package in
LeoMiniGames 0.6.2 or newer.

The [GitHub Actions workflow](../../.github/workflows/orbital_commander.yml) builds the
RCC and attaches it to successful workflow runs.

## License

[GPL-3.0-or-later](LICENSE).
