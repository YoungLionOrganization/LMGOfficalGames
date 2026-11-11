# Dungeon Delver 6.6.3 — Gamer / Multi-Platform QA

> Source-level/platform-behavior review, not physical-device validation.

## First 30 seconds

The 6.6.3 build is intentionally easy to distinguish from the previous build:

- a class picker appears before the first run;
- the header visibly shows `v6.6.3`;
- class portrait/name/skill are visible in the HUD;
- first-floor objective text points to loot/economy systems;
- key/chest/shrine/relic/Soul Shard/bomb are exposed near the starting area;
- gameplay actors use colored SVG art instead of monochrome stencil presentation.

Verdict: the first-run experience now communicates that this is a materially expanded game rather than the same maze with hidden backend additions.

## Windows

**Controls:** WASD/arrows, F/Space skill, H potion, B bomb, E shop, Esc overlays/settings. Mouse works for UI.

**UI:** desktop side panel exposes skill, inventory, relics, progression and shop without hiding them behind later discovery.

**Performance:** effects use lightweight rings/low-amplitude board shake rather than blur-heavy layers.

**Verdict:** source-level design is suitable for desktop roguelike play. Physical executable not tested here.

## Linux

Same keyboard/mouse path as Windows. No Windows-only gameplay assumptions were introduced. POSIX build script remains available.

**Verdict:** source-level PASS; no physical/runtime test claimed.

## Android

**Controls:** swipe movement plus D-pad; persistent active-skill/Potion/Bomb/Shop/Options actions.

**UI:** SafeArea-aware layout and short-landscape behavior reduce board compression.

**Audio:** Android/iOS prefer pooled local QtMultimedia playback for RCC WAVs, with host audio as alternate path. Settings includes Test Sound.

**Haptics:** guarded and independently toggleable.

**Verdict:** materially improved mobile interaction model, but actual phone testing is still required for audio backend, touch threshold and vibration strength.

## iOS

Uses the same mobile control/audio fallback design and SafeArea-sensitive layout.

**Verdict:** source-level PASS; physical iOS validation not performed.

## macOS

Desktop keyboard/mouse controls and host-first audio path apply. Build script supports POSIX shell.

**Verdict:** source-level PASS; physical macOS validation not performed.

## Gameplay/content verdict

The game now has a clearer run identity:

- class choice changes stats and active tactics;
- skills create turn-to-turn decisions;
- visible first-floor loot teaches the economy;
- in-run coins and persistent Soul Shards have separate purposes;
- eight relics provide build variation;
- bosses gate progression every fifth floor;
- three independent environment styles improve replay variety.

The remaining highest-value test is a real Android session covering Test Sound, landscape rotation, D-pad/swipe feel, skill button ergonomics and save/restore after backgrounding.

## 6.6.3 desktop-control review

Desktop input now has three layers: LeoMiniGames GameInput, arrow/logical keys, and physical QWERTY scan-code fallback. This specifically addresses layout switching without changing the mobile swipe/D-pad experience. D-pad and currency feedback no longer depend on Unicode symbol fonts. Physical-device Windows/Linux/macOS validation is still required.
