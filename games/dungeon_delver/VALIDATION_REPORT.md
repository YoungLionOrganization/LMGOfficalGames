# Dungeon Delver 6.6.3 — Validation Report

## Automated source validator

Current expected result:

```text
PASS: 9 checks
WARNING: 0
ERROR: 0
```

Validated categories:

- i18n parity/placeholders/QML key coverage: 10 locales, 115 keys
- QRC inner-prefix/mount/alias/runtime-resource contract: 76 resources
- assets: 29 SVGs and 28 WAV SFX
- multicolor actor/enemy SVG requirement
- QML static/save/input/theme/i18n/audio/content contracts
- canonical campaign + active-run save/restore/migration paths
- strict RCC build + mounted QQmlEngine smoke verifier contract
- 250 deterministic procedural-floor connectivity/content-capacity simulations
- run-system regression suite
- version consistency: 6.6.3

## Extended algorithmic stress

Additional tests performed during development:

- 10,000 procedural-map seeds: 0 disconnected maps observed; minimum connected floor-cell count 73.
- 1,000 first-floor seeds: nearby key/chest/shrine/relic/Soul Shard/bomb placement stayed within configured distance limits.
- Class baseline/cooldown/save parity checks: PASS.
- Audio path table vs packaged WAV assets: 28/28 parity PASS.

## Post-build verification contract

`build_mod.bat` and `build_mod.sh` are fail-closed by default. The verifier is designed to:

1. compile the actual RCC;
2. mount it at `/mods/dungeon_delver`;
3. reject doubled mount paths;
4. validate manifest/critical resources;
5. instantiate `Main.qml` without services;
6. instantiate it with LeoMiniGames-style stubs including audio;
7. select Rogue through the runtime new-run path;
8. invoke the active skill and verify cooldown;
9. resize through short-landscape and portrait sizes;
10. fail on syntax errors, ReferenceError/TypeError, invalid assignment, missing resources/modules/types, binding/layout recursion and similar fatal diagnostics.

## Limitations

The target Qt 6.11 toolchain and physical Android/iOS devices are not available in this execution environment. Therefore this report does not claim a real native RCC/QQmlEngine run here or physical-device audio/haptic/touch validation. Those gates run on the user's actual Qt kit during normal strict build.

## 6.6.3 additions

- SVG-only graphical control icons: PASS
- Windows/evdev physical WASD matrix: PASS
- X11 physical WASD matrix: PASS
- macOS physical WASD matrix including native code 0 for A: PASS
