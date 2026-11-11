# Circuit Defense 6.4.0

Expanded lane tower-defense with six tower classes, five upgrade levels, varied enemy archetypes, shields/armor/regeneration, bosses, research, selling and EMP/Orbital/Overclock abilities.

## Build from the repository root

With Python 3.11 or newer and Qt 6's `rcc` installed, run

```sh
python tools/build_game.py circuit_defense --rcc /path/to/rcc
```

If `rcc` is on `PATH`, omit `--rcc`. The build writes `circuit_defense-6.4.0.rcc`
and its SHA-256 checksum to this game's `dist/` directory. Open the package in
LeoMiniGames 0.6.2 or newer.

The [GitHub Actions workflow](../../.github/workflows/circuit_defense.yml) builds the
RCC and attaches it to successful workflow runs.

## License

[GPL-3.0-or-later](LICENSE).
