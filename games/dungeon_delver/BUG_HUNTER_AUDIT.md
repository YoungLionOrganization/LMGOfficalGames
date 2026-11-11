# Dungeon Delver 6.6.3 — Bug Hunter Audit

## Audit objective

The previous 6.5.0 source contained substantial new code but still felt almost identical on a phone. This audit therefore tested not only whether features existed in source, but whether they were visible and reachable during the first run.

## Findings and fixes

### [FOUND] New content existed but first-minute gameplay still resembled the old build
The player still opened into a familiar 13x13 maze with most shops/relics/boss systems hidden behind menus or later floors.

### [FIX]
Added a mandatory fresh-run class picker, visible class/skill HUD, persistent mobile skill button, first-floor objective text and near-start placement of Soul Shard/key/chest/shrine/relic/bomb/extra loot.

### [RETEST]
PASS — run-system regression checks first-floor proximity over 1000 generated seeds.

---

### [FOUND] SVG assets were technically present but appeared like old monochrome placeholders
The 6.5 gameplay art was largely single-color stencil SVG displayed through a tinting component.

### [FIX]
Rebuilt hero/enemy/item/environment SVGs as multicolor semantic gameplay art and switched `DungeonCell` gameplay rendering to `Image` so embedded colors survive. Theme tint remains for UI chrome, not gameplay identity.

### [RETEST]
PASS — validator rejects monochrome actor/enemy assets and rejects reintroduction of `ThemedSvgIcon` in the gameplay cell.

---

### [FOUND] Environment style and hero identity were coupled
Choosing a dungeon visual style implicitly changed the hero look.

### [FIX]
Separated `heroClass` from `artStyle`. Sentinel/Rogue/Arcanist retain their own hero art while Iron Keep/Ember Crypt/Moon Ruins control environment presentation.

### [RETEST]
PASS.

---

### [FOUND] Fresh-install class selection could be bypassed by an early autosave
A default run could theoretically become dirty before the player made an explicit class choice.

### [FIX]
`classPickerOpen` is established before floor generation and `markDirty()` refuses to persist the active run while the picker is open. A run becomes saveable after `startNewRunAs()`.

### [RETEST]
PASS — save marker/static contract and class runtime regression.

---

### [FOUND] Audio architecture diverged from the working Gem Cascade mobile pattern
The earlier Dungeon build had a different path and was not sufficiently device-verifiable.

### [FIX]
Ported the proven host-audio probe/preload + Android/iOS pooled `MediaPlayer` fallback structure. Added 28 WAV cues and a Settings `Test Sound` action.

### [RETEST]
PASS source/QRC/path parity. Physical Android playback remains device validation, not claimed here.

---

### [FOUND] Duplicate floor-start audio path after class selection
Class selection and floor generation could both emit the same start cue.

### [FIX]
Removed the duplicate explicit class-selection start call; floor creation owns the floor-start cue.

### [RETEST]
PASS static audit.

---

### [FOUND] New relics inherited Lantern reveal behavior by an overly broad `else`
Bloodstone/Blast Core/Quickglass/Gilded Token unintentionally called `revealAround()` when collected.

### [FIX]
Restricted the reveal side effect to `r === "lantern"`. New relics keep only their intended passive behavior.

### [RETEST]
PASS.

---

### [FOUND] Short landscape screens could lose too much board area to HUD/control chrome

### [FIX]
Added `shortLandscape` behavior, reduced header/control footprint and suppressed the desktop side panel in short-height landscape mode.

### [RETEST]
The post-build QQmlEngine smoke contract now resizes through 800x400 and 360x720. Source-level contract PASS; physical-device geometry remains unverified here.

---

### [FOUND] Existing smoke test proved instantiation but not the new gameplay path

### [FIX]
Expanded smoke logic to create a host-audio stub, select Rogue through the actual runtime function, invoke the class skill, verify cooldown, then resize through short-landscape and portrait dimensions while trapping fatal QML diagnostics.

### [RETEST]
Build contract PASS. Real compilation executes on the user's Qt kit because this environment does not contain the target Qt toolchain.

---

### [FOUND] New active-skill state would be lost if save schema ignored it

### [FIX]
Active snapshot now includes `heroClass`, `skillCooldown`, `guardTurns`, `evadeTurns`, and `turnCount`; restore/sanitization paths mirror those fields.

### [RETEST]
PASS — run-system regression checks write/restore field parity.

## Adversarial generation results

- Validator procedural test: 250 connected 13x13 floors — PASS.
- Separate connectivity stress: 10,000 generated seeds, 0 disconnected maps observed; minimum connected floor-cell count 73.
- First-floor visibility stress: 1000 seeds — guaranteed systems remain within configured start-distance limits.

## Final source audit status

No concrete source-level regression remained after this audit. Physical Android/iOS runtime validation is not claimed.

## 6.6.3 Analyst findings

[FOUND] Logical `Qt.Key_W/A/S/D` changes with the active keyboard layout; Azerbaijani and other layouts could break physical WASD.
[FIX] Added native scan-code fallback matrices for Windows/evdev, X11 and macOS while retaining logical keys and arrows.
[RETEST] PASS - source validator checks all three mapping families.

[FOUND] Mobile D-pad and currency HUD used font glyphs (`triangle`, diamond/star-like symbols) that are not guaranteed by every device font.
[FIX] Added SVG arrows plus coin/shard HUD icons and removed those font-dependent graphical glyphs from QML.
[RETEST] PASS - validator rejects the removed glyph set.
