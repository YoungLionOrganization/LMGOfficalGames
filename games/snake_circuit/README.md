# Snake Circuit 6.4.0

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
