# Rogue Deck 6.4.0

Roguelite deckbuilder with draw/discard deck, enemy intents, bosses, relics, rewards, shop/rest decisions, persistent progression and corrected QML loading/runtime integration.

## Build from the repository root

With Python 3.11 or newer and Qt 6's `rcc` installed, run

```sh
python tools/build_game.py rogue_deck --rcc /path/to/rcc
```

If `rcc` is on `PATH`, omit `--rcc`. The build writes `rogue_deck-6.4.0.rcc`
and its SHA-256 checksum to this game's `dist/` directory. Open the package in
LeoMiniGames 0.6.2 or newer.

The [GitHub Actions workflow](../../.github/workflows/rogue_deck.yml) builds the
RCC and attaches it to successful workflow runs.

## License

[GPL-3.0-or-later](LICENSE).
