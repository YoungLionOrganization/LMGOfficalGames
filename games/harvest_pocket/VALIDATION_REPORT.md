# Harvest Pocket 7.4.2 — Validation Report

Status: **SOURCE / LOGIC / RELEASE-STAGING GATES PASS**

v7.4.2 is a recovery/stability PATCH over Town Market. It was produced after real user reports that v7.4.1 could still leave harvesting unusable. v7.5 development remains intentionally frozen until this patch passes the target LeoMiniGames runtime smoke test.

## Automated results

Current source-tree results:

- Actual-QML JavaScript logic harness: **279219 / 279219 PASS**
- Package/source validator: **17087 / 17087 PASS**
- Gameplay regression suite: **257 / 257 PASS**
- Legacy/schema migration suite: **93 / 93 PASS**
- Release-tree meta audit: **630 / 630 PASS**
- Locale catalogs: **10 / 10**, 275 keys each with parity/blank/placeholder/encoding checks

`tools/test_runtime_logic.js` is intentionally separate from the Python gameplay model: it extracts the named JavaScript functions from `Main.qml`, executes those actual bodies together with `js/FarmData.js`, injects failures, and checks state invariants. It is a logic harness, not a Qt renderer.

## Reported failures addressed

### Harvest unavailable after v7.4.x

The harvest function itself works on a fresh deterministic path. The deeper failure class was historical state integrity: v7.4.0 could commit crops/animals/day and then throw before resetting energy and incrementing the lifetime day counter. A lifecycle save could preserve that half-committed day. v7.4.1 added an initial repair marker, but its signature was too narrow.

v7.4.2 uses recovery revision **3**. It deliberately re-audits v7.4.1 revision-2 saves. If `day > 1` while `lifetimeStats.days < day - 1`, the patch repairs the missing completed-day accounting, restores the full daily energy budget, advances the marker to 3, and immediately rewrites the canonical save. The repair is idempotent.

Harvest also has two player-facing paths: direct ready-plot interaction and an explicit sticky **Harvest selected** action.

### Transaction integrity

The first recovery implementation exposed another issue under fault injection: rollback through `applySnapshot()` was not exact because save normalization calls `ensureOrders()` and can generate order cards. v7.4.2 now uses `restoreRuntimeSnapshot()` for known-valid pre-transaction snapshots.

Exact rollback covers:

- single harvest;
- batch harvest;
- Next Day commit;
- selling;
- Town Order delivery;
- Community Project progression.

Injected failures after state mutation are verified to restore the pre-action snapshot.

### Input races / hidden Farm actions

- Farm keyboard actions are active only on the Farm tab.
- `GameInput` farm actions are ignored outside the Farm tab.
- Gameplay input is locked while day or tab transitions are active.
- `N` remains the explicit global Next Day shortcut.

This prevents Enter/Space/gamepad fire from harvesting/planting/watering an invisible plot while another tab is on screen, and prevents state mutation during transition commit/reveal.

### Save hardening

- Unknown crop IDs are cleared to an empty plot rather than falling through to the first crop definition.
- Nested quality/mastery/animal/project/lifetime/refresh/history numeric values are finite-normalized.
- Invalid Town Order item/status payloads are discarded/regenerated.
- Invalid order-history item/outcome records are discarded.
- Crop-quality bucket totals remain reconciled to actual crop inventory.
- Selected plot/seed and progression tiers remain bounded.

Internal save schema remains **4**; host `save_version` remains **1**. `snapshot_v4` stays canonical and v3/v2 downgrade mirrors remain available.

## Gameplay consistency fixes

- Ready crops reject fertilizer from both direct `F` input and batch-zone fertilization; fertilizer cannot be wasted after crop maturity.
- Board Refresh keeps accepted orders, guarantees a visibly changed replacement when a refresh is consumed, and cannot consume budget when no slot is refreshable.
- Next Day keeps transactional commit + watchdog/force-finish protection.
- Market/order history and signed trend/forecast behavior from v7.4.0 remain intact.

## Performance / package checks

- No ParticleSystem, ShaderEffect, MultiEffect or Canvas gameplay dependency was introduced.
- Shared/bounded visual pools and visibility gating remain intact.
- Audio continues through the verified LeoMiniGames `GameAudio`/legacy `Audio` host paths.
- Build/publish scripts retain the Windows PowerShell 5.1-safe native process handling introduced in 7.0.5.
- Source packaging remains deterministic and preserves `build_mod.sh` executable metadata.

## Runtime boundary

This environment does **not** contain the user's Windows Qt 6.11.1 installation or the running LeoMiniGames host, and it cannot perform physical Android/iOS/macOS tests. Therefore this report does not claim:

- real `qmllint`/`rcc` execution on the user's Windows machine;
- Qt/QML renderer/binding behavior inside LeoMiniGames;
- physical mouse/touch/gamepad focus behavior;
- real GameSave disk restart round-trip;
- final speaker loudness/haptics/frame pacing.

Those remain target-runtime smoke tests. The package should not advance to v7.5 until the user confirms the v7.4.2 RCC behaves correctly in that environment.
