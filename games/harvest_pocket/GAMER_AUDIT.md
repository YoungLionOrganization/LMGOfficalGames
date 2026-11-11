# Harvest Pocket 7.4.2 — Gamer / Multi-Platform QA

## Gameplay assessment

The original farm loop was functional but exhausted quickly: six crops, direct selling, two numeric animal counters and several upgrades that stopped producing value while still accepting coins. Version 7 turns the same core into a longer farm progression rather than replacing it with an unrelated game.

The player now progresses from a 12-plot manual farm to a 40-plot automated farm. Crop choice changes by season, unlock level, growth time, value and processing use. Crop quality and mastery give repeated harvests a purpose. Animal husbandry connects feed, building capacity, happiness and output. Processing links crop and animal inventories. Town Orders convert production choices into explicit objectives, while eight five-phase Community Projects provide a persistent late-game resource sink without resetting the farm.

## Visual/interaction assessment

- Fields use actual furrow/soil SVG textures with dry/wet/fertile/winter states instead of plain brown rectangles.
- All gameplay iconography is SVG; emoji/Unicode icons are not used as game visuals.
- Crops visibly progress through five growth illustrations.
- Plant, water, fertilize, growth and harvest transitions provide local feedback.
- Crops use selective idle sway and stronger wind behavior without continuously animating every plot.
- Animals have idle/happy/sleep visual states and lightweight behavior; huge herds render at most six representative sprites plus the numeric population.
- Touch interaction does not spend fertilizer implicitly.
- Keyboard and host action input remain available for desktop play.
- The package does not guess a `Viewport` safe-area API that is absent from the supplied v6.4 contract; the host game viewport is expected to provide its usable content rectangle, while Harvest keeps internal page padding. Physical notch/safe-area behavior remains a device-test item.
- Reduced Motion disables/minimizes ambient movement.

## Low-end target

The design intentionally avoids per-plot and per-animal timers, particle systems, blur/MultiEffect chains, ShaderEffect and Canvas rendering. There are three root Timers: one startup-only service retry that stops after initialization, a short save debounce, and one shared visual pulse. Hidden Farm/Animals animation work is stopped by tab visibility. SVG assets are small and cached through normal Qt Quick `Image` elements.

## Platform expectations

Windows/Linux/macOS: mouse + keyboard and scalable SVG presentation are implemented in QML. Android/iOS: tap targets, scrolling, safe-area insets and reduced animation load were considered. The same RCC resources are architecture independent.

These statements are code/audit expectations, **not physical-device test claims**. The package still needs real host testing at phone-size and desktop-size viewports, especially long German/Russian text, touch density and haptic strength.

## v7.0.3 visual QA

The mature crop set was redrawn for faster visual recognition: root crops sit at soil level, corn/wheat/sunflower use crop-specific silhouettes, vine crops visibly spread, and winter/fantasy crops no longer look like recolored generic stems. Animal silhouettes and facial features were realigned. Soil now reads as furrowed farm ground rather than a flat brown card while retaining a very low rendering cost.

## v7.0.3 planting UX re-test

The Farm tab now defaults to **This season**, with **All crops** as an explicit secondary view. Each crop card shows four compact SVG season markers, the current season is highlighted, and the selected crop summary shows valid seasons, growth days, seed stock, purchase price, and whether it can be planted now / greenhouse-only / out of season. This removes the previous trial-and-error loop where the player learned season compatibility only after tapping a plot.

## v7.0.4 UX re-test

The previously ambiguous first `Next Day` press is now visibly a safety confirmation rather than an apparent missed click: the farm shakes, danger edges flash inward, a warning banner appears and the button changes to a confirm action. The actual day transition uses a short fade-to-black/fade-back sequence. Long translations fit the shared button cards more reliably, and changing language no longer leaves the prior language's status message on screen. Seasonal keyboard/gamepad crop selection now matches the visible crop chooser.

Physical-device testing is still required for final animation feel, safe-area behavior and host-specific language-change signals.

## v7.0.5 compact-screen re-test boundary

Static layout review found two player-facing regressions that were credible at the documented 360 px Android target: navigation could become a tall single-button column, and Workshop action cards could place their action button outside the usable card width. The existing controls now wrap/size within the available row width, while wide-screen behavior remains based on the same Flow/implicit-size system. Journal project actions received the same overflow fix.

This is source/static QA only. No physical Android/iOS device or real LeoMiniGames host was available, so touch ergonomics, safe-area behavior and actual rendered font metrics remain **NOT PHYSICALLY TESTED**.


## v7.1.0 Responsive Farm player re-test

The main interaction hierarchy is materially clearer on both phone-sized and desktop-sized layouts. On Compact screens the five primary destinations stay in a fixed bottom navigation instead of consuming vertical farm content; the Farm Context Action Bar keeps the selected crop, seed purchase, fertilizer and Next Day available without scrolling back through the page. Medium and Wide use centered sticky top navigation; Wide switches to a denser capped-width presentation so fullscreen desktop does not waste space on an oversized side rail.

Watering feedback now matches player expectation: sprinkler/rain/storm coverage visibly wets the plot and shows its source, and tapping that crop does not spend another unit of energy. Ready crops are easier to identify through the basket/accent treatment without relying on color alone. Reward feedback is short and pooled rather than opening persistent cards.

Town Orders have a clearer decision loop: Available -> Accept/Reject, Accepted -> Deliver/Abandon. Reject/Abandon is intentionally limited to three daily refresh actions and the affected slot waits until the next day, so players cannot fish endlessly for the best reward.

Workshop cards now deliberately change layout in Compact mode; their action moves to a full-width row rather than becoming a narrow or off-screen control.

This is source/static QA, not a physical-device claim. Windows/Linux/macOS resizing, Android/iOS safe-area/touch feel, actual long German/Russian/Japanese font metrics, haptic strength and low-end frame pacing still require the real host/devices.


## v7.2.2 Living Seasons player re-test

The day change now has a readable hierarchy instead of a generic fade. A dry-crop warning still appears first when needed; after confirmation the screen reaches blackout before gameplay state changes. Crossing a season boundary adds a dedicated season beat, then the new day's weather is presented, then the farm returns. Same-season days skip the redundant season beat.

The Farm tab now communicates current weather without requiring the player to read the HUD alone: rain/storm streaks, moving clouds, wind lines, heat shimmer motifs, frost crystals and a sun treatment are available as lightweight SVG ambience. Wind and storm remain visible in crop sway. Reduced Motion keeps static/fade information but removes the continuous decorative movement.

No claim is made that Android/iOS safe-area rendering, desktop resize animation smoothness or low-end frame pacing has been physically measured here. Those require the built RCC in the real LeoMiniGames host and target devices.


## v7.2.2 fullscreen/effects/audio re-test

The previous Wide left navigation was too visually heavy in fullscreen desktop use. 7.2.2 keeps the primary navigation centered and compact at large widths while also capping the playable content column. This should preserve hierarchy from a small tablet/window up through 1080p/1440p/4K desktop instead of stretching controls with the viewport.

Living Seasons feedback is intentionally less theatrical: fewer petals/leaves/rain elements, lower opacity, compact season/weather cards, and ambient visuals underneath rather than over the persistent HUD/navigation. Day advancement still gives a clear blackout/state-change cue without turning the entire UI into a long effect sequence.

The new audio set is restrained rather than arcade-like: planting, watering, sprinkler, harvest, sale, craft, animal production and day change get short cues; rain/wind/storm use quiet ambience only while the Farm view is relevant. This environment cannot audition the final loudness through the real host/device output path, so perceived loudness on Windows speakers and Android/iOS hardware remains a real-device QA item.

### v7.2.2 player-facing patch

Economy and progression actions now acknowledge the click with short, subdued sounds instead of leaving successful purchases/orders/workshop interactions silent. Tab changes use a small fade/slide so navigation feels connected without slowing repeated use. Reduced Motion keeps navigation instant.


## v7.3.0 Smart Fields player audit

Smart Fields exposes why a plot is wet and where sprinkler coverage ends without placing large labels on every tile. Batch actions remain locked until mid-game progression so early manual play is preserved. The selected zone is visually subtle and the controls live below the farm grid rather than crowding the sticky action bar.

## v7.4.0 Town Market gamer review
- Order state is now readable before and after every action.
- Market percentages are signed deltas rather than opaque 82–124% multipliers.
- Forecast communicates direction without pretending to know an exact future price.
- Accepted work is protected from board refresh and special deadlines are visible.


## v7.4.2 patch audit

The reported Town Market regressions were reproduced by source-path inspection: `commitNextDay()` still called the removed `syncOrderRejectBudget()` symbol, which could throw during blackout and strand the transition; board refresh could also generate a visually identical card in a small early-game pool. The patch uses `syncOrderRefreshBudget()`, distinct visible-order signatures, disables refresh when no slot is eligible, and adds a bounded transition watchdog/force-finish path. Save schema remains v4.

## v7.4.2 harvest/recovery player re-test

The player-facing recovery goal is that a mature crop has an obvious, reliable path to collection even after upgrading from a broken v7.4.x session. A selected ready plot now exposes **Harvest selected** in the sticky Farm action bar in addition to direct plot tap/Enter interaction. If energy is legitimately exhausted, the action communicates that state instead of silently doing nothing.

A historical interrupted-day save is re-audited even if v7.4.1 already wrote its earlier repair marker. When the day counter proves that a day was half committed, v7.4.2 restores the daily energy budget and repairs the lifetime day counter once. This specifically addresses a farm that visually progressed into a new day but retained stale energy.

Input behavior is also less surprising: Farm controls no longer react behind Animals/Market/Workshop/Journal, and gameplay actions are ignored during day/tab transitions. Harvest-ready plots cannot consume fertilizer from keyboard or batch actions.

The Node logic harness verifies the same JavaScript function bodies used by QML, including randomized action sequences and forced mid-transaction failures. The actual rendered Qt controls, real mouse/touch focus behavior and host save restart still need the built RCC in LeoMiniGames; those are not claimed as physically tested here.
