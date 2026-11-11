# Gem Cascade 6.7.0 — Validation Report

## Final source result

`python3 tools/validate_source.py`

```text
PASS — 11 checks, 0 warnings, 0 errors
```

Validated areas:

- 10 locale files / 54-key parity and placeholder coverage
- RCC inner prefix `/`, aliases, mounted runtime paths and all runtime resources
- 15 SVG assets
- QML state/service/theme/input/static contracts
- version consistency: `6.7.0`
- canonical save/restore/migration/lifecycle paths
- fail-closed RCC + QQmlEngine post-build verifier contract
- audio: `GameAudio` adapter + Android/iOS `MediaPlayer` fallback + 17 valid WAV assets
- generated-board/legal-move/gravity/refill/cascade simulation
- BoardLogic adversarial suite including 1000 generation/shuffle/cascade iterations
- campaign feasibility smoke

## Gameplay regression

The 1000-iteration BoardLogic suite passed special creation, direct activation, special+special combinations, illegal-swap isolation, pathological RNG fallback, shuffle special preservation and bounded cascades.

The fast campaign gate passed 120 simulations across levels 1–15 with an 88.3% greedy-bot completion average. This is a mathematical feasibility smoke test, not a human fun/difficulty score.

## Mobile-specific gates

- `BoosterButton.qml` may not reference the base component's private `shortcut` id.
- Bottom actions Flow retains implicit height.
- Haptics/vibration toggle exists in the pause overlay and persists in the campaign snapshot.
- Special/large clears have bounded 190 ms impact feedback; normal match clears do not trigger board shake.
- Android/iOS prefer the isolated `MediaPlayer` RCC path rather than the 6.6.0 SoundEffect-only path.

## Negative regression gates

- Deliberately restoring `prefix="/mods/gem_cascade"` is rejected by the validator.
- Deliberately reintroducing a private `shortcut` id reference in `BoosterButton.qml` is rejected.

## Runtime test limitation

This environment does not provide the user's Qt 6.11.1 Android kit or a physical Android/iOS device. `build_mod.bat` / `build_mod.sh` therefore retain the mandatory mounted-RCC QQmlEngine smoke gate for the user's Qt kit. Physical-device audio/haptic confirmation remains required after installation.

## 6.7.0 desktop gates

- Plain SVG/Image gameplay symbols: PASS
- Font-dependent gameplay glyph scan: PASS
- Physical Windows/Linux/macOS key matrix: PASS
- 17 local WAV MediaPlayer-first routing: PASS

## 6.7.0 runtime/reward hotfix

- Fixed `GemCell.qml` radius bindings that produced repeated `Unable to assign [undefined] to double` diagnostics on Windows.
- Removed `enabled` property shadowing from audio QML components.
- Added deterministic non-farmable booster progression and reward regression coverage.

## 6.7.0 algorithm validation

- Source validator: 13 PASS / 0 warning / 0 error.
- Gamer algorithm audit: 500 boards PASS.
- BoardLogic generation/shuffle/cascade stress: 300 iterations PASS.
- Smart campaign simulation: 180 runs at 92.2% average completion in the sampled 12-seed pass. This is a feasibility signal, not a human-fun score.
- Booster economy replay-farming regression: PASS.
