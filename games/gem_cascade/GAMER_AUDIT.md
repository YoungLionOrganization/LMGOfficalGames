# Gem Cascade 6.7.0 — Gamer / Multi-Platform QA

## Android / iOS behavior review

The 6.7.0 pass specifically targets the reported phone issues: visible bottom boosters, larger special-state distinction, direct special activation, local RCC audio via `MediaPlayer`, and short haptic/shake impact feedback. Touch targets remain metric-based and the board still uses SafeArea-aware sizing.

## Desktop behavior review

Desktop keeps mouse/keyboard controls. Audio prefers the LeoMiniGames host mixer when available; the local QtMultimedia pool remains a fallback. Impact shake is intentionally low amplitude and does not affect normal clears.

## Visual feel

Effects are deliberately restrained: no blur stack, no full particle engine and no permanent screen effects. Special gems use a small badge, icon and pulse; high-impact clears add only a short flash/ring/burst and board displacement.

## Test limitation

This package has source-level/static and simulation validation in this environment. The user's previous 6.6.0 phone test is real physical-device evidence, but 6.7.0 itself must still be installed on Android/iOS to confirm device audio/haptic backend behavior.

## 6.7.0 PC review

The desktop pass prioritizes predictable visuals and controls: plain SVG rendering, physical-layout keyboard fallback, MediaPlayer-first audio and unchanged deterministic BoardLogic. Windows/Linux/macOS physical-device verification remains pending; Android behavior is intentionally preserved from the user-confirmed working branch.

## 6.7.0 runtime/reward hotfix

- Fixed `GemCell.qml` radius bindings that produced repeated `Unable to assign [undefined] to double` diagnostics on Windows.
- Removed `enabled` property shadowing from audio QML components.
- Added deterministic non-farmable booster progression and reward regression coverage.

## 6.7.0 Gamer review

The player now receives useful hints rather than merely the first legal swap. Board starts have more agency, colour distribution is less drought-prone, and refill is less likely to force a no-move shuffle immediately after a clear. The system deliberately does not guarantee cascades or objective colours; randomness remains meaningful.

Measured algorithm sample: 500 opening/refill boards, ~10.36 legal opening moves average, 5.14 opening colour-spread average, 4.82 refill-spread average, 0 dead refills, and smart hint beat the first legal move in 427/500 sampled boards.
