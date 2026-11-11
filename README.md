# LMGOfficalGames

Open-source official YoungLion games for [LeoMiniGames](https://github.com/YoungLionOrganization/LeoMiniGames).
Each game is a Level 2 QML plugin packaged as an RCC for LeoMiniGames 0.6.2 or newer.

## Games

| Game | Version | Category | Workflow |
| --- | --- | --- | --- |
| [Alchemy Workshop](games/alchemy_workshop/) | 6.4.0 | Puzzle | [CI](.github/workflows/alchemy_workshop.yml) |
| [Astro Courier](games/astro_courier/) | 6.4.0 | Arcade | [CI](.github/workflows/astro_courier.yml) |
| [Brick Forge](games/brick_forge/) | 6.4.0 | Arcade | [CI](.github/workflows/brick_forge.yml) |
| [Circuit Defense](games/circuit_defense/) | 6.4.0 | Strategy | [CI](.github/workflows/circuit_defense.yml) |
| [Dungeon Delver](games/dungeon_delver/) | 6.6.3 | Roguelike | [CI](.github/workflows/dungeon_delver.yml) |
| [Gem Cascade](games/gem_cascade/) | 6.7.0 | Puzzle | [CI](.github/workflows/gem_cascade.yml) |
| [Harvest Pocket](games/harvest_pocket/) | 7.4.2 | Simulation | [CI](.github/workflows/harvest_pocket.yml) |
| [Merge Foundry](games/merge_foundry/) | 6.4.0 | Puzzle | [CI](.github/workflows/merge_foundry.yml) |
| [Meteor Miner](games/meteor_miner/) | 6.4.0 | Arcade | [CI](.github/workflows/meteor_miner.yml) |
| [Orbital Commander](games/orbital_commander/) | 6.4.0 | Action | [CI](.github/workflows/orbital_commander.yml) |
| [Pocket Factory](games/pocket_factory/) | 3.2.0 | Management | [CI](.github/workflows/pocket_factory.yml) |
| [Reversi Arena](games/reversi_arena/) | 6.4.0 | Strategy | [CI](.github/workflows/reversi_arena.yml) |
| [Rogue Deck](games/rogue_deck/) | 6.4.0 | Card | [CI](.github/workflows/rogue_deck.yml) |
| [Snake Circuit](games/snake_circuit/) | 6.4.0 | Arcade | [CI](.github/workflows/snake_circuit.yml) |
| [Star Defender](games/star_defender/) | 6.4.0 | Shooter | [CI](.github/workflows/star_defender.yml) |
| [Sudoku Master](games/sudoku_master/) | 6.4.0 | Puzzle | [CI](.github/workflows/sudoku_master.yml) |
| [Tower Grid](games/tower_grid/) | 6.4.0 | Strategy | [CI](.github/workflows/tower_grid.yml) |

## Build and play

Install Python 3.11 or newer and the Qt 6 resource compiler, `rcc`. From the repository root,
build a game by its folder name.

```sh
python tools/build_game.py snake_circuit --rcc /path/to/rcc
```

Omit `--rcc` if the compiler is on `PATH`, or set `LMG_RCC` to its path. The
versioned RCC and SHA-256 checksum are written to `games/<game_id>/dist/`. Open
the RCC in LeoMiniGames. Successful GitHub Actions runs also provide these files
as downloadable artifacts.

Each game's workflow runs when its source or shared build files change and can
be run manually from the Actions tab. CI validates the package and runs the
game-specific regression checks where available.

## License

All listed games declare GPL-3.0-or-later. See the `LICENSE` file in each game's
directory for its license terms.
