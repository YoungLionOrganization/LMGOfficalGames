# Harvest Pocket 7.4.2 — Bug Hunter

## Fixed legacy defects

- Watering Can upgrades no longer consume money indefinitely after their effect has capped; v7 uses five meaningful tiers.
- Sprinkler and Greenhouse progression are finite five-tier coverage systems instead of no-op infinite levels.
- Greenhouse no longer removes the entire season system at its first upgrade; coverage expands by plot count.
- Animal happiness now affects output and is visible through animal state/feedback rather than being dead save data.
- Coop/Barn/Apiary capacity prevents unlimited animals in a level-one building.
- Animal-product orders use explicit Accept/Deliver flow and do not depend on a crop-harvest callback.
- Accepted orders are not silently replaced every fourth day.
- Tapping an already-watered growing crop no longer silently consumes fertilizer.
- Calendar progression is normalized to four seven-day seasons in a 28-day year.
- Nested plot/inventory/order objects are no longer written as independent ambiguous GameSave QVariant payloads.
- UI strings used by the new game flow are routed through complete ten-language catalogs.
- Manifest `reducedMotion` now changes animation behavior.

## Defects found during v7 implementation and fixed

- Crop-quality buckets could remain after recipe/order/project consumption, allowing ghost high-quality sales. All inventory consumption now passes through one canonical consume path and normalization reconciles buckets.
- Community Project energy recalculation could reduce an existing maximum-energy value. The update is now monotonic.
- Legacy Town Order progress was initially discarded during migration. Valid orders are now retained as accepted slot-zero orders.
- Next-Day dry-crop warning initially ignored extra irrigation coverage from the Irrigation Canal project. Effective sprinkler coverage is now shared with the real day simulation.
- GameSave/GameI18n could be touched before host service injection completed. Initialization now waits for the verified methods themselves and uses a short startup-only retry; guessed `ready/gameId/language` properties were removed.
- An early v7 draft bumped manifest `save_version` to 2 and guessed a `GameSave.registerMigration` callback. The supplied v6.4 source does not verify that API, so the host save version is now kept at 1 and the game performs internal schema-v2 migration only after the legacy slot has loaded.
- A validator delimiter scan treated apostrophes in comments as string delimiters. The scanner is now comment-aware.
- A safety refactor accidentally made the haptic wrapper recursive. It was caught in the second runtime audit; the helper now calls host Haptics directly and a regression rule forbids self-recursion.
- GameInput and Haptics connections originally assumed capability injection could never fail. They now capability-probe and safely no-op/fall back.
- 32-bit `coins`/`farmXp` properties were unsuitable for long-running farms. They now use QML `real`.
- The first v7 gate design could re-lock Pumpkin/Crystal Bloom and other original crops for a low-level v6.4 save. Migration now persists a compatibility flag for exactly the original six crops; new v7 crops are not granted.

## Adversarial scenarios checked statically / by pure regression tests

- sparse and malformed legacy save values;
- 40th legacy plot preservation;
- quality stock versus total inventory consistency;
- over-cap tool migration;
- negative legacy values;
- animal building capacity;
- crop/animal/recipe/project catalog counts;
- sprinkler + Community Project effective coverage;
- deterministic daily RNG path;
- no session-random market/weather/order dependence;
- two-timer performance ceiling;
- representative animal sprite cap;
- no Canvas/MultiEffect/ShaderEffect/ParticleSystem;
- SVG/QRC existence and XML parse;
- ten-locale key/placeholder parity;
- no raster gameplay assets and no Unicode/emoji gameplay icon source.

## Not claimed

The current container does not include the real LeoMiniGames executable, Qt `rcc`/`qmllint`, or physical Windows/Linux/Android/iOS/macOS test devices. Runtime QML loading, physical touch ergonomics, graphics-driver behavior and on-disk lifecycle persistence are therefore not claimed as tested here. For 7.4.0 the current LeoMiniGames `GameAudio`/legacy `AudioManager` source was inspected before integration; the package still capability-probes every call and treats audio failure as a no-op. Build scripts are designed to fail explicitly if `rcc` is unavailable.


## v7.0.3 loader hotfix

- Removed QML child-object semicolon separators that can produce `Unexpected token ';'` at runtime even though RCC compilation succeeds.
- Added a permanent validator gate for this parser failure class.
- Build scripts now probe Qt's `qmllint` and run a real Qt QML syntax pass when available before RCC generation.

## v7.0.3 runtime hotfix

- Fixed nested animal `Repeater` binding loop caused by the bare `count` identifier resolving to `Repeater.count` instead of the outer animal population property. The delegate now uses `animalCount` / `displayAnimalCount` and an explicit `animalCard` scope.
- Fixed nullable Town Order visibility expressions that could evaluate to JavaScript `undefined` and be assigned to QML `bool` properties.
- Hardened `FarmPlot`, `UiPanel`, and processing-section visibility bindings against undefined object/map values.
- Added static gates so the same shadowing/undefined-bool regressions fail validation.
- Reworked major SVG assets after visual QA: crop silhouettes, animal face/body alignment, field textures, tools and farm buildings. No filters, raster embeddings, per-asset timers, or shader effects were introduced.

## v7.0.3 planting / season audit

- Replaced the flat 16-crop chooser with a season-aware model and explicit current-season filter.
- Added automatic selection repair when the season changes so an out-of-season or locked crop does not remain the hidden default planting choice.
- Town Orders no longer choose an unlocked crop that is unreachable in the current season unless the player already has stock or greenhouse access.
- Fresh farms always retain at least one Level-1 crop in every season; Berry is now Level 1 so Summer cannot deadlock low-level players.
- Confirmed the original v6.4 package did **not** persist `selectedSeed`; therefore no legacy selected-crop index remap is needed.

## v7.0.4 language / Next Day regression audit

- Runtime language changes now invalidate translation bindings through `i18nRevision`; transient messages from the previous language are cleared.
- Locale files are checked for key parity, blanks, placeholders, UTF-8 replacement characters, NFC normalization and excessive English fallback copies.
- Long localized `IconButton` labels are constrained to two wrapped/elided lines.
- Next Day warnings ignore ready-to-harvest crops and effective sprinkler coverage, and rain/storm suppress dry warnings.
- The first warning press never advances the day; the confirmation press owns the fade-to-black transition and commits the day at the blackout midpoint.
- Warning feedback adds no recurring Timer and uses no blur, shader or particle effect.
- Keyboard/gamepad crop cycling can no longer bypass the current seasonal crop filter.

## v7.0.5 package / layout regression audit

- Initial source validator failed with eight concrete errors: `ThemedSvgIcon.qml` missing from QRC, four SVG UI files missing from QRC, `assets/icon.png` missing from QRC, raster gameplay asset policy violation, and a forbidden Canvas implementation. The unused Canvas component and raster PNG were removed; the four SVG resources were added to `mod.qrc`.
- Initial meta audit also found that `build_mod.sh` had lost its executable bit; it is executable again.
- Phone-width navigation used five `IconButton` instances with 190 px compact implicit widths, which made a roughly 360 px viewport collapse into a one-button-per-row navigation stack. Existing Flow navigation now gives the buttons a bounded half-row width on compact viewports without introducing the v7.1 adaptive-navigation subsystem.
- `IconButton` text width was fixed to 142 px in compact mode even when a caller assigned a narrower explicit button width. It now derives the text column from the actual control width.
- Workshop building/recipe rows and Journal project rows combined fixed images, minimum text columns and 190 px actions inside a non-wrapping `Row`, causing narrow-screen overflow. These existing rows now use wrapping `Flow` containers.
- `UiButton` now caps excessive translated-label width and elides a single line, preventing a long locale string from forcing a control wider than a phone card.
- Root `build.bat` / `publish.bat` and game-specific PowerShell pipelines were added. A follow-up Windows build exposed an ambiguity regression when several Qt installations were present: the first implementation aborted instead of choosing the intended desktop kit. The Harvest-only resolver now honors explicit/env/PATH choices first, otherwise selects the newest installed Qt desktop version with `llvm-mingw_64` preferred before `mingw_64` and MSVC; Qt Design Studio tool copies are excluded from discovery.
- A second real Windows build reached `qmllint` and then failed before validation because the Python resolver used `-like 'py*'`; PowerShell therefore classified `python.exe` as the Windows `py.exe` launcher and invoked `python.exe -3`, which Python 3.13 rejects as `Unknown option: -3`. The resolver now uses explicit candidates (`python.exe`/`python` with no prefix; `py.exe`/`py` with `-3`), probes that the selected interpreter is Python 3, and invokes validator scripts with a constructed argument array.
- The supplied working Volume 6 publisher was then reduced directly to Harvest Pocket instead of requiring an external transport adapter. The resulting publisher keeps the verified health/schema, upload-ticket, R2 PUT, catalog publish, and post-publish verification sequence while removing volume discovery, `volume.json`, `-Only`, and `-DiscoverAll` paths.

- Windows build audit no longer requires Bash/WSL; `build_mod.sh` is statically checked on Windows and `bash -n` is POSIX-only.
- `qmllint` non-fatal warnings are summarized by default to keep build logs usable; `-VerboseQmlLint` restores full warning output.

## 7.0.5 Windows PowerShell native-process regression fix

A real Windows build exposed a PowerShell 5.1 integration defect: `qmllint.exe` writes ordinary warnings to stderr, and redirecting native stderr with `2>&1` under `$ErrorActionPreference = 'Stop'` promoted those warnings to `NativeCommandError`, aborting the build despite a successful qmllint exit code. The build wrapper now captures Qt-tool stdout/stderr at the native process layer with `Start-Process`, evaluates the real process exit code, and uses the same mechanism for `rcc.exe`. Non-fatal qmllint warnings are summarized instead of terminating or flooding the console.



## v7.1.0 Responsive Farm adversarial audit

- Replaced scroll-bound HUD/navigation with real sticky chrome. 7.2.2 further removes the Wide left rail after fullscreen QA showed it became visually dominant; Compact uses bottom navigation while Medium/Wide use centered top navigation, with a denser Wide presentation. The Flickable reserves the required top/bottom space so sticky controls do not overlay content.
- Added a dedicated Farm Context Action Bar outside the scrolling farm content; crop/seed state, fertilizer and Next Day remain reachable at the documented phone viewport.
- Effective water state now has one source function (`manual`, `sprinkler`, `rain`, `storm`). Watering target selection uses that same derived state, preventing energy loss from watering a crop already covered by irrigation or weather.
- Plot soil and water-source indicator receive the same derived state, eliminating the previous simulation/visual mismatch where sprinkler-covered crops could grow while still looking dry.
- Harvest-ready plots now use an accent border and basket indicator driven by the shared pulse; no per-plot Timer was introduced.
- Reward feedback uses three pre-created delegate slots and `Repeater.itemAt()` reuse. Harvest/sell/animal/craft/order feedback does not allocate a new QML component for each reward.
- Town Order Reject/Abandon consumes one of three persisted daily refresh actions and places the slot in `cooldownUntil = day + 1`. Immediate free reroll is therefore impossible; completed delivery still generates a normal replacement.
- Internal save schema is now 3 only because order-refresh budget/cooldown state is persistent. Host `save_version: 1` remains unchanged, v7.0.x `snapshot_v2` is promoted, and the normalized v3 payload is mirrored back to `snapshot_v2` for downgrade safety.
- Workshop building and recipe actions explicitly become full-width rows in Compact layout rather than relying on accidental wrapping.
- Validator gates were added for layout classes, sticky chrome, fixed reward pool, effective water state, ready indicator, order budget/cooldown, schema-v3 persistence and Compact Workshop geometry.

### Remaining attack surface / not claimed

No real Qt/QML runtime, LeoMiniGames host, physical Android/iOS device, or desktop GPU/font stack is available in this environment. In particular, actual safe-area behavior, rendered long-locale metrics, touch ergonomics, host lifecycle persistence and `qmllint`/RCC runtime loading remain external smoke-test items.


## v7.2.2 Living Seasons adversarial audit

- Removed the legacy inline `dayTransition`/`dayShade` path so there is one owner for Next Day visual sequencing.
- Day mutation is requested only from `DayTransition.blackoutReached`; the reveal cannot start until season/weather presentation completes.
- Season presentation is conditional on an actual season boundary; weather presentation runs for every committed day.
- All decorative effects use bounded Repeaters and shared progress values. No runtime `createObject`, ParticleSystem, ShaderEffect, MultiEffect, blur or per-effect Timer was introduced.
- Ambient weather animation runs only when the Farm tab and game item are visible, Reduced Motion is off, and no day transition is active.
- Reduced Motion keeps short fades plus static season/weather information instead of deleting state feedback.
- Added validator gates for component/QRC presence, effect assets, blackout commit ordering, bounded pools, visibility gating and removal of the old inline transition path.
- Save schema remains v3 because the new transition/ambient state is intentionally transient.

Static/pure checks cannot prove GPU frame pacing or exact rendered animation behavior on the real host. The Windows/Qt build and device smoke test remain the runtime authority.


## v7.2.2 polish/audio adversarial audit

- Fullscreen regression: the old Wide layout promoted primary navigation to a tall left rail. On large desktop windows this consumed disproportionate visual weight. Main now keeps navigation centered at the top for Medium/Wide, caps Wide navigation at 760 px and main content at 1180 px.
- Transition ownership remains centralized and the gameplay commit still occurs only after the screen reaches full blackout. The visible transition treatment was reduced to small themed cards and smaller fixed SVG pools.
- Persistent weather decoration was separated from the z=940 transition director. `AmbientWeatherLayer.qml` sits below sticky chrome, so effects cannot obscure HUD/navigation/action controls.
- Audio API names were verified against current `GameAudio.h/.cpp` and legacy `AudioManager.h/.cpp`. Modern SFX use `GameAudio.playEffect(url,gain,"sfx")`; legacy fallback uses `Audio.playUrl(url,gain)`. Weather ambience uses `GameAudio.playMusic(url,true,"ambient")` only when available.
- Audio calls are wrapped in capability checks/exception guards. Missing multimedia support, decode failure, or an older host cannot crash or block gameplay.
- Ambient playback is restricted to the visible Farm tab and rain/wind/storm, is stopped during day transitions/unload, and participates in host pause/resume lifecycle.
- WAVs are mono 16-bit PCM at a modest sample rate; validator checks their headers and QRC inclusion. The loops are intentionally low-amplitude rather than mutating host-wide volume preferences.

### v7.2.2 adversarial patch audit

- Multi-input crafting was changed to preflight and commit inventory/quality state atomically; this closes the partial-consumption failure class that is easiest to notice on the Flour + Egg bread recipe.
- Purchase/order/animal/workshop/upgrade/fertilize actions now have explicit host-audio hooks. No action creates QtMultimedia objects inside the mod.
- Tab changes use one shared animation, not per-tab timers or dynamic object creation; Reduced Motion bypasses movement entirely.


## v7.3.0 Smart Fields adversarial audit

Validated derived-vs-persistent state separation, deterministic A-E zone boundaries, partial irrigation coverage, batch watering energy caps, batch fertilizer inventory caps, and single aggregated harvest feedback. Batch actions do not add persistent fields or bypass existing crop/energy/fertilizer economics.


## v7.2.2 preflight before v7.4.0

The exact v7.2.2 source ZIP was unpacked cleanly before starting Smart Fields. Its existing gates passed unchanged: 13036/13036 package validation, 206/206 gameplay regression, 81/81 migration regression and 601/601 meta audit. Additional inspection covered the transactional bread recipe, host-audio event routing, tab transition guard, QRC audio entries and ambient lifecycle conditions. No concrete source/regression defect requiring a 7.2.3 PATCH was found, so development moved directly to 7.4.0 rather than creating an empty version bump. This does not substitute for a fresh real-host device/runtime smoke test.

## v7.4.0 Town Market audit
- Verified accepted orders survive board refresh.
- Verified special orders become visible `Expired` state instead of silently disappearing.
- Verified history is bounded to 40 entries and only canonical v4 persists it.
- Verified v3/v2 mirrors map new terminal states to legacy cooldowns.


## v7.4.2 patch audit

The reported Town Market regressions were reproduced by source-path inspection: `commitNextDay()` still called the removed `syncOrderRejectBudget()` symbol, which could throw during blackout and strand the transition; board refresh could also generate a visually identical card in a small early-game pool. The patch uses `syncOrderRefreshBudget()`, distinct visible-order signatures, disables refresh when no slot is eligible, and adds a bounded transition watchdog/force-finish path. Save schema remains v4.

## v7.4.2 deep recovery audit — harvest / state integrity

This pass was started after the real host/user report that v7.4.1 could still show a farm where harvest did not work. The previous Python regression suite was not accepted as sufficient evidence because much of it modelled gameplay rules separately from the QML implementation.

Concrete findings and fixes:

- **Historical half-committed Next Day state:** v7.4.0 could advance crops/animals/day and then throw before energy reset, lifetime-day accounting and the rest of the commit. A lifecycle save could therefore preserve the new day with stale energy. v7.4.1's first repair signature was too narrow and could also persist `repairRevision = 2` without fixing every affected state. v7.4.2 introduces repair revision **3**, deliberately re-audits revision-2 saves, detects a trailing `lifetimeStats.days < day - 1` signature, restores full daily energy, repairs the day counter, and rewrites the canonical save.
- **Harvest atomicity:** single harvest and batch harvest capture the complete persistent snapshot before mutation. Unexpected failures after energy/inventory/plot mutation restore the exact runtime snapshot.
- **Rollback was initially not exact:** the first v7.4.2 draft used `applySnapshot(before)`. Fault injection proved that `applySnapshot()` normalizes and calls `ensureOrders()`, so empty order slots could be regenerated during rollback. `restoreRuntimeSnapshot()` now restores a known-valid pre-transaction snapshot without normalization or order generation. Harvest, batch harvest, Next Day, selling, order delivery and Community Project progression use this exact rollback path.
- **Hidden/off-tab input:** keyboard and `GameInput` could mutate Farm state while Market/Workshop/Journal was visible, and input could arrive during day/tab transitions. Farm gameplay input is now restricted to the Farm tab and blocked by one `inputLocked` contract while transitions are active. `N` remains the deliberate global Next Day shortcut.
- **Malformed save poisoning:** nested numeric fields could still retain `NaN`, invalid crop ids could fall through `FarmData.cropById()` to the first crop definition, and malformed order/history objects were under-normalized. Nested quality/mastery/animal/project/stat/refresh fields now use finite-number normalization; unknown crop ids become empty plots; order/history item/status/outcome fields are bounded to known values.
- **Mature-crop fertilizer waste:** direct `F` input and batch fertilize could still fertilize a harvest-ready crop even though the action bar hid that action. Ready plots now reject fertilizer in every path, and batch-zone eligibility uses the same predicate.
- **Economy partial commits:** selling, order delivery and Community Project progression now use the same exact snapshot rollback protection as harvest/day commits.

### New evidence layer

`tools/test_runtime_logic.js` extracts and executes the **actual named JavaScript function bodies from `Main.qml`** with the real `js/FarmData.js` in a deterministic Node VM. It covers fresh plant/water/day/harvest, the real `interact()` harvest route, injected harvest/day/sell/order/project failures, revision-2 save recovery, malformed state normalization, mature-crop fertilizer rejection, snapshot round-trip and 1,500 randomized QML-logic actions with state invariants. This closes the previous gap where a separately reimplemented Python model could pass while QML logic regressed.

This is still not a Qt renderer/host execution test. QML bindings, visual geometry, actual `GameSave` disk I/O and device input/audio remain target-runtime smoke-test responsibilities.
