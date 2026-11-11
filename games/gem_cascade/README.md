# Gem Cascade 6.7.0

Gem Cascade is the LeoMiniGames `gem_cascade` external RCC match-3 game. Version 6.7.0 is a mobile-polish release based on physical-phone feedback from 6.6.0.

## 6.7.0 changes

- Fixed the mobile booster/action regression: `BoosterButton.qml` no longer references a private `UiButton` QML id, and the bottom `Flow` now keeps its implicit height.
- Audio is **host-aware and mobile-safe**: desktop prefers LeoMiniGames `GameAudio`; Android/iOS use an isolated `QtMultimedia` `MediaPlayer` pool for the game-owned RCC WAV files, with host fallback.
- 17 short SFX are included for selection, swap, invalid move, match/cascade, Line/Bomb/Prism/Nova, combo, boosters, shuffle, win/fail and stars.
- Special gems are more visually distinct with stronger theme-aware borders, badges, overlay icons and a restrained breathing highlight.
- Large special clears now use a short ~190 ms theme-colored impact flash/ring, low-amplitude board shake and light/medium/heavy haptic feedback depending on impact strength.
- Normal match-3 clears do **not** shake the whole screen.
- Sound and vibration can be toggled from the pause overlay. `haptics` remains the manifest setting key for backward compatibility and is labelled **Vibration**.
- Sound/vibration choices are also stored in the canonical campaign snapshot.

## Specials

- 4-match: horizontal/vertical Line gem.
- T/L match: Bomb.
- 5-match: Prism.
- 6+ match: Nova.
- Specials can be tapped to activate directly.
- Two neighboring special gems can be combined.
- Supported combinations include Line+Line, Bomb+Bomb, Line+Bomb, Prism+normal, Prism+Line, Prism+Bomb, Prism+Nova, Line+Nova, Bomb+Nova, Nova+Nova and Prism+Prism.

## Controls

Desktop: mouse/touch-style swipe or click selection, WASD/arrows, Enter/Space, H, R and P/Esc.

Mobile: swipe, tap-select/tap-neighbor, direct special activation, and bottom booster buttons sized to the host touch-target metric.

## Audio

`components/AudioBus.qml` probes the LeoMiniGames `GameAudio` service (`playEffect`, `preload`, lifecycle pause/resume). On Android/iOS, the game deliberately prefers `components/LocalAudioFallback.qml`, which uses pooled QtMultimedia `MediaPlayer`/`AudioOutput` instances with RCC-local WAV URLs. This avoids the SoundEffect-only path that was silent in the physical-phone 6.6.0 test.

If the local mobile backend is not ready, the adapter falls back to the host service. Audio failures are non-fatal.

## Save / lifecycle

The schema-2 canonical snapshot preserves campaign state, active stable board state, boosters, tutorial/statistics and the sound/vibration preferences. Animation transactions are never persisted half-complete; backgrounding rolls back to the last stable snapshot before forced save.

## RCC contract

`mod.qrc` must use inner prefix `/`. LeoMiniGames mounts the binary RCC at `/mods/gem_cascade`, producing `:/mods/gem_cascade/Main.qml`. Do not change the inner prefix to `/mods/gem_cascade`.

## Build from the repository root

With Python 3.11 or newer and Qt 6's `rcc` installed, run

```sh
python tools/build_game.py gem_cascade --rcc /path/to/rcc
```

If `rcc` is on `PATH`, omit `--rcc`. The build writes `gem_cascade-6.7.0.rcc`
and its SHA-256 checksum to this game's `dist/` directory. Open the package in
LeoMiniGames 0.6.2 or newer.

The [GitHub Actions workflow](../../.github/workflows/gem_cascade.yml) builds the
RCC and attaches it to successful workflow runs.

## Game-specific build

Windows:

```bat
build_mod.bat "D:\Qt\6.11.1\llvm-mingw_64\bin\rcc.exe"
```

Linux/macOS:

```bash
./build_mod.sh /path/to/rcc
```

Output:

```text
gem_cascade-6.7.0.rcc
```

The default build is fail-closed: source validation → RCC build → mounted-resource/QQmlEngine smoke. `GEM_CASCADE_SKIP_QT_SMOKE=1` is an explicit unverified bypass only.

## Validation

```bash
python3 tools/validate_source.py
node tools/test_board_logic.js
node tools/test_campaign_balance.js
```

The source validator checks manifest/QRC, locale parity, SVG/WAV assets, QML/service contracts, booster mobile-layout regression, audio routing, save/lifecycle and gameplay simulations.

## 6.7.0 desktop parity pass

- Gameplay gems, special overlays and booster icons now render as ordinary SVG `Image` items rather than Canvas-tinted symbols. Gem colors are embedded as gameplay-semantic SVG colors.
- Removed font-dependent star/multiplier/arrow glyphs from gameplay HUD/fallback copy.
- QtMultimedia MediaPlayer pool is now first choice on desktop as well as mobile; GameAudio remains a fallback.
- Added physical QWERTY scan-code fallback for Windows, Linux and macOS keyboard layouts.
- Mouse click-click and drag/swipe paths remain active; board logic regression tests still cover special activation/combinations and 1000 cascade runs.

## 6.7.0 booster progression

Booster inventory is no longer limited to the initial gift. The progression economy is deterministic and non-farmable:

- every newly-cleared level grants one booster from a balanced Hammer/Shuffle/Extra rotation;
- the first 3-star clear on levels 3, 6, 9, ... grants one additional Shuffle;
- every fifth newly-cleared level grants one Cross Blast;
- replaying an already-cleared/3-starred level cannot grant the same reward again.

The policy is implemented in `js/LevelLogic.js` and covered by `tools/test_booster_rewards.js`. Across 30 perfect first clears the fixed budget is 46 rewards: 18 Hammer, 16 Shuffle, 6 Cross Blast and 6 Extra Moves.

The Windows runtime `Unable to assign [undefined] to double` warnings from `GemCell.qml` were caused by child items using `parent.radius` while `UiPanel` reparents content into an internal `Item`; those bindings now use `cell.radius`. Audio components also no longer redeclare the inherited `Item.enabled` property.

## 6.7.0 smart-board / player-fun pass

The board algorithm no longer accepts the first merely legal layout. Opening boards and shuffle results evaluate colour balance, legal-move agency and special-making opportunities, while keeping the search budget intentionally small for low-end devices.

Hints are objective-aware rather than scan-order based. The hint scorer considers immediate clear size, special creation, special combinations, target-gem progress, ice, Bomb objectives and low-move urgency. It can also recommend direct activation of an existing special instead of pretending a weak swap is the best action.

Refill uses mild inverse-frequency weighting to reduce long colour droughts, plus a deliberately small cascade bias. Two lightweight refill candidates are compared; this reduces dead boards without guaranteeing wins or scripting objective gems. A 500-board Gamer audit measured about 10.36 legal opening moves on average, 4.82 average refill colour spread, and zero dead refills in that sample.

Audio startup was also hardened: local RCC MediaPlayer remains primary and host GameAudio is no longer eagerly preloaded in parallel. Host fallback uses only the observed single-URL call contract.

## License

[GPL-3.0-or-later](LICENSE).
