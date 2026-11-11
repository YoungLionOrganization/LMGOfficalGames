# Dungeon Delver 6.6.3

Dungeon Delver is the LeoMiniGames `dungeon_delver` turn-based roguelike. Version 6.6.3 is a visible gameplay/UI revision rather than a behind-the-scenes content update: every fresh run starts with a class choice, the first floor exposes the new loot/economy systems immediately, gameplay actors use multicolor SVG art, the HUD shows class/skill/inventory objectives, and mobile has a persistent skill action plus responsive movement controls.

## Playable classes

Every new run starts with a visible class selection:

- **Sentinel** — higher HP and armor; `Shield Bash` damages adjacent enemies and grants temporary guard.
- **Rogue** — higher attack and an extra bomb; `Shadow Strike` bursts a nearby enemy and grants brief evasion.
- **Arcanist** — extra potion; `Arc Nova` damages nearby enemies in an area.

Active skills are available from floor 1. Desktop uses `F` or Space; mobile has a persistent class-skill button. Cooldowns advance with turns and the Quickglass relic shortens skill recovery.

The title bar intentionally shows **v6.6.3** so a device test can immediately confirm that the new RCC is actually loaded.

## First-floor experience

The old build could hide most new content behind later floors. Version 6.6.3 deliberately exposes the expanded systems in the first minutes. Floor 1 places, near the start where capacity permits:

- Soul Shard
- key and locked chest
- shrine
- relic
- bomb
- coins and a potion

The first-floor objective text points the player toward these systems instead of only saying to find the stairs.

## Major gameplay systems

- Connected 13x13 procedural dungeon floors with small chamber carving.
- Fog of war and upgradable vision radius.
- Eight enemy archetypes: Slime, Goblin, Bat, Skeleton, Cultist, Ogre, Wraith and Guardian.
- Guardian boss every fifth floor; stairs remain sealed while the Guardian lives.
- Loot/events: coins, potions, bombs, keys, locked chests, shrines, traps, Soul Shards and relics.
- Eight relics: Delver Blade, Vital Charm, Stone Ward, Moon Lantern, Bloodstone, Blast Core, Quickglass and Gilded Token.
- Relic passives include attack, max HP, armor, vision, kill-heal, bomb damage, faster skill recharge and improved coin income.
- Turn-based combat with enemy pursuit, melee pressure and Cultist ranged attacks.
- Bomb active item damages nearby enemies; Blast Core improves it.
- In-run shop spends coins on potions, bombs and keys.
- Persistent Soul Shards survive run restarts and buy permanent Vitality, Might, Fortune and Torch upgrades.
- Best floor, total kills and best run coins are persisted.

## Visual system

Gameplay actors/items are true multicolor SVG assets. They are no longer flattened into a single theme tint.

### Hero art

Class and environment style are independent:

- Sentinel uses its own hero SVG.
- Rogue uses its own hero SVG.
- Arcanist uses its own hero SVG.

### Environment styles

Three selectable dungeon presentations ship in the same version:

1. **Iron Keep** — masonry/fortress treatment.
2. **Ember Crypt** — warmer crypt treatment.
3. **Moon Ruins** — arcane/ruins treatment.

The environment style changes wall presentation while the chosen hero class remains the chosen hero class.

Included art groups include 3 hero SVGs, 8 enemy SVGs, environment variants, loot/event icons and UI skill/shop/settings icons. UI frames/text still use LeoMiniGames `GameTheme`; gameplay SVGs preserve semantic embedded colors for recognition.

Hits, traps, loot, bombs, boss events and skills use restrained cell rings/flash and low-amplitude board shake rather than expensive blur-heavy effects.

## Controls

### Desktop

- Arrow keys / WASD — move
- `F` or Space — class active skill
- H — drink potion
- B — use bomb
- E — shop / legacy upgrades
- Esc — close active overlay or open Settings
- Mouse — all UI controls

### Mobile

Two movement methods are available simultaneously:

- swipe directly on the dungeon board;
- large four-direction D-pad.

The action area keeps the class skill, Potion, Bomb, Shop and Options controls accessible. Short landscape layouts reduce nonessential HUD height and hide the desktop side panel so the dungeon remains usable. Qt SafeArea margins are respected.

## Save model

Version 6.6.3 uses save schema 2 with a canonical JSON snapshot through `GameSave`.

### Persistent campaign/meta state

- Soul Shards
- permanent upgrades
- best floor
- total kills
- best run coins
- tutorial state
- sound/vibration preferences
- selected environment style

### Active run state

- full dungeon map
- fog/seen map
- all monsters, type/HP/position/boss state
- player position
- HP/max HP/attack/armor
- current floor
- coins/potions/bombs/keys
- XP and hero level
- relic list
- death state
- selected hero class
- skill cooldown
- Sentinel guard turns
- Rogue evade turns
- turn counter

Save/load is service-readiness gated. Old 6.4.x scalar save fields have a migration path. Restored runs are sanitized before play.

Fresh-install class selection is transactional: a default Sentinel run is not committed before the player chooses a class.

## Audio and haptics

The package includes **28 short WAV effects**, including dedicated Sentinel, Rogue and Arcanist skill cues.

Audio uses the same cross-platform strategy proven in the later Gem Cascade build:

- `AudioBus.qml` probes/preloads LeoMiniGames `GameAudio` when present.
- Android/iOS prefer a pooled local `QtMultimedia` MediaPlayer fallback for RCC-contained WAV assets.
- Desktop prefers the host audio mixer when available.
- Failure of either route does not crash gameplay.

Settings contains **Test Sound** so the audio path can be checked immediately on a device.

Sound and vibration have independent in-game toggles. Haptic calls are guarded on unsupported platforms.

## Theme integration

UI colors derive from LeoMiniGames `GameTheme` with conservative fallbacks. Runtime theme changes increment a revision dependency so panels, text and controls refresh without restart. Gameplay-semantic SVG colors are intentionally preserved for readability.

## i18n

Key-parity checked locale files are included for:

`en`, `tr`, `az`, `ru`, `de`, `fr`, `es`, `pt`, `zh`, `ja`.

There are **115 shared runtime translation keys** with placeholder parity validation.

## Build from the repository root

With Python 3.11 or newer and Qt 6's `rcc` installed, run

```sh
python tools/build_game.py dungeon_delver --rcc /path/to/rcc
```

If `rcc` is on `PATH`, omit `--rcc`. The build writes `dungeon_delver-6.6.3.rcc`
and its SHA-256 checksum to this game's `dist/` directory. Open the package in
LeoMiniGames 0.6.2 or newer.

The [GitHub Actions workflow](../../.github/workflows/dungeon_delver.yml) builds the
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

Both scripts produce:

```text
dungeon_delver-6.6.3.rcc
```

### RCC prefix contract

`mod.qrc` uses inner prefix `/`. LeoMiniGames mounts the compiled package at `/mods/dungeon_delver`, producing paths such as:

```text
:/mods/dungeon_delver/Main.qml
```

Do not put `/mods/dungeon_delver` inside `mod.qrc`; that would double the runtime mount root.

### Strict post-build verification

The default build is fail-closed. It:

1. runs `tools/validate_source.py`;
2. compiles the RCC;
3. builds the Qt smoke verifier;
4. mounts the actual RCC at `/mods/dungeon_delver`;
5. verifies critical resources/manifest fields;
6. instantiates `Main.qml` without host services for fallback resilience;
7. instantiates again with LeoMiniGames-style service stubs including audio;
8. chooses Rogue through the runtime class path;
9. invokes the active skill and checks cooldown state;
10. resizes through short-landscape and portrait dimensions while trapping QML diagnostics.

A failed smoke test deletes the generated RCC. `DUNGEON_DELVER_SKIP_QT_SMOKE=1` is an explicit **UNVERIFIED** bypass only.

## Validation

```bash
python3 tools/validate_source.py
python3 tools/test_run_systems.py
```

The validator covers JSON/i18n parity, QRC prefix/resource coverage, multicolor SVG structure, WAV structure/path parity, QML runtime-contract markers, save paths, desktop/mobile controls, first-floor content, class/skill behavior, audio routing, build/post-build contracts and procedural connectivity simulations.

## Test limitations

This source package is statically and algorithmically validated in the current environment. Physical Windows/Linux/macOS/Android/iOS gameplay is **not** claimed here. In particular, Android audio backend behavior, haptic intensity, safe-area handling and real touch feel should be validated after building against the actual LeoMiniGames host. The visible `v6.6.3` header is the fastest way to confirm the correct package is loaded on-device.

## 6.6.3 cross-platform parity pass

- Replaced font-dependent D-pad/currency glyphs with packaged SVG icons.
- Added layout-independent physical-key fallback using `KeyEvent.nativeScanCode` for QWERTY WASD positions on Windows, Linux/X11/Wayland-style scan codes and macOS. Arrow keys and LeoMiniGames `GameInput` remain supported.
- The same physical mapping also covers H/B/E/F/Space action positions so localized keyboard layouts do not strand desktop controls.
- Validator rejects the old triangle/diamond/star glyph controls and checks the physical-key matrix.

## 6.6.3 QML audio warning hotfix

The local audio components now use the inherited `QQuickItem.enabled` property instead of redeclaring `property bool enabled`. This removes the `qt.qml.propertyCache.append: Member enabled ... overrides a member of the base object` runtime warning without changing playback behavior.


## 6.6.3 runtime-log hardening

Single-URL GameAudio hardening: removed keyed/multi-argument preload/play fallbacks. Mobile local MediaPlayer path is unchanged; desktop host preload is only used when that backend is actually preferred.

## License

[GPL-3.0-or-later](LICENSE).
