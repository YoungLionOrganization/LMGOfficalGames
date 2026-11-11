# Gem Cascade 6.7.0 — Bug Hunter Audit

## Physical-phone feedback addressed

[FOUND] 6.6.0 produced no audible SFX on the tested phone.  
[FIX] The SoundEffect-only path was replaced with host-aware routing plus an Android/iOS-preferred pooled `MediaPlayer` RCC fallback.  
[RETEST] Source/audio contract PASS. Physical-device retest is still required by the user.

[FOUND] Bottom Hammer/Shuffle/Cross/+5 controls disappeared on mobile.  
[ROOT CAUSE] `BoosterButton.qml` referenced `UiButton.qml`'s private lexical id `shortcut`; derived QML components cannot use that id.  
[FIX] Booster sizing is now self-contained and the actions Flow explicitly keeps `implicitHeight`.  
[RETEST] Static mobile booster regression gate PASS.

[FOUND] Special gems did not read strongly enough at phone scale.  
[FIX] Theme-aware 2 px special border, compact special badge, dedicated overlay SVG and subtle pulse added.  
[RETEST] Source-level visual contract PASS.

[FOUND] Large clears lacked impact feedback.  
[FIX] Strength-scaled 190 ms board shake + flash/ring + 6 lightweight burst points; only special/large clears trigger it. Haptics scale light/medium/heavy and obey the vibration toggle.  
[RETEST] QML/static contract PASS.

[FOUND] Lifecycle rollback contained writes to undeclared `pendingClearPlan` and `comboContext`, a potential `Invalid write to global property` runtime error.  
[FIX] Removed those undeclared assignments.  
[RETEST] Validator explicitly rejects their reintroduction.

## Gameplay regression

- Special creation / direct activation / special combinations: PASS
- Illegal-swap isolation: PASS
- Pathological RNG generation/shuffle fallback: PASS
- 1000 generation → shuffle → cascade iterations: PASS
- Campaign feasibility smoke: PASS

## 6.7.0 Analyst findings

[FOUND] Desktop could report a successful GameAudio call while mounted-RCC playback remained silent.
[FIX] Local MediaPlayer pool is attempted first on all platforms, with GameAudio fallback.
[RETEST] PASS - 17 WAV resources and routing contract validated.

[FOUND] Gameplay icon rendering depended on Canvas tint plus several Unicode HUD glyphs, increasing Windows/font/backend variance.
[FIX] Core gameplay symbols use plain SVG Image rendering and ASCII HUD values.
[RETEST] PASS - validator rejects Canvas dependency in GemCell/BoosterButton and font-dependent gameplay glyphs.

## 6.7.0 runtime/reward hotfix

- Fixed `GemCell.qml` radius bindings that produced repeated `Unable to assign [undefined] to double` diagnostics on Windows.
- Removed `enabled` property shadowing from audio QML components.
- Added deterministic non-farmable booster progression and reward regression coverage.
