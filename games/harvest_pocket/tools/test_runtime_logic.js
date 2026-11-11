#!/usr/bin/env node
'use strict';

// Executes the actual JavaScript function bodies embedded in Main.qml instead
// of re-implementing gameplay rules in another language. This is not a Qt/QML
// renderer test; it is a deterministic logic harness for state transitions.
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.resolve(__dirname, '..');
const mainText = fs.readFileSync(path.join(ROOT, 'Main.qml'), 'utf8');
const farmDataText = fs.readFileSync(path.join(ROOT, 'js', 'FarmData.js'), 'utf8').replace(/^\.pragma library\s*/, '');

function extractNamedFunctions(text) {
    const result = [];
    const seen = new Set();
    const re = /\bfunction\s+([A-Za-z_]\w*)\s*\(([^)]*)\)\s*\{/g;
    let match;
    while ((match = re.exec(text)) !== null) {
        const name = match[1];
        if (seen.has(name)) continue;
        let i = text.indexOf('{', match.index);
        let depth = 0;
        let quote = null;
        let escaped = false;
        let lineComment = false;
        let blockComment = false;
        for (; i < text.length; ++i) {
            const ch = text[i];
            const nx = i + 1 < text.length ? text[i + 1] : '';
            if (lineComment) {
                if (ch === '\n') lineComment = false;
                continue;
            }
            if (blockComment) {
                if (ch === '*' && nx === '/') { blockComment = false; ++i; }
                continue;
            }
            if (quote !== null) {
                if (escaped) escaped = false;
                else if (ch === '\\') escaped = true;
                else if (ch === quote) quote = null;
                continue;
            }
            if (ch === '/' && nx === '/') { lineComment = true; ++i; continue; }
            if (ch === '/' && nx === '*') { blockComment = true; ++i; continue; }
            if (ch === '"' || ch === "'" || ch === '`') { quote = ch; continue; }
            if (ch === '{') ++depth;
            else if (ch === '}') {
                --depth;
                if (depth === 0) {
                    result.push(text.slice(match.index, i + 1));
                    seen.add(name);
                    break;
                }
            }
        }
    }
    return result.join('\n\n');
}

const farmCtx = {};
vm.createContext(farmCtx);
vm.runInContext(farmDataText, farmCtx, {filename: 'FarmData.js'});
const FarmData = farmCtx;

const c = {
    console: {log: console.log, warn() {}, error: console.error}, FarmData, Math, JSON, Date, String, Number, Boolean, Object, Array,
    Qt: { resolvedUrl: x => String(x), callLater: f => f() },
    GameStats: { increment() {}, submitHighScore() {} },
    Achievements: { unlock() {} }, GameEvents: { emitEvent() {} },
    rewardLayer: { show() {} }, saveDebounce: { stop() {}, restart() {} },
    warningEdge: { stop() {}, restart() {} }, warningShake: { stop() {}, restart() {} },
    visualFeedback: { beginDay() { return true; }, forceFinish() {}, commitApplied() {} },
    tabSwitchAnimation: { running: false, restart() {} }, scroll: { contentY: 0 },
    GameSettings: { value: (k, fallback) => fallback },
    Haptics: { light() {}, medium() {}, heavy() {} },
    GameI18n: { text: (k, fallback) => fallback || k },
    GameAudio: { playEffect() {}, preload() {}, stopMusic() {}, playMusic() {}, pauseAll() {}, resumeAll() {} },
    Audio: { playUrl() {}, preload() {} },
    GameSave: { load() { return false; }, get: (k, fallback) => fallback, set() {}, save() {} },
    width: 1280, visible: true, focus: true,
    saveSchema: 4, plotCount: 40, orderRefreshBudget: 3, columns: 8, rows: 5,
    activeTab: 0, day: 1, year: 1, coins: 80, energy: 16, maxEnergy: 16,
    farmXp: 0, farmLevel: 1, reputation: 0, selectedPlot: 0, selectedSeed: 0,
    animationPulse: 0, worldSeed: 12345, message: '', saveDirty: false, gameLoaded: true,
    visualActionSerial: 0, visualActionPlot: -1, visualActionKind: '',
    nextDayWarningArmed: false, nextDayTransitionRunning: false,
    warningShakeOffset: 0, warningEdgeOpacity: 0, i18nRevision: 0,
    legacyCropAccess: false, showAllCrops: false, ambientAudioKey: '', audioPreloaded: false,
    pendingTab: -1, tabSlideDirection: 1, tabContentOpacity: 1, tabContentOffset: 0,
    initializationDone: true, repairRevision: 0,
    wateringTier: 1, sprinklerLevel: 0, greenhouseLevel: 0, landStage: 0,
    coopLevel: 0, barnLevel: 0, apiaryLevel: 0,
    plots: [], inventory: {}, qualityInventory: {}, cropHarvests: {}, animalCounts: {},
    animalMood: {}, processingBuilt: {}, orders: [], orderSerial: 0,
    orderRefreshDay: 1, orderRefreshesUsed: 0, orderHistory: [], highestOrderReward: 0,
    projectLevels: {}, lifetimeStats: {}, reducedMotion: false, visualQuality: 'balanced', showHints: true,
    forceActiveFocus() {}
};
vm.createContext(c);
const define = (name, getter) => Object.defineProperty(c, name, {configurable: true, enumerable: true, get: getter});
define('seasonIndex', () => Math.floor(((c.day - 1) % 28) / 7));
define('seasonDay', () => ((c.day - 1) % 7) + 1);
define('seasonKey', () => ['season_spring','season_summer','season_autumn','season_winter'][c.seasonIndex]);
define('weather', () => c.weatherForDay ? c.weatherForDay(c.day) : 'sunny');
define('activePlotCount', () => FarmData.landCounts[Math.max(0, Math.min(FarmData.landCounts.length - 1, c.landStage))]);
define('sprinklerCount', () => FarmData.sprinklerCoverage[Math.max(0, Math.min(5, c.sprinklerLevel))]);
define('greenhouseCount', () => FarmData.greenhouseCoverage[Math.max(0, Math.min(5, c.greenhouseLevel))]);
define('effectiveSprinklerCoverage', () => Math.min(c.activePlotCount, c.sprinklerCount + Number(c.projectLevels.irrigation || 0) * 2));
define('selectedCrop', () => FarmData.crops[Math.max(0, Math.min(FarmData.crops.length - 1, c.selectedSeed))]);
define('cropChooserIndexes', () => c.buildCropChooserIndexes());
define('xpNeeded', () => c.farmLevel * 45);
define('marketVegetable', () => c.categoryMarket('vegetable'));
define('marketFruit', () => c.categoryMarket('fruit'));
define('marketGrain', () => c.categoryMarket('grain'));
define('marketAnimal', () => c.categoryMarket('animal'));
define('marketProcessed', () => c.categoryMarket('processed'));
define('orderRefreshRemaining', () => Math.max(0, c.orderRefreshBudget - (c.orderRefreshDay === c.day ? c.orderRefreshesUsed : 0)));
define('refreshableOrderCount', () => c.countRefreshableOrders());
define('selectedIrrigationZone', () => Math.max(0, Math.min(4, Math.floor(Math.max(0, c.selectedPlot) / 8))));
define('batchWaterUnlocked', () => c.wateringTier >= 3);
define('batchFertilizeUnlocked', () => c.farmLevel >= 8);
define('batchHarvestUnlocked', () => c.farmLevel >= 10);
define('dryFieldCount', () => c.countDryGrowingPlots());
define('readyFieldCount', () => c.countReadyPlots());
define('selectedZoneFertilizableCount', () => c.countFertilizableInZone(c.selectedIrrigationZone));
define('selectedPlotState', () => c.plotState(c.selectedPlot));
define('selectedPlotReady', () => c.isHarvestReady(c.selectedPlot));

vm.runInContext(extractNamedFunctions(mainText), c, {filename: 'Main.qml.functions.js'});
c.root = c;

let checks = 0;
function ok(cond, message) { ++checks; if (!cond) throw new Error(message); }
function deep(value) { return JSON.parse(JSON.stringify(value)); }
function assertCoreInvariants(tag) {
    ok(Number.isFinite(c.coins) && c.coins >= 0, `${tag}: coins invalid`);
    ok(Number.isFinite(c.energy) && c.energy >= 0 && c.energy <= c.maxEnergy, `${tag}: energy invalid`);
    ok(Array.isArray(c.plots) && c.plots.length === 40, `${tag}: plot count`);
    const validCrops = new Set(FarmData.crops.map(x => x.id));
    for (let i = 0; i < c.plots.length; ++i) {
        const p = c.plots[i];
        ok(p && typeof p === 'object', `${tag}: plot ${i} object`);
        ok(p.crop === '' || validCrops.has(p.crop), `${tag}: plot ${i} crop`);
        ok(Number.isFinite(Number(p.age)) && Number(p.age) >= 0, `${tag}: plot ${i} age`);
    }
    for (const [key, value] of Object.entries(c.inventory))
        ok(Number.isFinite(Number(value)) && Number(value) >= 0, `${tag}: inventory ${key}`);
    for (const crop of FarmData.crops) {
        const q = c.qualityInventory[crop.id] || {};
        const total = ['normal','fine','premium','perfect'].reduce((a, key) => a + Number(q[key] || 0), 0);
        ok(total === Number(c.inventory[crop.id] || 0), `${tag}: quality stock mismatch ${crop.id}`);
    }
}

// Real fresh-game path: plant -> water -> day -> water -> day -> harvest.
c.initializeFreshGame(); c.gameLoaded = true; c.worldSeed = 7;
c.plant(0); ok(c.plots[0].crop === 'turnip', 'fresh plant failed');
c.water(0); ok(c.plots[0].watered, 'fresh water failed');
ok(c.commitNextDay() === true && c.day === 2 && c.plots[0].age === 1, 'first day commit failed');
c.water(0); ok(c.commitNextDay() === true && c.day === 3 && c.isHarvestReady(0), 'crop did not become ready');
const beforeHarvest = Number(c.inventory.turnip || 0);
const harvested = c.harvest(0);
ok(harvested && harvested.id === 'turnip', 'direct harvest returned no result');
ok(c.plots[0].crop === '' && Number(c.inventory.turnip) > beforeHarvest, 'direct harvest did not commit');

// The actual interact() path must also harvest a mature selected plot.
c.inventory.turnipSeed = 1; c.plant(1); c.plots[1].age = 2; c.energy = 10;
const beforeInteract = Number(c.inventory.turnip || 0); c.interact(1);
ok(c.plots[1].crop === '' && Number(c.inventory.turnip) > beforeInteract, 'interact() could not harvest ready crop');

// Harvest transaction rollback: injected failure after energy has been charged.
c.inventory.turnipSeed = 1; c.plant(2); c.plots[2].age = 2; c.energy = 9;
const harvestRollbackBefore = deep(c.snapshot());
const realQualityFor = c.qualityFor;
c.qualityFor = function() { throw new Error('injected harvest failure'); };
const failedHarvest = c.harvest(2);
c.qualityFor = realQualityFor;
ok(failedHarvest === null, 'failed harvest must return null');
ok(c.day === harvestRollbackBefore.day && c.energy === harvestRollbackBefore.energy, 'harvest rollback lost scalar state');
ok(JSON.stringify(c.plots) === JSON.stringify(harvestRollbackBefore.plots), 'harvest rollback lost plot state');
ok(JSON.stringify(c.inventory) === JSON.stringify(harvestRollbackBefore.inventory), 'harvest rollback lost inventory state');

// Next Day transaction rollback: injected historical failure point after day mutation.
c.plots[3] = {crop:'turnip', age:0, watered:true, fertilized:false}; c.energy = 4;
const dayRollbackBefore = deep(c.snapshot());
const realSyncBudget = c.syncOrderRefreshBudget;
c.syncOrderRefreshBudget = function() { throw new Error('injected next-day failure'); };
const dayCommitted = c.commitNextDay();
c.syncOrderRefreshBudget = realSyncBudget;
ok(dayCommitted === false, 'failed day commit must report false');
ok(c.day === dayRollbackBefore.day && c.energy === dayRollbackBefore.energy, 'day rollback lost scalar state');
ok(JSON.stringify(c.plots) === JSON.stringify(dayRollbackBefore.plots), 'day rollback lost crop state');

// Known v7.4.0 partial-day save repair: ready crop + zero energy + days counter trailing.
c.initializeFreshGame(); c.gameLoaded = true; c.day = 4; c.lifetimeStats.days = 2; c.energy = 3; c.repairRevision = 0;
c.plots[0] = {crop:'turnip', age:2, watered:false, fertilized:false};
ok(c.repairKnownState() === true, 'partial-day repair was not applied');
ok(c.energy === c.maxEnergy && c.lifetimeStats.days === 3 && c.repairRevision === 3, 'partial-day repair did not restore energy/day stat/revision');
const repairedEnergy = c.energy; ok(c.repairKnownState() === false && c.energy === repairedEnergy, 'repair must be idempotent');

// v7.4.1 may already have persisted repairRevision=2 even when its narrower
// signature did not repair a non-zero-energy partial day. v7.4.2 revision 3
// must deliberately re-audit those saves.
c.initializeFreshGame(); c.day = 9; c.lifetimeStats.days = 7; c.energy = 2; c.repairRevision = 2;
ok(c.repairKnownState() === true, 'v7.4.1 repairRevision=2 save was not re-audited');
ok(c.energy === c.maxEnergy && c.lifetimeStats.days === 8 && c.repairRevision === 3, 'v7.4.1 partial-day state was not upgraded to repair revision 3');

// Malformed snapshot normalization must not leak NaN/invalid orders into UI bindings.
const malformed = deep(c.snapshot());
malformed.day = "oops"; malformed.coins = "NaN"; malformed.energy = "broken"; malformed.maxEnergy = "bad";
malformed.worldSeed = "bad"; malformed.selectedPlot = 9999; malformed.selectedSeed = -500;
malformed.orders = [{item:"not_a_real_item",amount:"x",reward:"y",status:"weird"},{status:"cooldown",cooldownUntil:"bad"},null];
ok(c.applySnapshot(malformed) === true, 'malformed snapshot should be recoverable');
ok(Number.isFinite(c.day) && Number.isFinite(c.coins) && Number.isFinite(c.energy) && Number.isFinite(c.worldSeed), 'malformed numeric state leaked NaN');
ok(c.selectedPlot >= 0 && c.selectedPlot < c.activePlotCount && c.selectedSeed >= 0 && c.selectedSeed < FarmData.crops.length, 'selection normalization failed');
ok(c.orders.length === 3 && c.orders[0] && c.knownOrderItem(c.orders[0].item), 'invalid order item was not regenerated');

// Unknown crop ids and malformed quality/stat values must be repaired rather
// than falling through FarmData.cropById() to the first crop definition.
c.plots[4] = {crop:'definitely_not_a_crop', age:'NaN', watered:true, fertilized:true};
c.qualityInventory.turnip.normal = 'broken'; c.cropHarvests.turnip = 'broken';
c.animalCounts.chicken = 'broken'; c.animalMood.chicken = 'broken';
c.projectLevels.irrigation = 'broken'; c.lifetimeStats.sold = 'broken';
c.normalizeState();
ok(c.plots[4].crop === '' && c.plots[4].age === 0 && !c.plots[4].watered && !c.plots[4].fertilized, 'unknown crop id was not cleared safely');
ok(Number.isFinite(c.qualityInventory.turnip.normal) && Number.isFinite(c.cropHarvests.turnip), 'quality/harvest NaN survived normalization');
ok(Number.isFinite(c.animalCounts.chicken) && Number.isFinite(c.animalMood.chicken), 'animal NaN survived normalization');
ok(Number.isFinite(c.projectLevels.irrigation) && Number.isFinite(c.lifetimeStats.sold), 'project/stat NaN survived normalization');

// A mature crop must be harvested before fertilizer can be applied. This
// prevents wasting fertilizer on a crop whose quality was already determined.
c.inventory.fertilizer = 3; c.plots[5] = {crop:'turnip', age:2, watered:false, fertilized:false};
const fertBefore = c.inventory.fertilizer; c.fertilize(5);
ok(c.inventory.fertilizer === fertBefore && c.plots[5].fertilized === false, 'fertilizer was consumed by a harvest-ready crop');

// Economy transactions must roll back if a later bookkeeping/UI step throws.
c.inventory.turnip = 3; c.qualityInventory.turnip = {normal:3,fine:0,premium:0,perfect:0}; c.coins = 500;
const sellRollbackBefore = deep(c.snapshot()); const realAddStat = c.addStat;
c.addStat = function() { throw new Error('injected sell bookkeeping failure'); };
c.sellItem('turnip'); c.addStat = realAddStat;
ok(JSON.stringify(c.snapshot()) === JSON.stringify(sellRollbackBefore), 'sell transaction rollback lost state');

c.inventory.turnip = 4; c.qualityInventory.turnip = {normal:4,fine:0,premium:0,perfect:0}; c.coins = 500; c.reputation = 10;
c.orders = [{id:101,item:'turnip',amount:2,reward:90,status:'accepted',special:false,expiresDay:0,acceptedDay:c.day,closedDay:0},null,null];
const orderRollbackBefore = deep(c.snapshot()); const realRecordHistory = c.recordOrderHistory;
c.recordOrderHistory = function() { throw new Error('injected order history failure'); };
c.deliverOrder(0); c.recordOrderHistory = realRecordHistory;
ok(JSON.stringify(c.snapshot()) === JSON.stringify(orderRollbackBefore), 'order delivery rollback lost state');

const project = FarmData.projects[0]; c.reputation = 100; c.coins = 100000; c.projectLevels[project.id] = 0;
c.inventory[project.item] = 1000;
if (c.isCropId(project.item)) c.qualityInventory[project.item] = {normal:1000,fine:0,premium:0,perfect:0};
const projectRollbackBefore = deep(c.snapshot());
c.addStat = function() { throw new Error('injected project bookkeeping failure'); };
c.advanceProject(project); c.addStat = realAddStat;
ok(JSON.stringify(c.snapshot()) === JSON.stringify(projectRollbackBefore), 'project transaction rollback lost state');

// Canonical snapshot must round-trip the newly added repair marker and mature crop state.
c.repairRevision = 3; c.plots[0] = {crop:'carrot',age:3,watered:false,fertilized:true}; c.energy = 6;
const roundTrip = JSON.parse(JSON.stringify(c.snapshot()));
c.initializeFreshGame();
ok(c.applySnapshot(roundTrip) === true, 'canonical snapshot round-trip apply failed');
ok(c.repairRevision === 3 && c.plots[0].crop === 'carrot' && c.plots[0].age === 3 && c.energy === 6, 'canonical snapshot round-trip lost state');

// Rich-state randomized action audit using the same QML functions.
c.initializeFreshGame(); c.gameLoaded = true; c.coins = 10000000; c.farmLevel = 20; c.reputation = 100;
c.landStage = 4; c.wateringTier = 5; c.sprinklerLevel = 2; c.greenhouseLevel = 2;
c.coopLevel = 5; c.barnLevel = 5; c.apiaryLevel = 5;
c.processingBuilt = {mill:true,feed_mixer:true,preserver:true,dairy:true,kitchen:true};
for (const crop of FarmData.crops) {
    c.inventory[crop.id + 'Seed'] = 50; c.inventory[crop.id] = 20;
    c.qualityInventory[crop.id] = {normal:20,fine:0,premium:0,perfect:0};
}
for (const animal of FarmData.animals) c.animalCounts[animal.id] = 2;
for (const id of ['feed','fertilizer','egg','duck_egg','milk','goat_milk','wool','honey','flour','cornmeal','berry_jam','tomato_sauce','cheese','goat_cheese','bread']) c.inventory[id] = 100;
c.ensureOrders(); assertCoreInvariants('rich setup');
let seed = 0x5eeda11; function rnd() { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; }
const ri = n => Math.floor(rnd() * n);
const actions = [
    () => { c.selectedSeed = ri(FarmData.crops.length); c.plant(ri(c.activePlotCount)); },
    () => c.water(ri(c.activePlotCount)), () => c.fertilize(ri(c.activePlotCount)),
    () => c.harvest(ri(c.activePlotCount)), () => c.interact(ri(c.activePlotCount)),
    () => c.batchWaterAllDry(), () => c.batchFertilizeSelectedZone(), () => c.batchHarvestAllReady(),
    () => c.buySeed(ri(FarmData.crops.length)), () => c.buyFeed(), () => c.buyFertilizer(),
    () => c.craft(FarmData.recipes[ri(FarmData.recipes.length)]),
    () => c.refreshOrderBoard(), () => c.acceptOrder(ri(3)), () => c.rejectOrder(ri(3)),
    () => c.abandonOrder(ri(3)), () => c.deliverOrder(ri(3)),
    () => { c.energy = c.maxEnergy; c.commitNextDay(); },
    () => c.buyAnimal(FarmData.animals[ri(FarmData.animals.length)].id),
    () => c.upgradeAnimalBuilding(['coop','barn','apiary'][ri(3)]),
    () => c.advanceProject(FarmData.projects[ri(FarmData.projects.length)])
];
for (let step = 0; step < 1500; ++step) {
    actions[ri(actions.length)]();
    assertCoreInvariants(`fuzz ${step}`);
}

console.log(`RUNTIME LOGIC PASS: ${checks}/${checks} checks`);
