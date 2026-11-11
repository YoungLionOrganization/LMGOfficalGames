# Harvest Pocket 7.4.2 — Save Audit

## Persistence contract

Harvest waits until the verified `GameSave.load/get/set/save` and `GameI18n.text` methods exist before loading state. The manifest deliberately remains at host `save_version: 1`, matching the v6.4 contract, so old host slots are not rejected before Harvest can migrate them.

v7.4.x uses internal schema 4. `snapshot_v4` is canonical because Town Market adds persistent board-refresh state, bounded order history and highest-order-reward data. Normalized `snapshot_v3` and `snapshot_v2` downgrade mirrors are still written for older v7 builds. Small scalar compatibility keys (`save_schema`, `day`, `coins`, `farmLevel`, `reputation`) remain separate; nested gameplay objects are not independently pushed through `GameSave.set()`.

## Persistent state

The canonical snapshot includes day/year, coins/energy, XP/level/reputation, selection, world seed and legacy-crop compatibility; tool/irrigation/greenhouse/land/building progression; all 40 plots; inventory and quality buckets; crop mastery harvest counts; animal counts/happiness; processing buildings; three Town Order slots and order serial; the v7.1 order-refresh day/usage budget; Community Project phases; and lifetime statistics.

Responsive layout class, sticky-bar geometry, transient reward toasts, Living Seasons transition progress, ambient weather phase, active animations and warning opacity are UI state and are intentionally not persisted. Season/weather themselves remain deterministic derivatives of the saved day/world seed.

## Write points

Ordinary gameplay mutations mark the save dirty and use the existing debounce. Critical operations force a save: day advancement, animal/building/land/tool infrastructure purchases, order delivery, order reject/abandon, Community Project progression and legacy/schema promotion. Lifecycle pause/background/save/close/unload and component destruction retain the existing dirty-save path.

## v6.4 / host-v1 -> internal-v4 migration

- All 40 legacy plots remain available and `landStage` maps to 4.
- `legacyCropAccess` preserves exactly the six crops exposed by v6.4; newly introduced crops keep their normal level gates.
- Legacy crop inventory becomes Normal-quality stock with reconciled bucket totals.
- Chickens, cows, old happiness and coop/barn levels survive.
- Watering/Sprinkler/Greenhouse values clamp to meaningful v7 ranges.
- A valid legacy Town Order becomes accepted slot 0.
- Legacy reject-budget fields migrate into the v4 board-refresh budget; older saves without them start with a clean current-day refresh budget.
- New animals/apiary/processors/projects are not fabricated from unrelated old progress.

## v7.0.x / v7.1-v7.3 promotion into schema 4

`loadGame()` tries `snapshot_v4` first, then `snapshot_v3`, then `snapshot_v2`. A valid older snapshot is applied through the same normalization path; missing Town Market fields receive safe defaults and the state is rewritten as canonical v4 plus normalized v3/v2 downgrade mirrors.

This preserves existing v7.0.x-v7.3 farms without requiring an unverified host migration callback.

## Defensive normalization

Negative counts are clamped, plot count is normalized to 40, crop-quality buckets are reconciled against actual crop inventory, progression tiers are bounded, selected plot/seed indices are clamped, and the new order-refresh usage is clamped to the daily budget. Long-running coin/XP counters remain QML `real` values.

In canonical v4, Rejected/Abandoned/Completed/Expired remain explicit visible order states for the current day. On the next committed in-game day, terminal slots generate replacements. Only the v3/v2 downgrade mirrors map terminal states to legacy cooldown objects for backward compatibility.

## Automated evidence

`tools/test_migration.py` checks representative/adversarial v6.4, schema-2/schema-3 promotion into schema 4, and downgrade mirrors. `tools/validate_package.py` requires internal schema 4, canonical `snapshot_v4`, downgrade-safe v3/v2 mirrors, and persistence of Town Market fields. `tools/test_gameplay.py` separately checks the three-refresh daily budget, accepted-order protection, distinct refresh output and Next Day transition recovery contract.

## Runtime boundary

The current execution environment cannot launch the real LeoMiniGames host or perform a physical-device disk round-trip. Therefore the full chain `state -> GameSave -> host disk -> process restart -> reload -> equivalent state` still requires a host smoke test after the RCC is built. Static/pure migration evidence is not presented as a physical runtime result.


## v7.2 persistence decision

Living Seasons does not advance the internal save schema. Day, world seed and the existing farm state already reproduce the same season/weather after reload. Transition stage, decorative pool positions and ambient phase are presentation-only and restart safely from defaults, so persisting them would add corruption/race risk without preserving meaningful player progress.


## v7.3.0 save decision

Internal save schema remains v3. Field state, irrigation zone membership, zone coverage, selected-zone UI state and batch-action eligibility are deterministic derivatives of already persisted data and therefore are intentionally not serialized.

## v7.4.0 schema 4
Persistent additions: `orderRefreshDay`, `orderRefreshesUsed`, bounded `orderHistory`, `highestOrderReward`. The host `save_version` remains 1. Canonical state is `snapshot_v4`; v3/v2 compatibility mirrors remain available.


## v7.4.2 patch audit

The reported Town Market regressions were reproduced by source-path inspection: `commitNextDay()` still called the removed `syncOrderRejectBudget()` symbol, which could throw during blackout and strand the transition; board refresh could also generate a visually identical card in a small early-game pool. The patch uses `syncOrderRefreshBudget()`, distinct visible-order signatures, disables refresh when no slot is eligible, and adds a bounded transition watchdog/force-finish path. Save schema remains v4.

## v7.4.2 recovery revision 3

v7.4.2 keeps **internal schema 4** and host `save_version: 1`; the recovery does not require a schema bump. Canonical `snapshot_v4` now also carries `repairRevision`. Current fresh/migrated/repaired state writes revision **3**. The field is deliberately removed from v3/v2 compatibility mirrors.

Revision 3 exists because v7.4.1 could mark a save with revision 2 after a narrower repair pass. v7.4.2 therefore re-audits revision-2 saves. The historical v7.4.0 half-commit signature is `day > 1` with `lifetimeStats.days < day - 1`: crops/animals/day had already advanced, but energy reset and day-stat accounting had not. On that signature, the repair sets `lifetimeStats.days = day - 1`, restores `energy = maxEnergy`, advances the repair marker to 3, and immediately rewrites the canonical save. Re-running the repair is idempotent.

### Exact transaction rollback

A pre-action `snapshot()` is already normalized runtime state. Rollback therefore uses `restoreRuntimeSnapshot()` rather than `applySnapshot()`. This distinction matters: `applySnapshot()` intentionally normalizes and calls `ensureOrders()`, which may regenerate empty order slots and would not be an exact rollback. The exact path is used for single/batch harvest, Next Day, sale, order delivery and Community Project progression.

### Corruption containment

Save normalization now clears unknown crop ids instead of allowing `FarmData.cropById()` fallback to reinterpret them as Turnip. Nested quality inventory, crop mastery, animal counts/mood, project levels, lifetime counters, board-refresh counters and history numbers are finite-normalized. Invalid order items/statuses and invalid history item/outcome combinations are discarded/regenerated rather than entering UI/gameplay state.
