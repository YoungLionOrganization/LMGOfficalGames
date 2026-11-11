# Harvest Pocket 7.4.2 — Town Market Stability Patch

<img src="assets/icon.svg" width="80" height="80" alt="Harvest Pocket icon">

[![Build status](https://github.com/YoungLionOrganization/LMGOfficalGames/actions/workflows/harvest_pocket.yml/badge.svg?branch=main)](https://github.com/YoungLionOrganization/LMGOfficalGames/actions/workflows/harvest_pocket.yml)
[![License GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue)](LICENSE)
[![LeoMiniGames 0.6.2+](https://img.shields.io/badge/LeoMiniGames-0.6.2%2B-2358ab)](https://github.com/YoungLionOrganization/LeoMiniGames/releases)

[All games](../../README.md#games) · [Get LeoMiniGames](https://github.com/YoungLionOrganization/LeoMiniGames/releases)

Harvest Pocket is an official LeoMiniGames farming simulation designed for desktop and mobile, including low-end devices. Version 7.4.2 is a backward-compatible Town Market recovery/stability PATCH. It repairs interrupted v7.4.0/v7.4.1 day-transition saves that could leave mature crops effectively unharvestable, makes harvest/day/economy rollback exact, hardens malformed-save normalization, blocks hidden Farm input during transitions/other tabs, and retains the full Town Market, Smart Fields, Living Seasons, responsive-navigation and host-audio feature set.

## Highlights

- 16 crops, each with five visible SVG growth stages and a product illustration.
- Responsive layout classes: Compact (<680 px), Medium (680–1279 px) and Wide (>=1280 px). Compact keeps bottom navigation; Medium/Wide use centered top navigation, with Wide switching to a denser fixed-width presentation instead of an oversized left rail.
- Sticky HUD and Farm Context Action Bar remain visible while gameplay content scrolls.
- Effective water source is derived from manual watering, sprinkler coverage, rain or storms, with matching SVG indicators and no duplicate watering energy cost.
- Pooled three-slot floating reward feedback avoids per-action QML object creation.
- Dry, wet, fertile, winter, greenhouse and irrigation field presentation using lightweight SVG resources.
- Five meaningful watering-can tiers, five sprinkler tiers, five greenhouse tiers and staged land expansion from 12 to 40 plots.
- Six animal species: chicken, duck, cow, goat, sheep and bee, with building capacity, happiness/productivity and multiple animated visual states.
- Five processing buildings and eight recipes linking crops, animal products and feed into a larger economy.
- Three-slot Town Order Board with explicit Available/Accepted/Completed/Rejected/Abandoned/Expired states, three free board refreshes per in-game day, and accepted-order protection during refresh.
- Timed special orders show their deadline before acceptance and remain visibly expired instead of disappearing.
- Signed market category movement uses SVG trend indicators; the next-day forecast communicates direction without exposing an exact future price.
- Four crop quality grades and five crop mastery tiers.
- Eight Community Projects with five phases each for long-term progression without a prestige reset.
- 28-day years with four seven-day seasons and deterministic daily weather/market values.
- Ten complete locale catalogs: EN, TR, AZ, RU, DE, FR, ES, PT, ZH and JA.
- Internal save schema v4 with canonical `snapshot_v4`, normalized v3/v2 compatibility mirrors, bounded order history, debounced autosave, and v6.4/v7.x migration while retaining host `save_version: 1`.
- v7.4.2 recovery revision 3 re-audits v7.4.1 saves, restores the missing full-energy/day-counter state after an interrupted historical Next Day commit, and rewrites the repaired snapshot immediately.
- Harvest has both plot interaction and an explicit sticky **Harvest selected** action; harvest, batch harvest, Next Day, selling, order delivery and Community Project transactions restore the exact pre-action snapshot if an unexpected runtime exception occurs.
- Gameplay keyboard/GameInput is Farm-only (except global `N` Next Day) and is locked while day/tab transitions are mutating presentation/state, preventing invisible/off-tab farm actions.
- Low-overhead timing policy: one startup-only service retry, one save-debounce timer, one shared visual pulse and one inactive-by-default day-transition watchdog; representative animal sprites are capped at six, with no Canvas, MultiEffect, ShaderEffect or particle system.

## Controls

Desktop supports mouse/touch interaction plus Arrow Keys or WASD to move the selected plot. Enter/Space interacts with the selected plot, `F` uses fertilizer, `N` advances the day and number keys select early crop slots. Host `GameInput` actions are supported when available, with raw keyboard input retained as a fallback.

On touch devices, plot actions are explicit: tapping an empty plot plants the selected crop, tapping a dry planted crop waters it, and tapping a ready crop harvests it. A ready selected crop also exposes a dedicated **Harvest selected** action in the sticky Farm action bar, so harvest does not depend on one input path. A watered growing crop does **not** silently consume fertilizer; fertilizer remains explicit, and harvest-ready crops reject fertilizer so a consumable cannot be wasted after maturation.

## Save compatibility

Harvest Pocket 7.4 uses internal save schema 4. v7.4.2 deliberately keeps that schema and adds an internal `repairRevision` marker (current revision 3) rather than inventing a new schema for a recovery-only change. `snapshot_v4` is canonical. Normalized compatibility mirrors are still written to `snapshot_v3` and `snapshot_v2`; v4-only terminal order states are mapped to the older cooldown representation in those mirrors so a temporary downgrade does not strand the board. The manifest deliberately keeps host `save_version: 1`, matching v6.4.x, so old host slots remain loadable. v7.3/v7.2 snapshots promote to schema 4 on load; older v6.4 scalar/object state still uses the verified `load/get/set/save` migration path.

Legacy migration intentionally preserves:

- coins, energy, XP, farm level and reputation;
- all 40 legacy plots (mapped to the final v7 land stage);
- access to the original v6.4 crop set (Turnip, Carrot, Berry, Corn, Pumpkin and Crystal Bloom), even if the new v7 level gates would otherwise re-lock them;
- legacy inventory and existing crop stock, assigned to Normal quality;
- chickens, cows, animal happiness and existing coop/barn levels;
- Watering Can/Sprinkler/Greenhouse levels, clamped to their meaningful v7 maximums;
- an active legacy Town Order when its payload is valid.

New v7 animals, processing buildings, Community Projects and the apiary begin unclaimed rather than being granted from unrelated legacy progress.

## Build from the repository root

With Python 3.11 or newer and Qt 6's `rcc` installed, run

```sh
python tools/build_game.py harvest_pocket --rcc /path/to/rcc
```

If `rcc` is on `PATH`, omit `--rcc`. The build writes `harvest_pocket-7.4.2.rcc`
and its SHA-256 checksum to this game's `dist/` directory. Open the package in
LeoMiniGames 0.6.2 or newer.

The [GitHub Actions workflow](../../.github/workflows/harvest_pocket.yml) builds the
RCC and attaches it to successful workflow runs.

## Game-specific build

The canonical Windows build entry point is `build.bat`. It invokes the PowerShell 5.1-compatible `tools/build_harvest_pocket.ps1` pipeline for **this game only**. The legacy `build_mod.bat` remains as a compatibility wrapper; `build_mod.sh` provides the equivalent Linux/macOS path.

The build pipeline performs manifest/version checks, package validation, gameplay regression, migration regression, release-tree audit, optional `qmllint`, RCC generation, SHA-256 generation, and a deterministic source ZIP. Qt is not pinned to one machine path: pass `-Rcc`, set `LMG_RCC`/`RCC`/`QT_RCC`/`QTDIR`, put `rcc` on `PATH`, or let the PowerShell script inspect common Qt install roots. When several desktop Qt kits are installed, Harvest Pocket now selects one deterministically instead of failing: newest Qt version first, then `llvm-mingw_64`, `mingw_64`, MSVC, then other kits. Qt Design Studio tool copies are not scanned as desktop kits.

### Windows

```bat
build.bat -Rcc "D:\Qt\<version>\<kit>\bin\rcc.exe"
```

Normally `build.bat` can be run without `-Rcc`; the selected kit is printed before validation/build begins. Use `-Rcc` only when you intentionally want to override the automatic choice.

### Linux / macOS

```bash
./build_mod.sh /path/to/Qt/bin/rcc
```

Successful builds create:

```text
dist/harvest_pocket-7.4.2.rcc
dist/harvest_pocket-7.4.2.rcc.sha256
release/HarvestPocket_7.4.2_Source.zip
release/HarvestPocket_7.4.2_Source.zip.sha256
```


## Validation

Manual execution:

```bash
python3 tools/validate_package.py
python3 tools/test_gameplay.py
python3 tools/test_migration.py
```

`validate_package.py` checks manifest/QRC consistency, every RCC path, SVG/XML integrity, absence of embedded raster gameplay assets, locale parity/placeholders, source-level emoji/Unicode icon policy, save/migration gates, low-end rendering constraints, service capability fallbacks and package hygiene.

Static validation is not a substitute for loading the built RCC in the real LeoMiniGames host or testing physical Android/iOS devices. For 7.4.2, the current LeoMiniGames source contract was verified before audio integration: modern hosts use `GameAudio.playEffect()` / `GameAudio.playMusic()` and short SFX fall back to legacy `Audio.playUrl()` when needed. Audio failures are caught and never block gameplay. See `VALIDATION_REPORT.md`, `BUG_HUNTER_AUDIT.md` and `GAMER_AUDIT.md` for the exact test boundary.

## L3 / native decision

Harvest Pocket is official content and could use LeoMiniGames Level 3/native permissions. Version 7.4.2 intentionally remains an RCC-only Level 2 package because its economy is day/turn based and the current workload does not justify a platform-specific companion binary. Qt Quick's scene graph and cached SVG Images are sufficient for the visual workload. Native code should be introduced only if profiling demonstrates a real bottleneck or a future feature requires a verified native host capability.

## License

[GPL-3.0-or-later](LICENSE).

## 7.0.3 runtime hotfix

7.0.3 fixes the animal-card nested Repeater binding loop reported by the Qt runtime, makes nullable order/visibility bindings explicitly boolean-safe, and refreshes the crop/animal/field/tool/building SVG set for clearer silhouettes without adding heavy effects.

## 7.0.3 planting UX

The Farm planting panel is now season-aware. It defaults to crops valid for the current season, can expand to all crops, displays four SVG season markers per crop, and gives a selected-crop summary with valid seasons, growth time, seed stock and planting status. Season changes automatically move an invalid hidden selection to a usable crop. Town Orders also avoid crops that are currently unreachable unless stock or greenhouse access makes them fulfillable.

## 7.0.4 language and day-transition hotfix

7.0.4 hardens runtime language switching and small-screen localization layout. Translation bindings now explicitly depend on an i18n revision signal, stale status messages are cleared when the host language changes, localized text is rendered as plain text, and common icon buttons wrap/elide long translations instead of expanding without limit. All ten locale files have matching keys, UTF-8/NFC validation, placeholder parity and fallback-copy checks.

`Next Day` now uses an explicit two-stage safety flow. If uncovered growing crops are dry, the first press shows a translated warning, shakes the farm content, flashes an inward danger border and changes the button to `Continue anyway`. Harvest-ready crops, sprinkler-covered plots, rain and storms do not trigger a false warning. The confirming press fades the screen to black, commits the day at blackout, then fades the new day back in. Reduced Motion keeps the safety indication while minimizing movement.

Season-filtered planting navigation was also hardened: keyboard number shortcuts and the host `next` input now select only crops visible in the current crop filter instead of silently choosing a hidden out-of-season crop.

## 7.0.5 package / narrow-layout hotfix

7.0.5 is a PATCH release only. It fixes release-tree defects found by the adversarial validator: four SVG assets that existed on disk but were absent from `mod.qrc`, an unused Canvas-based `ThemedSvgIcon.qml`, a forbidden raster `assets/icon.png`, and the lost executable bit on `build_mod.sh`. It also prevents the existing five-button navigation from degenerating into one oversized button per row at phone widths, makes compact icon-button text columns honor explicitly narrowed button widths, and lets Workshop building/recipe rows plus Journal project action rows wrap rather than overflow narrow viewports. No v7.1.0 responsive-navigation architecture, sticky HUD, effective-water-state feature, or other MINOR-scope system is introduced.


## 7.1.0 Responsive Farm

7.1.0 is a backward-compatible MINOR release. It introduces three deterministic layout classes instead of stretching one layout across every viewport. Compact layouts use a five-slot bottom navigation, Medium layouts use sticky top navigation, and Wide layouts move navigation to a left rail. The HUD stays pinned at the top and the Farm Context Action Bar stays pinned near the bottom so crop selection, seed purchase, fertilizer and Next Day remain reachable while the farm content scrolls.

Farm water presentation now uses a derived effective state. A crop can be effectively watered by manual watering, irrigation coverage, rain or storm; the plot shows the corresponding SVG source and uses wet soil presentation. Manual watering excludes already-effective plots, so tapping a sprinkler-covered or rainy crop no longer wastes energy. Harvest-ready crops receive a semantic accent border plus basket indicator using the existing shared visual pulse rather than per-plot timers.

Harvest, sell, animal production, craft and Town Order delivery now feed a fixed three-item reward overlay pool. No QML object is created per reward. Workshop building and recipe cards explicitly change geometry in Compact mode so the action button gets its own full-width row instead of depending on accidental Flow wrapping.

Town Orders now support Reject for available orders and Abandon for accepted orders. These actions share a persisted daily budget of three refreshes. A rejected/abandoned slot enters cooldown until the next in-game day rather than immediately rolling another order, closing the free infinite-reroll exploit. Delivery still replaces a completed order normally because it represents completed gameplay, not a refresh action.

Save schema moves from internal v2 to v3 only because the new daily order-refresh state is persistent. Host `save_version` remains 1. Existing v7.0.x `snapshot_v2` data is accepted and promoted, and v6.4 migration remains supported.


## 7.2.0 Living Seasons

7.2.0 is a backward-compatible MINOR release focused on day, season and weather presentation. `VisualFeedbackLayer.qml` is now the single transition director. Next Day follows the deterministic pipeline `request -> optional warning -> fade out -> blackout commit -> optional season transition -> weather transition -> fade in`; gameplay state changes only after blackout is reached.

Season boundaries use fixed SVG pools: spring petals, summer pollen/light motifs, autumn leaves and winter snowflakes. Weather presentation covers Sunny, Cloudy, Rain, Wind, Storm, Heatwave and Frost. The farm also receives lightweight ambient weather feedback while the Farm tab is visible. Wind/storm continue to influence crop sway, rain/storm continue to feed effective watering, and frost keeps the winter field treatment.

No Qt ParticleSystem, ShaderEffect, blur or MultiEffect is used. Decorative effects are fixed-size Repeaters driven by a small number of shared animation properties, so they do not create per-particle QML objects during play. Ambient movement is gated by Farm-tab visibility, application visibility, Reduced Motion and transition state. Reduced Motion preserves the day/season/weather information with short fades and static SVGs while suppressing continuous movement.

The save schema remains internal v3 because Living Seasons adds only derived/transient visual state; no new persistent gameplay field is required.


## 7.2.2 Living Seasons Polish Patch

7.2.2 is a PATCH release. It keeps the v7.2 gameplay/save schema intact and addresses player-facing presentation issues found after real desktop use.

Day transitions now use a calmer full-black commit stage with a compact themed status card, followed by smaller season/weather cards and reduced decorative pools. Persistent weather decoration was split into `AmbientWeatherLayer.qml`, rendered below sticky HUD/navigation/action chrome so rain, wind and other effects no longer wash over the whole interface. Reduced Motion keeps the information while minimizing continuous movement.

Responsive breakpoints are now Compact `<680`, Medium `680–1279`, and Wide `>=1280`. Wide/fullscreen desktop no longer moves the five primary destinations into a tall left rail. Medium and Wide use centered top navigation; Wide uses the denser form capped at 760 px, while content is centered and capped at 1180 px. This avoids controls becoming visually oversized on 1080p/1440p/4K windows.

Audio uses the verified LeoMiniGames host contract rather than importing QtMultimedia directly. Short interactions include planting, watering, sprinkler, harvest, sell, craft, animal production and day transition SFX. Rain, wind and storm use subdued loopable WAV beds through the host Ambient group. SFX use conservative per-action gain values; the ambient source files themselves are mixed quietly so the game does not change the user's global host volume settings. Audio is lifecycle-aware and stops/pauses outside relevant gameplay states.

## v7.2.2 patch

- Adds distinct low-volume feedback for purchases, order accept/reject/delivery, animal purchases, workshop construction, upgrades, fertilizing and tab navigation.
- Makes workshop crafting transactional so multi-ingredient recipes such as Farm Bread cannot partially consume ingredients/energy on a failed craft.
- Adds reduced-motion-aware tab transitions: short fade/slide on normal motion, immediate switch when Reduced Motion is enabled.
- Keeps all sounds behind the verified LeoMiniGames `GameAudio` / legacy `Audio.playUrl` host adapters.


## 7.3.0 Smart Fields

Smart Fields separates canonical persistent plot data (`crop`, `age`, `watered`, `fertilized`) from derived runtime state (`EMPTY`, `PLANTED`, `DRY`, `WATERED`, `FERTILIZED`, `READY`) and the derived water source (`MANUAL`, `SPRINKLER`, `RAIN`, `STORM`). The new irrigation view maps the 40 plots into five deterministic eight-plot zones (A-E) and shows full/partial sprinkler coverage without persisting UI state.

Progression-gated batch actions preserve the original economy: Water All Dry unlocks with Watering Tool III and charges energy according to the current watering-tool coverage; Harvest All Ready unlocks at farm level 10 and still costs one energy per harvested plot; Fertilize Zone unlocks at level 8 and consumes exactly one fertilizer per affected plot in the selected zone. Batch harvesting aggregates player feedback instead of creating one popup per plot.

No save-schema bump is required because zone selection, field state, coverage and batch eligibility are all derived/transient. Existing v7.2.x and older schema-v3 saves remain compatible.

## v7.4.0 — Town Market

- Town Orders now keep explicit Available, Accepted, Completed, Rejected, Abandoned, and Expired states instead of silently replacing active work.
- The board has three free refreshes per in-game day; accepted orders are never removed by a refresh.
- Deterministic special orders can expire, show their deadline before acceptance, and remain visible as Expired rather than disappearing.
- A bounded 40-entry order history records completed/rejected/abandoned outcomes and the highest completed reward.
- Market categories show signed daily percentage movement with SVG trend icons and a deterministic next-day demand forecast.
- Internal save schema is v4. v3/v2 compatibility mirrors are still written; new terminal order states are downgraded to legacy cooldown entries in those mirrors.


## v7.4.2 — Stability Patch

- Fixed Next Day black-screen/transition lock caused by the stale `syncOrderRejectBudget()` call left after the v7.4 board-refresh rename.
- Added a bounded transition watchdog and force-finish recovery path so a future callback exception cannot leave input/UI permanently blocked.
- Board Refresh now guarantees a visibly distinct replacement order for every refreshable slot instead of sometimes consuming a refresh on an identical early-game card.
- Board Refresh disables when every unlocked order is Accepted, since Accepted orders are intentionally preserved.
- Save schema remains v4; no migration bump is required.
