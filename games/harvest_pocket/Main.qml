import QtQuick
import "js/FarmData.js" as FarmData

FocusScope {
    id: root
    focus: true

    readonly property int saveSchema: 4
    readonly property int plotCount: 40
    readonly property bool showHints: settingBool("showHints", true)
    readonly property bool reducedMotion: settingBool("reducedMotion", false)
    readonly property string visualQuality: "balanced" // Fixed low-overhead profile; no unverified host setting key.
    readonly property string layoutClass: width < 680 ? "compact" : (width < 1280 ? "medium" : "wide")
    readonly property bool compactLayout: layoutClass === "compact"
    readonly property bool mediumLayout: layoutClass === "medium"
    readonly property bool wideLayout: layoutClass === "wide"
    readonly property int contentMaxWidth: wideLayout ? 1180 : (mediumLayout ? 920 : 640)
    readonly property int columns: width < 560 ? 4 : (width < 900 ? 5 : 8)
    readonly property int rows: Math.ceil(plotCount / columns)
    readonly property int contentPadding: Math.max(10, GameTheme.number("alias.page.padding"))
    readonly property int effectiveSprinklerCoverage: Math.min(activePlotCount, sprinklerCount + Number(projectLevels.irrigation || 0) * 2)
    readonly property int orderRefreshBudget: 3
    readonly property int orderRefreshRemaining: Math.max(0, orderRefreshBudget - (orderRefreshDay === day ? orderRefreshesUsed : 0))
    readonly property int refreshableOrderCount: countRefreshableOrders()
    readonly property int selectedIrrigationZone: Math.max(0, Math.min(4, Math.floor(Math.max(0, selectedPlot) / 8)))
    readonly property bool batchWaterUnlocked: wateringTier >= 3
    readonly property bool batchFertilizeUnlocked: farmLevel >= 8
    readonly property bool batchHarvestUnlocked: farmLevel >= 10
    readonly property int dryFieldCount: countDryGrowingPlots()
    readonly property int readyFieldCount: countReadyPlots()
    readonly property int selectedZoneFertilizableCount: countFertilizableInZone(selectedIrrigationZone)
    readonly property bool inputLocked: nextDayTransitionRunning || pendingTab >= 0 || tabSwitchAnimation.running
    readonly property var selectedPlotState: plotState(selectedPlot)
    readonly property bool selectedPlotReady: isHarvestReady(selectedPlot)

    property int activeTab: 0
    property int day: 1
    property int year: 1
    property real coins: 80
    property int energy: 16
    property int maxEnergy: 16
    property real farmXp: 0
    property int farmLevel: 1
    property int reputation: 0
    property int selectedPlot: 0
    property int selectedSeed: 0
    property int animationPulse: 0
    property int worldSeed: 0
    property string message: ""
    property bool saveDirty: false
    property bool gameLoaded: false
    property int visualActionSerial: 0
    property int visualActionPlot: -1
    property string visualActionKind: ""
    property bool nextDayWarningArmed: false
    property bool nextDayTransitionRunning: false
    property real warningShakeOffset: 0
    property real warningEdgeOpacity: 0
    property int i18nRevision: 0
    // Compatibility flag for v6.4.x players: those saves had the original
    // six crops available without level gates. Preserve that access after
    // migration without auto-unlocking the ten crops introduced in v7.
    property bool legacyCropAccess: false
    property bool showAllCrops: false
    property string ambientAudioKey: ""
    property bool audioPreloaded: false
    property int pendingTab: -1
    property int tabSlideDirection: 1
    property real tabContentOpacity: 1.0
    property real tabContentOffset: 0

    // External RCC content can be constructed before host services are fully
    // injected. Use only API members verified by the supplied v6.4 package and
    // retry initialization until those methods exist.
    property bool initializationDone: false



    property int wateringTier: 1
    property int sprinklerLevel: 0
    property int greenhouseLevel: 0
    property int landStage: 0
    property int coopLevel: 0
    property int barnLevel: 0
    property int apiaryLevel: 0

    property var plots: []
    property var inventory: ({})
    property var qualityInventory: ({})
    property var cropHarvests: ({})
    property var animalCounts: ({})
    property var animalMood: ({})
    property var processingBuilt: ({})
    property var orders: []
    property int orderSerial: 0
    property int orderRefreshDay: 1
    property int orderRefreshesUsed: 0
    property var orderHistory: []
    property int highestOrderReward: 0
    // Incremented when a known historical state-repair pass has been applied.
    // This is intentionally stored inside snapshot_v4 without changing the host save_version.
    property int repairRevision: 0
    property var projectLevels: ({})
    property var lifetimeStats: ({})

    readonly property int seasonIndex: Math.floor(((day - 1) % 28) / 7)
    readonly property int seasonDay: ((day - 1) % 7) + 1
    readonly property string seasonKey: ["season_spring", "season_summer", "season_autumn", "season_winter"][seasonIndex]
    readonly property string weather: weatherForDay(day)
    readonly property int activePlotCount: FarmData.landCounts[Math.max(0, Math.min(FarmData.landCounts.length - 1, landStage))]
    readonly property int sprinklerCount: FarmData.sprinklerCoverage[Math.max(0, Math.min(5, sprinklerLevel))]
    readonly property int greenhouseCount: FarmData.greenhouseCoverage[Math.max(0, Math.min(5, greenhouseLevel))]
    readonly property var selectedCrop: FarmData.crops[Math.max(0, Math.min(FarmData.crops.length - 1, selectedSeed))]
    readonly property var cropChooserIndexes: buildCropChooserIndexes()
    readonly property int xpNeeded: farmLevel * 45
    readonly property real marketVegetable: categoryMarket("vegetable")
    readonly property real marketFruit: categoryMarket("fruit")
    readonly property real marketGrain: categoryMarket("grain")
    readonly property real marketAnimal: categoryMarket("animal")
    readonly property real marketProcessed: categoryMarket("processed")

    function settingBool(key, fallback) {
        try {
            if (typeof GameSettings === "undefined" || typeof GameSettings.value !== "function") return Boolean(fallback)
            return Boolean(GameSettings.value(key, fallback))
        } catch (e) { return Boolean(fallback) }
    }

    function haptic(level) {
        try {
            if (typeof Haptics === "undefined") return
            if (level === "light" && typeof Haptics.light === "function") Haptics.light()
            else if (level === "medium" && typeof Haptics.medium === "function") Haptics.medium()
            else if (level === "heavy" && typeof Haptics.heavy === "function") Haptics.heavy()
        } catch (e) {}
    }

    function audioUrl(name) {
        return Qt.resolvedUrl("assets/audio/" + name + ".wav")
    }

    function playSfx(name, gain) {
        var source = audioUrl(name)
        var level = gain === undefined ? 0.42 : Number(gain)
        try {
            if (typeof GameAudio !== "undefined" && typeof GameAudio.playEffect === "function") {
                GameAudio.playEffect(source, level, "sfx")
                return
            }
        } catch (e) {}
        try {
            if (typeof Audio !== "undefined" && typeof Audio.playUrl === "function") Audio.playUrl(source, level)
        } catch (e2) {}
    }

    function preloadAudio() {
        if (audioPreloaded) return
        // Preload only hot-path SFX. Less frequent economy/order/workshop
        // cues are lazy-loaded by the verified host AudioManager on first use.
        var names = ["plant","water","harvest","sell","craft","tab"]
        try {
            if (typeof GameAudio !== "undefined" && typeof GameAudio.preload === "function") {
                for (var i=0; i<names.length; ++i) GameAudio.preload(audioUrl(names[i]))
                audioPreloaded = true
                return
            }
        } catch (e) {}
        try {
            if (typeof Audio !== "undefined" && typeof Audio.preload === "function") {
                for (var j=0; j<names.length; ++j) Audio.preload(audioUrl(names[j]))
                audioPreloaded = true
            }
        } catch (e2) {}
    }

    function desiredAmbientAudio() {
        if (!root.visible || !gameLoaded || activeTab !== 0 || nextDayTransitionRunning) return ""
        if (weather === "rain") return "rain_loop"
        if (weather === "wind") return "wind_loop"
        if (weather === "storm") return "storm_loop"
        return ""
    }

    function stopAmbientAudio() {
        if (ambientAudioKey.length === 0) return
        try {
            if (typeof GameAudio !== "undefined" && typeof GameAudio.stopMusic === "function") GameAudio.stopMusic()
        } catch (e) {}
        ambientAudioKey = ""
    }

    function syncAmbientAudio() {
        var desired = desiredAmbientAudio()
        if (desired === ambientAudioKey) return
        stopAmbientAudio()
        if (desired.length === 0) return
        try {
            if (typeof GameAudio !== "undefined" && typeof GameAudio.playMusic === "function") {
                GameAudio.playMusic(audioUrl(desired), true, "ambient")
                ambientAudioKey = desired
            }
        } catch (e) { ambientAudioKey = "" }
    }

    function switchTab(index) {
        index = Math.max(0, Math.min(4, Math.floor(Number(index))))
        if (index === activeTab || pendingTab >= 0 || tabSwitchAnimation.running) return
        root.playSfx("tab", 0.16)
        if (root.reducedMotion) {
            activeTab = index
            tabContentOpacity = 1.0
            tabContentOffset = 0
            if (typeof scroll !== "undefined") scroll.contentY = 0
            return
        }
        pendingTab = index
        tabSlideDirection = index > activeTab ? 1 : -1
        tabSwitchAnimation.restart()
    }

    function showReward(text, iconSource, colorToken) {
        if (!text || String(text).length === 0) return
        try { rewardLayer.show(String(text), iconSource, colorToken || "color.accent") } catch (e) {}
    }

    function tr(key) {
        // Explicit dependency so runtime language changes invalidate bindings.
        var _languageRevision = i18nRevision
        try {
            if (typeof GameI18n === "undefined" || typeof GameI18n.text !== "function") return key
            var value = GameI18n.text(key, key)
            return value === undefined || value === null || String(value).length === 0 ? key : String(value)
        } catch (e) { return key }
    }

    function saveServiceReady() {
        try {
            return typeof GameSave !== "undefined" &&
                   typeof GameSave.load === "function" && typeof GameSave.get === "function" &&
                   typeof GameSave.set === "function" && typeof GameSave.save === "function"
        } catch (e) { return false }
    }

    function fmt(n) {
        n = Number(n || 0)
        if (Math.abs(n) < 1000) return String(Math.floor(n))
        var suffix = ["K", "M", "B", "T", "Qa", "Qi"]
        var value = Math.abs(n)
        var idx = -1
        while (value >= 1000 && idx < suffix.length - 1) {
            value /= 1000
            idx++
        }
        var sign = n < 0 ? "-" : ""
        if (idx >= 0 && !(idx === suffix.length - 1 && value >= 1000))
            return sign + (value >= 100 ? value.toFixed(0) : (value >= 10 ? value.toFixed(1) : value.toFixed(2))) + suffix[idx]
        return Number(n).toExponential(2)
    }

    function clone(value) {
        try { return JSON.parse(JSON.stringify(value)) } catch (e) { return value }
    }

    function finiteNumber(value, fallback) {
        var n = Number(value)
        return isFinite(n) ? n : Number(fallback || 0)
    }

    function knownOrderItem(id) {
        if (!id) return false
        for (var i=0; i<FarmData.crops.length; ++i) if (FarmData.crops[i].id === id) return true
        for (var a=0; a<FarmData.animals.length; ++a) if (FarmData.animals[a].product === id) return true
        for (var r=0; r<FarmData.recipes.length; ++r) if (FarmData.recipes[r].output === id) return true
        return false
    }

    function defaultInventory() {
        var result = {feed:4, fertilizer:2}
        for (var i=0; i<FarmData.crops.length; ++i) {
            var c = FarmData.crops[i]
            result[c.id] = 0
            result[c.id + "Seed"] = (c.id === "turnip" ? 8 : (c.id === "carrot" ? 4 : 0))
        }
        var productIds = ["egg","duck_egg","milk","goat_milk","wool","honey","flour","cornmeal","berry_jam","tomato_sauce","cheese","goat_cheese","bread"]
        for (var p=0; p<productIds.length; ++p) result[productIds[p]] = 0
        return result
    }

    function defaultQualityInventory() {
        var result = {}
        for (var i=0; i<FarmData.crops.length; ++i)
            result[FarmData.crops[i].id] = {normal:0, fine:0, premium:0, perfect:0}
        return result
    }

    function defaultCropHarvests() {
        var result = {}
        for (var i=0; i<FarmData.crops.length; ++i) result[FarmData.crops[i].id] = 0
        return result
    }

    function defaultAnimalCounts() {
        return {chicken:0, duck:0, cow:0, goat:0, sheep:0, bee:0}
    }

    function defaultAnimalMood() {
        return {chicken:55, duck:55, cow:55, goat:55, sheep:55, bee:65}
    }

    function defaultProcessingBuilt() {
        return {mill:false, feed_mixer:false, preserver:false, dairy:false, kitchen:false}
    }

    function defaultProjectLevels() {
        var result = {}
        for (var i=0; i<FarmData.projects.length; ++i) result[FarmData.projects[i].id] = 0
        return result
    }

    function defaultLifetimeStats() {
        return {planted:0, watered:0, harvested:0, sold:0, orders:0, ordersRejected:0, ordersAbandoned:0, ordersExpired:0, crafted:0, days:0, projects:0}
    }

    function freshPlots() {
        var result = []
        for (var i=0; i<plotCount; ++i)
            result.push({crop:"", age:0, watered:false, fertilized:false})
        return result
    }

    function normalizeState() {
        var p = clone(plots || [])
        while (p.length < plotCount) p.push({crop:"", age:0, watered:false, fertilized:false})
        if (p.length > plotCount) p = p.slice(0, plotCount)
        for (var i=0; i<p.length; ++i) {
            var item = p[i] || {}
            var cropId = String(item.crop || "")
            if (cropId !== "" && !isCropId(cropId)) cropId = ""
            p[i] = {
                crop: cropId,
                age: cropId === "" ? 0 : Math.max(0, finiteNumber(item.age, 0)),
                watered: cropId === "" ? false : Boolean(item.watered),
                fertilized: cropId === "" ? false : Boolean(item.fertilized)
            }
        }
        plots = p

        day = Math.max(1, Math.floor(finiteNumber(day, 1)))
        year = Math.max(1, Math.floor(finiteNumber(year, Math.floor((day - 1) / 28) + 1)))
        coins = Math.max(0, finiteNumber(coins, 0))
        maxEnergy = Math.max(8, finiteNumber(maxEnergy, 16))
        energy = FarmData.clamp(finiteNumber(energy, maxEnergy), 0, maxEnergy)
        farmXp = Math.max(0, finiteNumber(farmXp, 0))
        farmLevel = Math.max(1, Math.floor(finiteNumber(farmLevel, 1)))
        reputation = Math.max(0, Math.floor(finiteNumber(reputation, 0)))
        worldSeed = Math.max(1, Math.floor(finiteNumber(worldSeed, Date.now() % 2147483646)))
        orderSerial = Math.max(0, Math.floor(finiteNumber(orderSerial, 0)))

        var inv = defaultInventory()
        var sourceInv = inventory || {}
        for (var k in sourceInv) inv[k] = Math.max(0, finiteNumber(sourceInv[k], 0))
        inventory = inv

        var q = defaultQualityInventory()
        var sq = qualityInventory || {}
        for (var c in sq) {
            if (q[c]) {
                q[c].normal = Math.max(0, finiteNumber(sq[c].normal, 0))
                q[c].fine = Math.max(0, finiteNumber(sq[c].fine, 0))
                q[c].premium = Math.max(0, finiteNumber(sq[c].premium, 0))
                q[c].perfect = Math.max(0, finiteNumber(sq[c].perfect, 0))
            }
        }
        // Keep crop quality buckets exactly aligned with total crop stock.
        // This also repairs partially-written/corrupt v2 snapshots without
        // allowing "ghost" Perfect produce to survive consumption.
        for (var qc=0; qc<FarmData.crops.length; ++qc) {
            var qid = FarmData.crops[qc].id
            var totalStock = Math.max(0, Math.floor(finiteNumber(inv[qid], 0)))
            var bucketTotal = Math.max(0, Math.floor(finiteNumber(q[qid].normal, 0))) + Math.max(0, Math.floor(finiteNumber(q[qid].fine, 0))) + Math.max(0, Math.floor(finiteNumber(q[qid].premium, 0))) + Math.max(0, Math.floor(finiteNumber(q[qid].perfect, 0)))
            if (bucketTotal < totalStock) q[qid].normal += totalStock - bucketTotal
            else if (bucketTotal > totalStock) {
                var overflow = bucketTotal - totalStock
                var trimOrder = ["normal","fine","premium","perfect"]
                for (var tq=0; tq<trimOrder.length && overflow>0; ++tq) {
                    var tv = Math.max(0, Math.floor(finiteNumber(q[qid][trimOrder[tq]], 0)))
                    var cut = Math.min(tv, overflow)
                    q[qid][trimOrder[tq]] = tv - cut
                    overflow -= cut
                }
            }
        }
        qualityInventory = q

        var ch = defaultCropHarvests()
        var sch = cropHarvests || {}
        for (var h in sch) if (ch[h] !== undefined) ch[h] = Math.max(0, finiteNumber(sch[h], 0))
        cropHarvests = ch

        var ac = defaultAnimalCounts()
        var sac = animalCounts || {}
        for (var a in sac) if (ac[a] !== undefined) ac[a] = Math.max(0, Math.floor(finiteNumber(sac[a], 0)))
        animalCounts = ac

        var am = defaultAnimalMood()
        var sam = animalMood || {}
        for (var m in sam) if (am[m] !== undefined) am[m] = FarmData.clamp(finiteNumber(sam[m], 50), 0, 100)
        animalMood = am

        var pb = defaultProcessingBuilt()
        var spb = processingBuilt || {}
        for (var b in spb) if (pb[b] !== undefined) pb[b] = Boolean(spb[b])
        processingBuilt = pb

        var pj = defaultProjectLevels()
        var spj = projectLevels || {}
        for (var j in spj) if (pj[j] !== undefined) pj[j] = FarmData.clamp(Math.floor(finiteNumber(spj[j], 0)), 0, 5)
        projectLevels = pj

        var ls = defaultLifetimeStats()
        var sls = lifetimeStats || {}
        for (var s in sls) if (ls[s] !== undefined) ls[s] = Math.max(0, finiteNumber(sls[s], 0))
        lifetimeStats = ls
        orderRefreshDay = Math.max(1, Math.floor(finiteNumber(orderRefreshDay, day)))
        orderRefreshesUsed = FarmData.clamp(Math.floor(finiteNumber(orderRefreshesUsed, 0)), 0, orderRefreshBudget)
        var normalizedHistory = []
        var sourceHistory = orderHistory || []
        var validHistoryOutcomes = {completed:true, rejected:true, abandoned:true, expired:true}
        for (var oh=0; oh<sourceHistory.length && oh<40; ++oh) {
            var he = sourceHistory[oh] || {}
            var historyItem = String(he.item || "")
            var historyOutcome = String(he.outcome || "")
            if (!knownOrderItem(historyItem) || !validHistoryOutcomes[historyOutcome]) continue
            normalizedHistory.push({
                item:historyItem, amount:Math.max(1, Math.floor(finiteNumber(he.amount, 1))),
                reward:Math.max(0, Math.floor(finiteNumber(he.reward, 0))), outcome:historyOutcome,
                day:Math.max(1, Math.floor(finiteNumber(he.day, day))), special:Boolean(he.special)
            })
        }
        orderHistory = normalizedHistory
        highestOrderReward = Math.max(0, Math.floor(finiteNumber(highestOrderReward, 0)))
        for (var hr=0; hr<orderHistory.length; ++hr) if (orderHistory[hr].outcome === "completed") highestOrderReward = Math.max(highestOrderReward, finiteNumber(orderHistory[hr].reward, 0))

        var normalizedOrders = []
        var sourceOrders = Array.isArray(orders) ? orders : []
        var validStatuses = {available:true, accepted:true, completed:true, rejected:true, abandoned:true, expired:true, cooldown:true}
        for (var oi=0; oi<3; ++oi) {
            var sourceOrder = sourceOrders[oi]
            if (!sourceOrder || typeof sourceOrder !== "object") { normalizedOrders.push(null); continue }
            var status = validStatuses[String(sourceOrder.status || "")] ? String(sourceOrder.status) : "available"
            if (status === "cooldown") {
                normalizedOrders.push({status:"cooldown", cooldownUntil:Math.max(day, Math.floor(finiteNumber(sourceOrder.cooldownUntil, day + 1)))})
                continue
            }
            var itemId = String(sourceOrder.item || "")
            if (!knownOrderItem(itemId)) { normalizedOrders.push(null); continue }
            normalizedOrders.push({
                id:Math.max(0, Math.floor(finiteNumber(sourceOrder.id, oi + 1))),
                item:itemId, amount:Math.max(1, Math.floor(finiteNumber(sourceOrder.amount, 1))),
                reward:Math.max(1, Math.floor(finiteNumber(sourceOrder.reward, 1))),
                status:status, special:Boolean(sourceOrder.special),
                expiresDay:Math.max(0, Math.floor(finiteNumber(sourceOrder.expiresDay, 0))),
                acceptedDay:Math.max(0, Math.floor(finiteNumber(sourceOrder.acceptedDay, 0))),
                closedDay:Math.max(0, Math.floor(finiteNumber(sourceOrder.closedDay, 0)))
            })
        }
        orders = normalizedOrders
        ensureOrders()
        wateringTier = FarmData.clamp(Math.floor(finiteNumber(wateringTier, 1)), 1, 5)
        sprinklerLevel = FarmData.clamp(Math.floor(finiteNumber(sprinklerLevel, 0)), 0, 5)
        greenhouseLevel = FarmData.clamp(Math.floor(finiteNumber(greenhouseLevel, 0)), 0, 5)
        landStage = FarmData.clamp(Math.floor(finiteNumber(landStage, 0)), 0, 4)
        coopLevel = FarmData.clamp(Math.floor(finiteNumber(coopLevel, 0)), 0, 5)
        barnLevel = FarmData.clamp(Math.floor(finiteNumber(barnLevel, 0)), 0, 5)
        apiaryLevel = FarmData.clamp(Math.floor(finiteNumber(apiaryLevel, 0)), 0, 5)
        selectedPlot = FarmData.clamp(Math.floor(finiteNumber(selectedPlot, 0)), 0, Math.max(0, activePlotCount - 1))
        selectedSeed = FarmData.clamp(Math.floor(finiteNumber(selectedSeed, 0)), 0, FarmData.crops.length - 1)
    }

    function initializeFreshGame() {
        day = 1
        year = 1
        coins = 80
        energy = 16
        maxEnergy = 16
        farmXp = 0
        farmLevel = 1
        reputation = 0
        selectedPlot = 0
        selectedSeed = 0
        legacyCropAccess = false
        wateringTier = 1
        sprinklerLevel = 0
        greenhouseLevel = 0
        landStage = 0
        coopLevel = 0
        barnLevel = 0
        apiaryLevel = 0
        plots = freshPlots()
        inventory = defaultInventory()
        qualityInventory = defaultQualityInventory()
        cropHarvests = defaultCropHarvests()
        animalCounts = defaultAnimalCounts()
        animalMood = defaultAnimalMood()
        processingBuilt = defaultProcessingBuilt()
        projectLevels = defaultProjectLevels()
        lifetimeStats = defaultLifetimeStats()
        orderSerial = 0
        orderRefreshDay = day
        orderRefreshesUsed = 0
        orderHistory = []
        highestOrderReward = 0
        repairRevision = 3
        worldSeed = Math.max(1, Math.floor(Date.now() % 2147483646))
        orders = []
        ensureOrders()
    }

    function snapshot() {
        return {
            schema: saveSchema,
            day: day, year: year, coins: coins, energy: energy, maxEnergy: maxEnergy,
            farmXp: farmXp, farmLevel: farmLevel, reputation: reputation,
            selectedPlot: selectedPlot, selectedSeed: selectedSeed, worldSeed: worldSeed, legacyCropAccess: legacyCropAccess,
            wateringTier: wateringTier, sprinklerLevel: sprinklerLevel, greenhouseLevel: greenhouseLevel,
            landStage: landStage, coopLevel: coopLevel, barnLevel: barnLevel, apiaryLevel: apiaryLevel,
            plots: plots, inventory: inventory, qualityInventory: qualityInventory, cropHarvests: cropHarvests,
            animalCounts: animalCounts, animalMood: animalMood, processingBuilt: processingBuilt,
            orders: orders, orderSerial: orderSerial, orderRefreshDay: orderRefreshDay, orderRefreshesUsed: orderRefreshesUsed,
            orderHistory: orderHistory, highestOrderReward: highestOrderReward, repairRevision: repairRevision,
            projectLevels: projectLevels, lifetimeStats: lifetimeStats
        }
    }

    function compatibilitySnapshotV3() {
        var compat = clone(snapshot())
        compat.schema = 3
        compat.orderRejectDay = orderRefreshDay
        compat.orderRejectsUsed = orderRefreshesUsed
        delete compat.orderRefreshDay
        delete compat.orderRefreshesUsed
        delete compat.orderHistory
        delete compat.highestOrderReward
        delete compat.repairRevision
        var compatOrders = clone(compat.orders || [])
        for (var i=0; i<compatOrders.length; ++i) {
            var o = compatOrders[i]
            if (!o) continue
            if (o.status === "rejected" || o.status === "abandoned" || o.status === "completed" || o.status === "expired")
                compatOrders[i] = {status:"cooldown", cooldownUntil:day + 1}
        }
        compat.orders = compatOrders
        return compat
    }

    function applySnapshot(s) {
        if (!s) return false
        day = Math.max(1, Math.floor(finiteNumber(s.day, 1)))
        year = Math.max(1, Math.floor(finiteNumber(s.year, Math.floor((day - 1) / 28) + 1)))
        coins = Math.max(0, finiteNumber(s.coins, 0))
        maxEnergy = Math.max(8, finiteNumber(s.maxEnergy, 16))
        energy = FarmData.clamp(finiteNumber(s.energy === undefined ? maxEnergy : s.energy, maxEnergy), 0, maxEnergy)
        farmXp = Math.max(0, finiteNumber(s.farmXp, 0))
        farmLevel = Math.max(1, Math.floor(finiteNumber(s.farmLevel, 1)))
        reputation = Math.max(0, Math.floor(finiteNumber(s.reputation, 0)))
        selectedPlot = finiteNumber(s.selectedPlot, 0)
        selectedSeed = finiteNumber(s.selectedSeed, 0)
        worldSeed = Math.max(1, Math.floor(finiteNumber(s.worldSeed, Date.now() % 2147483646)))
        legacyCropAccess = Boolean(s.legacyCropAccess)
        wateringTier = finiteNumber(s.wateringTier, 1)
        sprinklerLevel = finiteNumber(s.sprinklerLevel, 0)
        greenhouseLevel = finiteNumber(s.greenhouseLevel, 0)
        landStage = finiteNumber(s.landStage, 0)
        coopLevel = finiteNumber(s.coopLevel, 0)
        barnLevel = finiteNumber(s.barnLevel, 0)
        apiaryLevel = finiteNumber(s.apiaryLevel, 0)
        plots = clone(s.plots || freshPlots())
        inventory = clone(s.inventory || defaultInventory())
        qualityInventory = clone(s.qualityInventory || defaultQualityInventory())
        cropHarvests = clone(s.cropHarvests || defaultCropHarvests())
        animalCounts = clone(s.animalCounts || defaultAnimalCounts())
        animalMood = clone(s.animalMood || defaultAnimalMood())
        processingBuilt = clone(s.processingBuilt || defaultProcessingBuilt())
        orders = clone(s.orders || [])
        orderSerial = Math.max(0, Math.floor(finiteNumber(s.orderSerial, 0)))
        orderRefreshDay = Math.max(1, Math.floor(finiteNumber(s.orderRefreshDay === undefined ? (s.orderRejectDay === undefined ? day : s.orderRejectDay) : s.orderRefreshDay, day)))
        orderRefreshesUsed = Math.max(0, Math.floor(finiteNumber(s.orderRefreshesUsed === undefined ? (s.orderRejectsUsed === undefined ? 0 : s.orderRejectsUsed) : s.orderRefreshesUsed, 0)))
        orderHistory = clone(s.orderHistory || [])
        highestOrderReward = Math.max(0, Math.floor(finiteNumber(s.highestOrderReward, 0)))
        repairRevision = Math.max(0, Math.floor(finiteNumber(s.repairRevision, 0)))
        projectLevels = clone(s.projectLevels || defaultProjectLevels())
        lifetimeStats = clone(s.lifetimeStats || defaultLifetimeStats())
        normalizeState()
        return true
    }

    function restoreRuntimeSnapshot(s) {
        // `s` comes from snapshot() immediately before a transaction, so it is
        // already normalized runtime state. Do not call normalizeState() or
        // ensureOrders() here: rollback must restore the exact pre-transaction
        // graph, including empty order slots and refresh counters.
        if (!s) return false
        day = s.day; year = s.year; coins = s.coins; energy = s.energy; maxEnergy = s.maxEnergy
        farmXp = s.farmXp; farmLevel = s.farmLevel; reputation = s.reputation
        selectedPlot = s.selectedPlot; selectedSeed = s.selectedSeed; worldSeed = s.worldSeed
        legacyCropAccess = Boolean(s.legacyCropAccess)
        wateringTier = s.wateringTier; sprinklerLevel = s.sprinklerLevel; greenhouseLevel = s.greenhouseLevel
        landStage = s.landStage; coopLevel = s.coopLevel; barnLevel = s.barnLevel; apiaryLevel = s.apiaryLevel
        plots = clone(s.plots); inventory = clone(s.inventory); qualityInventory = clone(s.qualityInventory)
        cropHarvests = clone(s.cropHarvests); animalCounts = clone(s.animalCounts); animalMood = clone(s.animalMood)
        processingBuilt = clone(s.processingBuilt); orders = clone(s.orders); orderSerial = s.orderSerial
        orderRefreshDay = s.orderRefreshDay; orderRefreshesUsed = s.orderRefreshesUsed
        orderHistory = clone(s.orderHistory); highestOrderReward = s.highestOrderReward; repairRevision = s.repairRevision
        projectLevels = clone(s.projectLevels); lifetimeStats = clone(s.lifetimeStats)
        return true
    }

    function migrateLegacyV1() {
        day = Math.max(1, Number(GameSave.get("day", 1)))
        year = Math.floor((day - 1) / 28) + 1
        coins = Math.max(0, Number(GameSave.get("coins", 80)))
        energy = Math.max(0, Number(GameSave.get("energy", 16)))
        maxEnergy = Math.max(8, Number(GameSave.get("maxEnergy", 16)))
        farmXp = Math.max(0, Number(GameSave.get("farmXp", 0)))
        farmLevel = Math.max(1, Number(GameSave.get("farmLevel", 1)))
        reputation = Math.max(0, Number(GameSave.get("reputation", 0)))
        plots = clone(GameSave.get("plots", freshPlots()))
        inventory = clone(GameSave.get("inventory", defaultInventory()))
        wateringTier = FarmData.clamp(Number(GameSave.get("wateringCanLevel", 1)), 1, 5)
        sprinklerLevel = FarmData.clamp(Number(GameSave.get("sprinklerLevel", 0)), 0, 5)
        greenhouseLevel = FarmData.clamp(Number(GameSave.get("greenhouseLevel", 0)), 0, 5)
        coopLevel = FarmData.clamp(Number(GameSave.get("coopLevel", 0)), 0, 5)
        barnLevel = FarmData.clamp(Number(GameSave.get("barnLevel", 0)), 0, 5)
        apiaryLevel = 0
        landStage = 4
        legacyCropAccess = true
        qualityInventory = defaultQualityInventory()
        // Legacy v1 had no quality split; classify existing crop stock as Normal.
        for (var qi=0; qi<FarmData.crops.length; ++qi) {
            var legacyCropId = FarmData.crops[qi].id
            qualityInventory[legacyCropId].normal = Math.max(0, Number(inventory[legacyCropId] || 0))
        }
        cropHarvests = defaultCropHarvests()
        animalCounts = defaultAnimalCounts()
        animalCounts.chicken = Math.max(0, Number(GameSave.get("chickens", 0)))
        animalCounts.cow = Math.max(0, Number(GameSave.get("cows", 0)))
        animalMood = defaultAnimalMood()
        var oldMood = FarmData.clamp(Number(GameSave.get("animalHappiness", 50)), 0, 100)
        animalMood.chicken = oldMood
        animalMood.cow = oldMood
        processingBuilt = defaultProcessingBuilt()
        projectLevels = defaultProjectLevels()
        lifetimeStats = defaultLifetimeStats()
        worldSeed = Math.max(1, Math.floor(Date.now() % 2147483646))
        orderSerial = 0
        orderRefreshDay = day
        orderRefreshesUsed = 0
        orderHistory = []
        highestOrderReward = 0
        repairRevision = 3
        orders = []
        // Preserve the v1 Town Order when possible instead of silently discarding player progress.
        var legacyOrder = clone(GameSave.get("order", null))
        if (legacyOrder && legacyOrder.item && Number(legacyOrder.amount || 0) > 0) {
            orders = [{item:String(legacyOrder.item), amount:Math.max(1, Math.floor(Number(legacyOrder.amount))),
                       reward:Math.max(1, Math.floor(Number(legacyOrder.reward || 1))), status:"accepted"}, null, null]
            orderSerial = 1
        }
        normalizeState()
        ensureOrders()
        message = tr("msg_save_migrated")
        return true
    }

    function repairKnownState() {
        var changed = false

        // v7.4.0 could throw after advanceCrops()/animalMorning()/day++ but
        // before energy reset and lifetimeStats.days increment. Lifecycle save
        // could then persist a half-committed day. The days counter is the
        // reliable signature: after N completed transitions it must be at least
        // day-1. Repair that historical state once, regardless of whether the
        // leftover energy happened to be zero or merely too low to be obvious.
        if (repairRevision < 3) {
            var trackedDays = Math.max(0, Math.floor(finiteNumber(lifetimeStats.days, 0)))
            if (day > 1 && trackedDays < day - 1) {
                var repairedStats = clone(lifetimeStats || defaultLifetimeStats())
                repairedStats.days = day - 1
                lifetimeStats = repairedStats
                energy = maxEnergy
                message = tr("msg_partial_day_recovered")
                changed = true
            }
        }

        // v7.4.2 also normalizes any impossible selected plot/seed values and
        // guarantees finite energy after malformed/legacy QVariant conversion.
        if (!isFinite(Number(energy))) { energy = maxEnergy; changed = true }
        energy = FarmData.clamp(finiteNumber(energy, maxEnergy), 0, maxEnergy)
        selectedPlot = FarmData.clamp(Math.floor(finiteNumber(selectedPlot, 0)), 0, Math.max(0, activePlotCount - 1))
        selectedSeed = FarmData.clamp(Math.floor(finiteNumber(selectedSeed, 0)), 0, FarmData.crops.length - 1)

        if (repairRevision < 3) { repairRevision = 3; changed = true }
        return changed
    }

    function ensureInitialized() {
        if (initializationDone) return true
        try {
            if (!saveServiceReady()) return false
            if (typeof GameI18n === "undefined" || typeof GameI18n.text !== "function") return false
        } catch (e0) { return false }
        // Keep the host-level save contract at v1 for v6.4 compatibility.
        // Harvest performs its structural migration internally. v7.1 writes a
        // canonical snapshot_v4 while keeping normalized snapshot_v3/v2 mirrors
        // for downgrade-safe compatibility with older v7 builds.
        initializationDone = true
        loadGame()
        forceActiveFocus()
        return true
    }

    function loadGame() {
        var loaded = false
        var migrated = false
        try { loaded = Boolean(GameSave.load("autosave")) } catch (e) { loaded = false }
        if (!loaded) {
            initializeFreshGame()
        } else {
            var textV4 = String(GameSave.get("snapshot_v4", "") || "")
            var textV3 = String(GameSave.get("snapshot_v3", "") || "")
            var textV2 = String(GameSave.get("snapshot_v2", "") || "")
            var applied = false
            if (textV4.length > 2) {
                try { applied = applySnapshot(JSON.parse(textV4)) } catch (e2) { applied = false }
            }
            if (!applied && textV3.length > 2) {
                try { applied = applySnapshot(JSON.parse(textV3)); migrated = applied } catch (e3) { applied = false }
            }
            if (!applied && textV2.length > 2) {
                try { applied = applySnapshot(JSON.parse(textV2)); migrated = applied } catch (e4) { applied = false }
            }
            if (!applied) { migrateLegacyV1(); migrated = true }
        }
        normalizeState()
        ensureOrders()
        var repaired = repairKnownState()
        gameLoaded = true
        saveDirty = false
        refreshYear()
        ensureSeasonSelection()
        if (migrated || repaired) writeSave(true)
    }

    function writeSave(forced) {
        if (!gameLoaded && !forced) return
        try {
            GameSave.set("save_schema", saveSchema)
            var canonicalSnapshot = JSON.stringify(snapshot())
            var compatibilitySnapshot = JSON.stringify(compatibilitySnapshotV3())
            GameSave.set("snapshot_v4", canonicalSnapshot)
            GameSave.set("snapshot_v3", compatibilitySnapshot)
            GameSave.set("snapshot_v2", compatibilitySnapshot)
            GameSave.set("day", day)
            GameSave.set("coins", coins)
            GameSave.set("farmLevel", farmLevel)
            GameSave.set("reputation", reputation)
            GameSave.save("autosave")
            saveDirty = false
        } catch (e) {
            message = tr("msg_save_failed")
        }
    }

    function markDirty(critical) {
        nextDayWarningArmed = false
        saveDirty = true
        if (critical) {
            saveDebounce.stop()
            writeSave(true)
        } else {
            saveDebounce.restart()
        }
    }

    function refreshYear() {
        year = Math.floor((day - 1) / 28) + 1
    }

    function plotState(i) {
        return (plots && plots[i]) ? plots[i] : {crop:"", age:0, watered:false, fertilized:false}
    }

    function cropDef(id) {
        return FarmData.cropById(id)
    }

    function seedKey(id) {
        return id + "Seed"
    }

    function cropUnlocked(crop) {
        if (farmLevel >= crop.level) return true
        if (!legacyCropAccess || !crop) return false
        // v6.4.x exposed exactly these six crops from the start.
        return crop.id === "turnip" || crop.id === "carrot" || crop.id === "berry" ||
               crop.id === "corn" || crop.id === "pumpkin" || crop.id === "crystal"
    }

    function seasonAllowed(crop, plotIndex) {
        if (crop.seasons.indexOf(seasonIndex) >= 0) return true
        return greenhouseLevel > 0 && plotIndex >= 0 && plotIndex < greenhouseCount
    }

    function cropSeasonText(crop) {
        if (!crop || !crop.seasons) return ""
        var keys = ["season_spring", "season_summer", "season_autumn", "season_winter"]
        var names = []
        for (var i=0; i<crop.seasons.length; ++i) names.push(tr(keys[crop.seasons[i]]))
        return names.join(" / ")
    }

    function cropNaturallyInSeason(crop) {
        return !!crop && crop.seasons.indexOf(seasonIndex) >= 0
    }

    function cropPlantStatusKey(crop) {
        if (!cropUnlocked(crop)) return "plant_status_locked"
        if (cropNaturallyInSeason(crop)) return "plant_status_available"
        if (greenhouseCount > 0) return "plant_status_greenhouse"
        return "plant_status_out_of_season"
    }

    function buildCropChooserIndexes() {
        var currentUnlocked = []
        var currentLocked = []
        var otherUnlocked = []
        var otherLocked = []
        for (var i=0; i<FarmData.crops.length; ++i) {
            var crop = FarmData.crops[i]
            var current = crop.seasons.indexOf(seasonIndex) >= 0
            var unlocked = cropUnlocked(crop)
            if (current && unlocked) currentUnlocked.push(i)
            else if (current) currentLocked.push(i)
            else if (unlocked) otherUnlocked.push(i)
            else otherLocked.push(i)
        }
        if (!showAllCrops) return currentUnlocked.concat(currentLocked)
        return currentUnlocked.concat(currentLocked, otherUnlocked, otherLocked)
    }

    function ensureSeasonSelection() {
        if (showAllCrops || (cropUnlocked(selectedCrop) && cropNaturallyInSeason(selectedCrop))) return
        var candidates = buildCropChooserIndexes()
        for (var i=0; i<candidates.length; ++i) {
            var idx = Number(candidates[i])
            if (cropUnlocked(FarmData.crops[idx])) {
                selectedSeed = idx
                return
            }
        }
    }

    function stageFor(plot) {
        if (!plot || plot.crop === "") return 0
        var d = cropDef(plot.crop)
        if (plot.age >= d.days) return 5
        return Math.max(1, Math.min(4, 1 + Math.floor((plot.age / Math.max(1, d.days)) * 4)))
    }

    function cropSource(plot) {
        if (!plot || plot.crop === "") return ""
        return Qt.resolvedUrl("assets/crops/stages/" + plot.crop + "_" + stageFor(plot) + ".svg")
    }

    function waterSourceForPlot(index, plot) {
        if (!plot || plot.crop === "") return ""
        if (plot.watered) return "manual"
        if (index >= 0 && index < effectiveSprinklerCoverage) return "sprinkler"
        if (weather === "storm") return "storm"
        if (weather === "rain") return "rain"
        return ""
    }

    function effectiveWatered(index, plot) {
        return waterSourceForPlot(index, plot).length > 0
    }

    // v7.3 Smart Fields keeps canonical persistent plot data minimal and
    // derives presentation/automation state from it. None of these values are
    // serialized, so old schema-v3 saves remain byte-compatible.
    function fieldStateFor(index, plot) {
        if (!plot || plot.crop === "") return "empty"
        var d = cropDef(plot.crop)
        if (Number(plot.age || 0) >= Number(d.days || 1)) return "ready"
        if (!effectiveWatered(index, plot)) {
            if (Number(plot.age || 0) <= 0) return "planted"
            return "dry"
        }
        if (plot.fertilized) return "fertilized"
        return "watered"
    }

    function fieldStateKey(state) {
        return "field_state_" + String(state || "empty")
    }

    function irrigationZoneForPlot(index) {
        return Math.max(0, Math.min(4, Math.floor(Math.max(0, Number(index || 0)) / 8)))
    }

    function irrigationZoneLetter(zone) {
        return ["A", "B", "C", "D", "E"][Math.max(0, Math.min(4, Number(zone || 0)))]
    }

    function irrigationZoneCoverage(zone) {
        var start = Math.max(0, Math.min(4, Number(zone || 0))) * 8
        return Math.max(0, Math.min(8, effectiveSprinklerCoverage - start))
    }

    function countDryGrowingPlots() {
        var count = 0
        for (var i=0; i<activePlotCount; ++i) {
            var p = plotState(i)
            if (!p || p.crop === "") continue
            var d = cropDef(p.crop)
            if (Number(p.age || 0) >= Number(d.days || 1)) continue
            if (!effectiveWatered(i, p)) count++
        }
        return count
    }

    function countReadyPlots() {
        var count = 0
        for (var i=0; i<activePlotCount; ++i) {
            var p = plotState(i)
            if (p && p.crop !== "" && Number(p.age || 0) >= Number(cropDef(p.crop).days || 1)) count++
        }
        return count
    }

    function countFertilizableInZone(zone) {
        var start = Math.max(0, Math.min(4, Number(zone || 0))) * 8
        var end = Math.min(activePlotCount, start + 8)
        var count = 0
        for (var i=start; i<end; ++i) {
            var p = plotState(i)
            if (p && p.crop !== "" && !p.fertilized && !isHarvestReady(i)) count++
        }
        return count
    }

    function soilSource(plot, index) {
        // Effective irrigation is visual state, not only persisted manual water.
        if (effectiveWatered(index, plot)) return Qt.resolvedUrl("assets/field/soil_wet.svg")
        if (plot && plot.fertilized) return Qt.resolvedUrl("assets/field/soil_fertile.svg")
        if (seasonIndex === 3) return Qt.resolvedUrl("assets/field/soil_winter.svg")
        return Qt.resolvedUrl("assets/field/soil_dry.svg")
    }

    function weatherForDay(targetDay) {
        var s = Math.floor(((targetDay - 1) % 28) / 7)
        var r = FarmData.hash01(worldSeed, targetDay, 17)
        if (s === 3 && r < 0.13) return "frost"
        if (s === 1 && r < 0.10) return "heatwave"
        if (r < 0.08) return "storm"
        if (r < 0.25) return "rain"
        if (r < 0.38) return "wind"
        if (r < 0.55) return "cloudy"
        return "sunny"
    }

    function categoryMarketForDay(category, dayNumber) {
        var salt = category === "vegetable" ? 31 : (category === "fruit" ? 37 : (category === "grain" ? 43 : (category === "animal" ? 47 : 53)))
        var r = FarmData.hash01(worldSeed, Math.max(1, Math.floor(Number(dayNumber || day))), salt)
        var projectBoost = Number(projectLevels.town_market || 0) * 0.02
        return 0.82 + r * 0.42 + projectBoost
    }

    function categoryMarket(category) { return categoryMarketForDay(category, day) }

    function marketPercentDelta(category) {
        return Math.round((categoryMarket(category) - 1.0) * 100)
    }

    function marketTrendIcon(category) {
        var delta = marketPercentDelta(category)
        if (delta >= 3) return Qt.resolvedUrl("assets/ui/arrow_up.svg")
        if (delta <= -3) return Qt.resolvedUrl("assets/ui/arrow_down.svg")
        return Qt.resolvedUrl("assets/ui/trend_flat.svg")
    }

    function marketCategoryLabelKey(category) {
        if (category === "vegetable") return "market_vegetables"
        if (category === "fruit") return "market_fruit"
        if (category === "grain") return "market_grain"
        if (category === "animal") return "market_animals"
        return "market_processed"
    }

    function marketForecast() {
        var cats = ["vegetable","fruit","grain","animal","processed"]
        var best = cats[0]
        var bestDelta = -1
        var bestDiff = 0
        for (var i=0; i<cats.length; ++i) {
            var now = categoryMarketForDay(cats[i], day)
            var tomorrow = categoryMarketForDay(cats[i], day + 1)
            var diff = tomorrow - now
            var magnitude = Math.abs(diff)
            if (magnitude > bestDelta) { bestDelta = magnitude; best = cats[i]; bestDiff = diff }
        }
        return {category:best, direction:bestDiff > 0.025 ? "rise" : (bestDiff < -0.025 ? "fall" : "steady")}
    }

    function marketForecastText() {
        var forecast = marketForecast()
        return tr(marketCategoryLabelKey(forecast.category)) + ": " + tr("forecast_" + forecast.direction)
    }

    function itemCategory(id) {
        for (var i=0; i<FarmData.crops.length; ++i) if (FarmData.crops[i].id === id) return FarmData.crops[i].category
        for (var j=0; j<FarmData.animals.length; ++j) if (FarmData.animals[j].product === id) return "animal"
        return "processed"
    }

    function marketMultiplierFor(id) {
        var cat = itemCategory(id)
        if (cat === "vegetable") return marketVegetable
        if (cat === "fruit" || cat === "flower" || cat === "rare") return marketFruit
        if (cat === "grain") return marketGrain
        if (cat === "animal") return marketAnimal
        return marketProcessed
    }

    function marketPrice(id) {
        return Math.max(1, Math.round(FarmData.productBase(id) * marketMultiplierFor(id)))
    }

    function addStat(key, amount) {
        var s = clone(lifetimeStats)
        s[key] = Number(s[key] || 0) + Number(amount || 1)
        lifetimeStats = s
    }

    function useEnergy(amount) {
        amount = Math.max(0, Number(amount || 0))
        if (energy < amount) {
            message = tr("msg_no_energy")
            root.haptic("light")
            return false
        }
        energy -= amount
        return true
    }

    function gainXp(amount) {
        farmXp += Math.max(0, Number(amount || 0))
        var need = farmLevel * 45
        var leveled = false
        while (farmXp >= need) {
            farmXp -= need
            farmLevel++
            maxEnergy = Math.max(maxEnergy, Math.min(40, 15 + farmLevel + Number(projectLevels.irrigation || 0)))
            energy = Math.min(maxEnergy, energy + 2)
            coins += 20 + farmLevel * 5
            leveled = true
            try { Achievements.unlock("farm_level_" + farmLevel) } catch (e) {}
            need = farmLevel * 45
        }
        if (leveled) {
            root.haptic("heavy")
            message = tr("msg_level_up") + " " + farmLevel
        }
    }

    function masteryTier(id) {
        var count = Number(cropHarvests[id] || 0)
        var tier = 0
        for (var i=0; i<FarmData.masteryThresholds.length; ++i)
            if (count >= FarmData.masteryThresholds[i]) tier = i
        return tier
    }

    function qualityFor(crop, plotIndex, fertilized) {
        var score = FarmData.hash01(worldSeed, day + plotIndex * 13, 83 + masteryTier(crop.id) * 7)
        score += masteryTier(crop.id) * 0.035
        if (fertilized) score += 0.18
        if (plotIndex < greenhouseCount) score += greenhouseLevel * 0.012
        score += Number(projectLevels.seed_lab || 0) * 0.018
        if (weather === "sunny") score += 0.025
        if (score >= 0.94) return "perfect"
        if (score >= 0.76) return "premium"
        if (score >= 0.48) return "fine"
        return "normal"
    }

    function qualityMultiplier(q) {
        if (q === "perfect") return 2.5
        if (q === "premium") return 1.8
        if (q === "fine") return 1.35
        return 1.0
    }

    function triggerVisualAction(kind, plotIndex) {
        visualActionKind = kind
        visualActionPlot = plotIndex
        visualActionSerial++
    }

    function isCropId(id) {
        for (var i=0; i<FarmData.crops.length; ++i) if (FarmData.crops[i].id === id) return true
        return false
    }

    function consumeItem(id, amount) {
        amount = Math.max(0, Math.floor(Number(amount || 0)))
        var inv = clone(inventory)
        if (Number(inv[id] || 0) < amount) return false
        inv[id] = Number(inv[id] || 0) - amount
        inventory = inv
        if (isCropId(id) && amount > 0) {
            var qi = clone(qualityInventory)
            if (!qi[id]) qi[id] = {normal:0, fine:0, premium:0, perfect:0}
            var left = amount
            var order = ["normal", "fine", "premium", "perfect"]
            for (var q=0; q<order.length && left>0; ++q) {
                var available = Math.max(0, Number(qi[id][order[q]] || 0))
                var take = Math.min(left, available)
                qi[id][order[q]] = available - take
                left -= take
            }
            qualityInventory = qi
        }
        return true
    }

    function addCropInventory(id, count, quality) {
        var inv = clone(inventory)
        inv[id] = Number(inv[id] || 0) + count
        inventory = inv
        var qi = clone(qualityInventory)
        if (!qi[id]) qi[id] = {normal:0, fine:0, premium:0, perfect:0}
        qi[id][quality] = Number(qi[id][quality] || 0) + count
        qualityInventory = qi
    }

    function plant(i) {
        if (i < 0 || i >= activePlotCount) return
        var p = plotState(i)
        if (p.crop !== "") return
        var d = selectedCrop
        if (!cropUnlocked(d)) {
            message = tr("msg_crop_locked") + " " + d.level
            return
        }
        if (!seasonAllowed(d, i)) {
            message = tr("msg_wrong_season") + " " + tr("grows_in") + ": " + cropSeasonText(d)
            return
        }
        var key = seedKey(d.id)
        if (Number(inventory[key] || 0) <= 0) {
            message = tr("msg_no_seed")
            return
        }
        if (!useEnergy(1)) return
        var next = clone(plots)
        next[i] = {crop:d.id, age:0, watered:false, fertilized:false}
        plots = next
        var inv = clone(inventory)
        inv[key] = Number(inv[key] || 0) - 1
        inventory = inv
        addStat("planted", 1)
        try { GameStats.increment("seeds_planted") } catch (e) {}
        message = tr("msg_planted") + " " + tr(d.key)
        triggerVisualAction("plant", i)
        root.playSfx("plant", 0.34)
        root.haptic("light")
        markDirty(false)
    }

    function wateringTargets(center) {
        var targetCount = FarmData.wateringCounts[Math.max(0, wateringTier - 1)]
        var result = []
        var cx = center % columns
        var cy = Math.floor(center / columns)
        var candidates = []
        for (var i=0; i<activePlotCount; ++i) {
            var x = i % columns
            var y = Math.floor(i / columns)
            var dist = Math.abs(x - cx) + Math.abs(y - cy)
            candidates.push({i:i, d:dist})
        }
        candidates.sort(function(a,b){ return a.d === b.d ? a.i - b.i : a.d - b.d })
        for (var c=0; c<candidates.length && result.length<targetCount; ++c) {
            var idx = candidates[c].i
            var p = plotState(idx)
            if (p.crop !== "" && !effectiveWatered(idx, p)) result.push(idx)
        }
        return result
    }

    function water(i) {
        var targets = wateringTargets(i)
        if (targets.length === 0) return
        if (!useEnergy(1)) return
        var next = clone(plots)
        for (var t=0; t<targets.length; ++t) next[targets[t]].watered = true
        plots = next
        addStat("watered", targets.length)
        message = tr("msg_watered") + " " + targets.length
        triggerVisualAction("water", i)
        root.playSfx("water", 0.30)
        root.haptic("light")
        markDirty(false)
    }

    function fertilize(i) {
        if (i < 0 || i >= activePlotCount) return
        var p = plotState(i)
        if (p.crop === "" || p.fertilized) return
        if (isHarvestReady(i)) {
            message = tr("msg_harvest_before_fertilize")
            return
        }
        if (Number(inventory.fertilizer || 0) <= 0) {
            message = tr("msg_no_fertilizer")
            return
        }
        var next = clone(plots)
        next[i].fertilized = true
        plots = next
        var inv = clone(inventory)
        inv.fertilizer = Number(inv.fertilizer || 0) - 1
        inventory = inv
        message = tr("msg_fertilized")
        triggerVisualAction("fertilize", i)
        root.playSfx("fertilize", 0.24)
        root.haptic("light")
        markDirty(false)
    }

    function isHarvestReady(i) {
        if (i < 0 || i >= activePlotCount) return false
        var p = plotState(i)
        if (!p || p.crop === "") return false
        var d = cropDef(p.crop)
        return !!d && Number(p.age || 0) >= Number(d.days || 1)
    }

    function harvestCore(i, batchMode) {
        if (i < 0 || i >= activePlotCount) { message = tr("msg_invalid_field"); return null }
        var p = plotState(i)
        if (!p || p.crop === "") { message = tr("msg_no_crop_here"); return null }
        var d = cropDef(p.crop)
        if (!d || Number(p.age || 0) < Number(d.days || 1)) { message = tr("msg_harvest_not_ready"); return null }
        if (!useEnergy(1)) return null
        var tier = masteryTier(d.id)
        var yieldCount = 1 + (p.fertilized ? 1 : 0)
        if (weather === "wind" && FarmData.hash01(worldSeed, day, i + 211) < 0.18) yieldCount++
        if (tier >= 3 && FarmData.hash01(worldSeed, day, i + 301) < 0.12) yieldCount++
        var quality = qualityFor(d, i, p.fertilized)
        addCropInventory(d.id, yieldCount, quality)
        var harvests = clone(cropHarvests)
        harvests[d.id] = Number(harvests[d.id] || 0) + yieldCount
        cropHarvests = harvests
        var next = clone(plots)
        next[i] = {crop:"", age:0, watered:false, fertilized:false}
        plots = next
        gainXp(7 + yieldCount * 2 + Number(projectLevels.festival || 0))
        addStat("harvested", yieldCount)
        try { GameStats.increment("crops_harvested", yieldCount) } catch (e) {}
        message = tr("msg_harvested") + " " + tr(d.key) + " " + yieldCount + " - " + tr("quality_" + quality)
        if (!batchMode) {
            showReward("+" + yieldCount + " " + tr(d.key), Qt.resolvedUrl("assets/products/" + d.id + ".svg"), "color.accent")
            triggerVisualAction("harvest", i)
            root.playSfx("harvest", 0.38)
            root.haptic("medium")
            markDirty(false)
        }
        return {id:d.id, key:d.key, count:yieldCount, quality:quality, plotIndex:i}
    }

    function harvest(i, batchMode) {
        // Harvest is an economy transaction. Roll back the entire persistent
        // state if an unexpected JS/QVariant failure occurs after energy or
        // inventory mutation, rather than leaving a half-harvested field.
        var before = clone(snapshot())
        try {
            return harvestCore(i, Boolean(batchMode))
        } catch (e) {
            try { restoreRuntimeSnapshot(before) } catch (rollbackError) {}
            message = tr("msg_harvest_failed")
            console.warn("Harvest Pocket: harvest transaction rolled back:", e)
            return null
        }
    }



    function batchWaterAllDry() {
        if (!batchWaterUnlocked) { message = tr("msg_batch_water_locked"); return }
        var candidates = []
        for (var i=0; i<activePlotCount; ++i) {
            var p = plotState(i)
            if (!p || p.crop === "") continue
            var d = cropDef(p.crop)
            if (Number(p.age || 0) >= Number(d.days || 1)) continue
            if (!effectiveWatered(i, p)) candidates.push(i)
        }
        if (candidates.length === 0) { message = tr("msg_no_dry_fields"); return }
        var perEnergy = Math.max(1, Number(FarmData.wateringCounts[Math.max(0, wateringTier - 1)] || 1))
        var possible = Math.min(candidates.length, Math.max(0, Math.floor(energy)) * perEnergy)
        if (possible <= 0) { message = tr("msg_no_energy"); root.haptic("light"); return }
        var energyCost = Math.ceil(possible / perEnergy)
        var next = clone(plots)
        for (var w=0; w<possible; ++w) next[candidates[w]].watered = true
        plots = next
        energy -= energyCost
        addStat("watered", possible)
        message = tr("msg_batch_watered") + " " + possible
        showReward("+" + possible + " " + tr("fields_watered"), Qt.resolvedUrl("assets/ui/water.svg"), "color.primary")
        triggerVisualAction("water", candidates[0])
        root.playSfx("water", 0.30)
        root.haptic("medium")
        markDirty(false)
    }

    function batchHarvestAllReady() {
        if (!batchHarvestUnlocked) { message = tr("msg_batch_harvest_locked"); return }
        var candidates = []
        for (var i=0; i<activePlotCount; ++i) if (isHarvestReady(i)) candidates.push(i)
        if (candidates.length === 0) { message = tr("msg_no_ready_fields"); return }
        var limit = Math.min(candidates.length, Math.max(0, Math.floor(energy)))
        if (limit <= 0) { message = tr("msg_no_energy"); root.haptic("light"); return }

        var before = clone(snapshot())
        try {
            var total = 0
            var byCrop = ({})
            var lastPlot = -1
            for (var h=0; h<limit; ++h) {
                var result = harvestCore(candidates[h], true)
                if (!result) continue
                total += Number(result.count || 0)
                byCrop[result.id] = Number(byCrop[result.id] || 0) + Number(result.count || 0)
                lastPlot = Number(result.plotIndex)
            }
            if (total <= 0) return
            var cropIds = Object.keys(byCrop)
            if (cropIds.length === 1) {
                var onlyId = cropIds[0]
                showReward("+" + total + " " + tr(FarmData.itemKey(onlyId)), Qt.resolvedUrl("assets/products/" + onlyId + ".svg"), "color.accent")
            } else {
                showReward("+" + total + " " + tr("harvest_items"), Qt.resolvedUrl("assets/tools/basket.svg"), "color.accent")
            }
            message = tr("msg_batch_harvested") + " " + total
            if (lastPlot >= 0) triggerVisualAction("harvest", lastPlot)
            root.playSfx("harvest", 0.38)
            root.haptic("heavy")
            markDirty(false)
        } catch (e) {
            try { restoreRuntimeSnapshot(before) } catch (rollbackError) {}
            message = tr("msg_harvest_failed")
            console.warn("Harvest Pocket: batch harvest transaction rolled back:", e)
        }
    }

    function batchFertilizeSelectedZone() {
        if (!batchFertilizeUnlocked) { message = tr("msg_batch_fertilize_locked"); return }
        var available = Math.max(0, Math.floor(Number(inventory.fertilizer || 0)))
        if (available <= 0) { message = tr("msg_no_fertilizer"); return }
        var zone = selectedIrrigationZone
        var start = zone * 8
        var end = Math.min(activePlotCount, start + 8)
        var targets = []
        for (var i=start; i<end; ++i) {
            var p = plotState(i)
            if (p && p.crop !== "" && !p.fertilized && !isHarvestReady(i)) targets.push(i)
        }
        var count = Math.min(targets.length, available)
        if (count <= 0) { message = tr("msg_no_fertilizable_fields"); return }
        var next = clone(plots)
        for (var f=0; f<count; ++f) next[targets[f]].fertilized = true
        plots = next
        var inv = clone(inventory)
        inv.fertilizer = available - count
        inventory = inv
        message = tr("msg_batch_fertilized") + " " + count + " - " + tr("zone") + " " + irrigationZoneLetter(zone)
        showReward("+" + count + " " + tr("fields_fertilized"), Qt.resolvedUrl("assets/ui/fertilizer.svg"), "color.accent")
        triggerVisualAction("fertilize", targets[0])
        root.playSfx("fertilize", 0.25)
        root.haptic("medium")
        markDirty(false)
    }

    function interact(i) {
        forceActiveFocus()
        if (i < 0 || i >= activePlotCount) return
        selectedPlot = i
        var p = plotState(i)
        if (p.crop === "") {
            plant(i)
            return
        }
        var d = cropDef(p.crop)
        if (isHarvestReady(i)) {
            harvest(i)
            return
        }
        if (!effectiveWatered(i, p)) {
            water(i)
            return
        }
        message = tr(d.key) + " - " + tr("label_growth") + " " + p.age + "/" + d.days
    }

    function buySeed(cropIndex) {
        var d = FarmData.crops[cropIndex]
        if (!cropUnlocked(d)) {
            message = tr("msg_crop_locked") + " " + d.level
            return
        }
        var discount = Number(projectLevels.research_center || 0) * 0.03
        var cost = Math.max(1, Math.round(d.seedCost * (1 - discount)))
        if (coins < cost) {
            message = tr("msg_not_enough_coins")
            return
        }
        coins -= cost
        var inv = clone(inventory)
        inv[seedKey(d.id)] = Number(inv[seedKey(d.id)] || 0) + 1
        inventory = inv
        selectedSeed = cropIndex
        root.playSfx("purchase", 0.28)
        markDirty(false)
    }

    function bestQualityAvailable(id) {
        var q = qualityInventory[id] || {normal:0,fine:0,premium:0,perfect:0}
        if (Number(q.perfect||0)>0) return "perfect"
        if (Number(q.premium||0)>0) return "premium"
        if (Number(q.fine||0)>0) return "fine"
        return "normal"
    }

    function removeQualityUnit(id, quality) {
        var qi = clone(qualityInventory)
        if (qi[id] && Number(qi[id][quality] || 0)>0) qi[id][quality] = Number(qi[id][quality] || 0)-1
        qualityInventory = qi
    }

    function sellItem(id) {
        var n = finiteNumber(inventory[id], 0)
        if (n <= 0) return
        var before = clone(snapshot())
        try {
            var basePrice = marketPrice(id)
            var quality = "normal"
            var isCrop = isCropId(id)
            var inv = clone(inventory)
            var qi = clone(qualityInventory)
            if (isCrop) {
                quality = bestQualityAvailable(id)
                if (!qi[id]) qi[id] = {normal:0, fine:0, premium:0, perfect:0}
                if (Math.max(0, finiteNumber(qi[id][quality], 0)) <= 0) quality = "normal"
                if (Math.max(0, finiteNumber(qi[id][quality], 0)) > 0)
                    qi[id][quality] = Math.max(0, finiteNumber(qi[id][quality], 0) - 1)
            }
            inv[id] = Math.max(0, n - 1)
            var earned = Math.max(1, Math.round(basePrice * (isCrop ? qualityMultiplier(quality) : 1)))
            inventory = inv
            qualityInventory = qi
            coins += earned
            addStat("sold", 1)
            try { GameStats.submitHighScore(coins, "coins") } catch (e) {}
            message = tr("msg_sold") + " " + tr(FarmData.itemKey(id)) + " +" + earned
            showReward("+" + earned + " " + tr("coins"), Qt.resolvedUrl("assets/ui/coin.svg"), "color.special")
            root.playSfx("sell", 0.36)
            markDirty(false)
        } catch (e) {
            try { restoreRuntimeSnapshot(before) } catch (rollbackError) {}
            message = tr("msg_transaction_failed")
            console.warn("Harvest Pocket: sell transaction rolled back:", e)
        }
    }

    function animalCapacity(animalId) {
        var d = FarmData.animalById(animalId)
        if (d.building === "coop") return FarmData.buildingCapacity[coopLevel]
        if (d.building === "barn") return FarmData.barnCapacity[barnLevel]
        return FarmData.apiaryCapacity[apiaryLevel]
    }

    function totalInBuilding(building) {
        var total = 0
        for (var i=0; i<FarmData.animals.length; ++i) {
            var d = FarmData.animals[i]
            if (d.building === building) total += Number(animalCounts[d.id] || 0)
        }
        return total
    }

    function buildingLevelFor(id) {
        return id === "coop" ? coopLevel : (id === "barn" ? barnLevel : apiaryLevel)
    }

    function buildingUnlockLevel(id) {
        return id === "coop" ? 5 : (id === "barn" ? 8 : 12)
    }

    function buyAnimal(animalId) {
        var d = FarmData.animalById(animalId)
        if (farmLevel < d.level) {
            message = tr("msg_unlock_level") + " " + d.level
            return
        }
        var bl = buildingLevelFor(d.building)
        if (bl < d.buildingLevel) {
            message = tr("msg_building_required") + " " + tr(d.buildingKey)
            return
        }
        var capacity = animalCapacity(animalId)
        if (totalInBuilding(d.building) >= capacity) {
            message = tr("msg_building_full")
            return
        }
        var count = Number(animalCounts[animalId] || 0)
        var cost = d.buyBase + count * d.buyStep
        if (coins < cost) {
            message = tr("msg_not_enough_coins")
            return
        }
        coins -= cost
        var ac = clone(animalCounts)
        ac[animalId] = count + 1
        animalCounts = ac
        message = tr("msg_animal_bought") + " " + tr(d.key)
        root.playSfx("animal_buy", 0.30)
        root.haptic("medium")
        markDirty(true)
    }

    function upgradeAnimalBuilding(id) {
        var current = buildingLevelFor(id)
        var unlockLevel = buildingUnlockLevel(id)
        if (current <= 0 && farmLevel < unlockLevel) {
            message = tr("msg_unlock_level") + " " + unlockLevel
            return
        }
        if (current >= 5) return
        var costs = id === "coop" ? FarmData.buildingCosts : (id === "barn" ? FarmData.barnCosts : FarmData.apiaryCosts)
        var cost = costs[current + 1]
        if (coins < cost) {
            message = tr("msg_not_enough_coins")
            return
        }
        coins -= cost
        if (id === "coop") coopLevel++
        else if (id === "barn") barnLevel++
        else apiaryLevel++
        root.playSfx("upgrade", 0.28)
        root.haptic("medium")
        message = tr("msg_building_upgraded")
        markDirty(true)
    }

    function moodMultiplier(value) {
        value = Number(value || 0)
        if (value < 25) return 0.50
        if (value < 50) return 0.75
        if (value < 75) return 1.0
        if (value < 90) return 1.10
        return 1.25
    }

    function animalMorning() {
        var inv = clone(inventory)
        var moods = clone(animalMood)
        var producedAny = false
        var producedTotal = 0
        for (var i=0; i<FarmData.animals.length; ++i) {
            var d = FarmData.animals[i]
            var count = Number(animalCounts[d.id] || 0)
            if (count <= 0) continue
            var feedNeed = count * d.feed
            var fedCount = count
            if (d.feed > 0) fedCount = Math.min(count, Math.floor(Number(inv.feed || 0) / d.feed))
            var consumed = fedCount * d.feed
            inv.feed = Math.max(0, Number(inv.feed || 0) - consumed)
            var mood = Number(moods[d.id] === undefined ? 50 : moods[d.id])
            if (fedCount >= count) mood += 5 + Number(projectLevels.veterinary || 0)
            else mood -= 8 + Math.ceil((count - fedCount) / Math.max(1, count) * 5)
            mood = FarmData.clamp(mood, 0, 100)
            moods[d.id] = mood
            var produced = Math.floor(fedCount * moodMultiplier(mood))
            var fraction = fedCount * moodMultiplier(mood) - produced
            if (FarmData.hash01(worldSeed, day, 500 + i) < fraction) produced++
            if (produced > 0) {
                inv[d.product] = Number(inv[d.product] || 0) + produced
                producedTotal += produced
                producedAny = true
            }
        }
        inventory = inv
        animalMood = moods
        if (producedAny) {
            message = tr("msg_animals_produced")
            showReward("+" + producedTotal + " " + tr("animal_products"), Qt.resolvedUrl("assets/ui/animals.svg"), "color.accent")
            root.playSfx("animal", 0.28)
        }
    }

    function sprinklerWater(nextPlots) {
        var count = Math.min(activePlotCount, sprinklerCount + Number(projectLevels.irrigation || 0) * 2)
        var wateredAny = false
        for (var i=0; i<count; ++i) {
            if (nextPlots[i].crop !== "") {
                nextPlots[i].watered = true
                wateredAny = true
            }
        }
        if (wateredAny) root.playSfx("sprinkler", 0.24)
        return nextPlots
    }

    function advanceCrops() {
        var next = clone(plots)
        next = sprinklerWater(next)
        var currentWeather = weather
        for (var i=0; i<activePlotCount; ++i) {
            var p = next[i]
            if (p.crop === "") continue
            var wateredEnough = p.watered || currentWeather === "rain" || currentWeather === "storm"
            if (currentWeather === "heatwave" && !p.watered) wateredEnough = false
            if (wateredEnough) p.age = Number(p.age || 0) + 1
            p.watered = false
        }
        plots = next
    }

    function dryOutdoorCropCount() {
        var dry = 0
        for (var i=0; i<activePlotCount; ++i) {
            var p = plots[i]
            if (p.crop === "") continue
            var def = cropDef(p.crop)
            if (Number(p.age || 0) >= Number(def.days || 1)) continue
            if (!effectiveWatered(i, p)) dry++
        }
        return dry
    }

    function triggerNextDayWarning() {
        nextDayWarningArmed = true
        message = tr("msg_next_day_warning")
        warningEdge.restart()
        if (!reducedMotion) warningShake.restart()
        root.haptic("heavy")
    }

    function commitNextDay() {
        var before = clone(snapshot())
        try {
            nextDayWarningArmed = false
            advanceCrops()
            animalMorning()
            day++
            refreshYear()
            syncOrderRefreshBudget()
            ensureSeasonSelection()
            energy = maxEnergy
            gainXp(2 + Number(projectLevels.festival || 0))
            addStat("days", 1)
            try { GameEvents.emitEvent("day_advanced", day) } catch (eventError) {}
            message = tr("msg_new_day")
            ensureOrders()
            markDirty(true)
            return true
        } catch (e) {
            try { restoreRuntimeSnapshot(before) } catch (rollbackError) {}
            nextDayWarningArmed = false
            message = tr("msg_day_commit_failed")
            console.warn("Harvest Pocket: Next Day transaction rolled back:", e)
            return false
        }
    }

    function nextDay() {
        if (nextDayTransitionRunning) return
        var dry = dryOutdoorCropCount()
        if (dry > 0 && !nextDayWarningArmed) {
            triggerNextDayWarning()
            return
        }
        nextDayWarningArmed = false
        warningEdge.stop()
        warningShake.stop()
        warningEdgeOpacity = 0
        warningShakeOffset = 0
        root.playSfx("day", 0.24)
        root.stopAmbientAudio()
        if (!visualFeedback.beginDay(root.seasonIndex, root.weather)) {
            message = tr("msg_transition_busy")
            Qt.callLater(root.syncAmbientAudio)
        }
    }

    function upgradeWatering() {
        if (wateringTier >= 5) return
        var cost = FarmData.toolCosts[wateringTier]
        if (coins < cost) { message = tr("msg_not_enough_coins"); return }
        coins -= cost
        wateringTier++
        message = tr("msg_tool_upgraded")
        root.playSfx("upgrade", 0.28)
        root.haptic("medium")
        markDirty(true)
    }

    function upgradeSprinkler() {
        if (sprinklerLevel <= 0 && farmLevel < 4) { message = tr("msg_unlock_level") + " 4"; return }
        if (sprinklerLevel >= 5) return
        var cost = FarmData.sprinklerCosts[sprinklerLevel + 1]
        if (coins < cost) { message = tr("msg_not_enough_coins"); return }
        coins -= cost
        sprinklerLevel++
        try { Achievements.unlock("sprinkler_farm") } catch (e) {}
        message = tr("msg_sprinkler_upgraded")
        root.playSfx("upgrade", 0.26)
        root.playSfx("sprinkler", 0.24)
        root.haptic("medium")
        markDirty(true)
    }

    function upgradeGreenhouse() {
        if (greenhouseLevel <= 0 && farmLevel < 10) { message = tr("msg_unlock_level") + " 10"; return }
        if (greenhouseLevel >= 5) return
        var cost = FarmData.greenhouseCosts[greenhouseLevel + 1]
        if (coins < cost) { message = tr("msg_not_enough_coins"); return }
        coins -= cost
        greenhouseLevel++
        try { Achievements.unlock("greenhouse_owner") } catch (e) {}
        message = tr("msg_greenhouse_upgraded")
        root.playSfx("upgrade", 0.28)
        root.haptic("medium")
        markDirty(true)
    }

    function expandLand() {
        if (landStage >= 4) return
        var nextStage = landStage + 1
        if (farmLevel < FarmData.landLevels[nextStage]) {
            message = tr("msg_unlock_level") + " " + FarmData.landLevels[nextStage]
            return
        }
        var cost = FarmData.landCosts[nextStage]
        if (coins < cost) { message = tr("msg_not_enough_coins"); return }
        coins -= cost
        landStage = nextStage
        message = tr("msg_land_expanded")
        root.playSfx("upgrade", 0.30)
        root.haptic("heavy")
        markDirty(true)
    }

    function buyFeed() {
        if (coins < 12) { message = tr("msg_not_enough_coins"); return }
        coins -= 12
        var inv = clone(inventory)
        inv.feed = Number(inv.feed || 0) + 4
        inventory = inv
        root.playSfx("purchase", 0.28)
        markDirty(false)
    }

    function buyFertilizer() {
        if (coins < 18) { message = tr("msg_not_enough_coins"); return }
        coins -= 18
        var inv = clone(inventory)
        inv.fertilizer = Number(inv.fertilizer || 0) + 2
        inventory = inv
        root.playSfx("purchase", 0.28)
        markDirty(false)
    }

    function buildProcessing(id) {
        for (var i=0; i<FarmData.processingBuildings.length; ++i) {
            var b = FarmData.processingBuildings[i]
            if (b.id !== id) continue
            if (farmLevel < b.level) { message = tr("msg_unlock_level") + " " + b.level; return }
            if (processingBuilt[id]) return
            if (coins < b.cost) { message = tr("msg_not_enough_coins"); return }
            coins -= b.cost
            var pb = clone(processingBuilt)
            pb[id] = true
            processingBuilt = pb
            message = tr("msg_building_built") + " " + tr(b.key)
            root.playSfx("workshop", 0.30)
            root.haptic("medium")
            markDirty(true)
            return
        }
    }

    function recipeInputText(recipe) {
        var parts = []
        for (var key in recipe.inputs) parts.push(tr(FarmData.itemKey(key)) + " " + recipe.inputs[key])
        return parts.join(" + ")
    }

    function canCraft(recipe) {
        if (!processingBuilt[recipe.building]) return false
        if (farmLevel < recipe.level || energy < recipe.energy) return false
        for (var key in recipe.inputs) if (Number(inventory[key] || 0) < Number(recipe.inputs[key])) return false
        return true
    }

    function craft(recipe) {
        if (!processingBuilt[recipe.building]) { message = tr("msg_building_required") + " " + tr(recipe.buildingKey); return }
        if (farmLevel < recipe.level) { message = tr("msg_unlock_level") + " " + recipe.level; return }
        if (energy < recipe.energy) { message = tr("msg_no_energy"); root.haptic("light"); return }

        // Build the complete transaction before mutating live state. Bread and
        // other multi-ingredient recipes must never consume flour/energy and
        // then fail on a later ingredient.
        var inv = clone(inventory)
        var qi = clone(qualityInventory)
        for (var key in recipe.inputs) {
            var need = Math.max(0, Math.floor(Number(recipe.inputs[key] || 0)))
            if (Number(inv[key] || 0) < need) { message = tr("msg_missing_ingredients"); return }
            inv[key] = Number(inv[key] || 0) - need
            if (isCropId(key) && need > 0) {
                if (!qi[key]) qi[key] = {normal:0, fine:0, premium:0, perfect:0}
                var left = need
                var qualityOrder = ["normal", "fine", "premium", "perfect"]
                for (var q=0; q<qualityOrder.length && left>0; ++q) {
                    var available = Math.max(0, Number(qi[key][qualityOrder[q]] || 0))
                    var take = Math.min(left, available)
                    qi[key][qualityOrder[q]] = available - take
                    left -= take
                }
            }
        }

        energy -= recipe.energy
        var bonus = Number(projectLevels.bakery || 0) >= 4 && FarmData.hash01(worldSeed, day, orderSerial + recipe.level) < 0.18 ? 1 : 0
        inv[recipe.output] = Number(inv[recipe.output] || 0) + recipe.amount + bonus
        inventory = inv
        qualityInventory = qi
        addStat("crafted", recipe.amount + bonus)
        gainXp(4 + recipe.amount)
        message = tr("msg_crafted") + " " + tr(recipe.key)
        showReward("+" + (recipe.amount + bonus) + " " + tr(recipe.key), Qt.resolvedUrl("assets/products/" + recipe.output + ".svg"), "color.accent")
        root.playSfx(recipe.output === "bread" ? "workshop" : "craft", recipe.output === "bread" ? 0.30 : 0.32)
        root.haptic("light")
        markDirty(false)
    }

    function orderSlotUnlocked(slot) {
        if (slot === 0) return true
        if (slot === 1) return reputation >= 5
        return reputation >= 20
    }

    function availableOrderItems() {
        var pool = []
        for (var i=0; i<FarmData.crops.length; ++i) {
            var crop = FarmData.crops[i]
            var stocked = Number(inventory[crop.id] || 0) > 0
            var seasonReachable = cropNaturallyInSeason(crop) || greenhouseCount > 0
            if (cropUnlocked(crop) && (stocked || seasonReachable)) pool.push(crop.id)
        }
        for (var a=0; a<FarmData.animals.length; ++a) if (Number(animalCounts[FarmData.animals[a].id]||0)>0) pool.push(FarmData.animals[a].product)
        for (var r=0; r<FarmData.recipes.length; ++r) if (processingBuilt[FarmData.recipes[r].building]) pool.push(FarmData.recipes[r].output)
        return pool.length > 0 ? pool : ["turnip"]
    }

    function orderVisibleSignature(o) {
        if (!o || !o.item) return ""
        return String(o.item) + "|" + Math.floor(Number(o.amount || 0)) + "|" + Math.floor(Number(o.reward || 0)) + "|" + (o.special ? "1" : "0")
    }

    function countRefreshableOrders() {
        var count = 0
        for (var i=0; i<3; ++i) {
            if (!orderSlotUnlocked(i)) continue
            var o = orders && i < orders.length ? orders[i] : null
            if (!o || o.status !== "accepted") count++
        }
        return count
    }

    function generateOrder(slot, avoidSignature) {
        var pool = availableOrderItems()
        var avoid = String(avoidSignature || "")
        var candidate = null
        // A refresh must be visibly meaningful. Small early-game item pools can
        // otherwise deterministically produce the same item/amount/reward and
        // make the refresh button look broken even though a serial was consumed.
        for (var attempt=0; attempt<8; ++attempt) {
            var serial = orderSerial
            var roll = FarmData.hash01(worldSeed, serial + day * 3 + attempt * 17, 700 + slot)
            var idx = Math.min(pool.length - 1, Math.floor(roll * pool.length))
            var item = pool[idx]
            var amount = 2 + Math.floor(FarmData.hash01(worldSeed, serial + day + attempt * 11, 740 + slot) * Math.min(7, 2 + Math.floor(farmLevel / 3)))
            var specialChance = reputation >= 10 ? (0.13 + Number(projectLevels.town_market || 0) * 0.025) : 0
            var special = FarmData.hash01(worldSeed, day * 19 + serial + attempt * 23, 880 + slot) < specialChance
            if (special) amount = Math.max(amount + 1, Math.round(amount * 1.35))
            var railway = 1 + Number(projectLevels.railway || 0) * 0.04
            var rewardScale = special ? 2.05 : 1.55
            var reward = Math.max(12, Math.round(FarmData.productBase(item) * amount * (rewardScale + reputation * 0.002) * railway))
            orderSerial++
            candidate = {id:serial + 1, item:item, amount:amount, reward:reward, status:"available", special:special, expiresDay:special ? day + 2 : 0}
            if (avoid.length === 0 || orderVisibleSignature(candidate) !== avoid) return candidate
        }
        // Extremely small pools can still collide repeatedly. Guarantee a visible
        // change instead of charging a daily refresh for an indistinguishable card.
        if (candidate && avoid.length > 0) {
            candidate.amount = Math.max(1, Math.floor(Number(candidate.amount || 1)) + 1)
            var railwayFallback = 1 + Number(projectLevels.railway || 0) * 0.04
            var scaleFallback = candidate.special ? 2.05 : 1.55
            candidate.reward = Math.max(12, Math.round(FarmData.productBase(candidate.item) * candidate.amount * (scaleFallback + reputation * 0.002) * railwayFallback))
        }
        return candidate
    }

    function syncOrderRefreshBudget() {
        if (orderRefreshDay !== day) {
            orderRefreshDay = day
            orderRefreshesUsed = 0
        }
    }

    function recordOrderHistory(outcome, o) {
        if (!o || !o.item || !outcome) return
        var history = clone(orderHistory || [])
        history.unshift({item:String(o.item), amount:Math.max(1, Number(o.amount || 1)), reward:Math.max(0, Number(o.reward || 0)), outcome:String(outcome), day:day, special:Boolean(o.special)})
        if (history.length > 40) history = history.slice(0,40)
        orderHistory = history
        if (outcome === "completed") highestOrderReward = Math.max(highestOrderReward, Number(o.reward || 0))
    }

    function orderHistoryCount(outcome) {
        var count = 0
        for (var i=0; i<orderHistory.length; ++i) if (orderHistory[i].outcome === outcome) count++
        return count
    }

    function orderExpiryText(o) {
        if (!o || !o.special || Number(o.expiresDay || 0) <= 0) return ""
        var left = Number(o.expiresDay) - day
        if (left <= 0) return tr("expires_today")
        return tr("expires_in") + " " + left + " " + tr(left === 1 ? "day_unit" : "days_unit")
    }

    function orderStatusKey(o) {
        if (!o) return "order_empty"
        if (o.status === "available") return "order_status_available"
        if (o.status === "accepted") return "order_status_accepted"
        if (o.status === "completed") return "order_status_completed"
        if (o.status === "rejected") return "order_status_rejected"
        if (o.status === "abandoned") return "order_status_abandoned"
        if (o.status === "expired") return "order_status_expired"
        if (o.status === "cooldown") return "order_cooldown"
        return "order_empty"
    }

    function ensureOrders() {
        syncOrderRefreshBudget()
        var next = clone(orders || [])
        while (next.length < 3) next.push(null)
        if (next.length > 3) next = next.slice(0,3)
        for (var i=0; i<3; ++i) {
            if (!orderSlotUnlocked(i)) {
                next[i] = null
                continue
            }
            var o = next[i]
            if (o && o.special && Number(o.expiresDay || 0) > 0 && day > Number(o.expiresDay) && (o.status === "available" || o.status === "accepted")) {
                recordOrderHistory("expired", o)
                addStat("ordersExpired", 1)
                o.status = "expired"
                o.closedDay = day
                next[i] = o
                continue
            }
            if (o && o.status === "cooldown") {
                if (Number(o.cooldownUntil || 0) <= day) next[i] = generateOrder(i)
                continue
            }
            if (o && (o.status === "rejected" || o.status === "abandoned" || o.status === "completed")) {
                if (Number(o.closedDay || day) < day) next[i] = generateOrder(i)
                continue
            }
            if (!o || !o.item) next[i] = generateOrder(i)
        }
        orders = next
    }

    function refreshOrderBoard() {
        syncOrderRefreshBudget()
        if (orderRefreshesUsed >= orderRefreshBudget) {
            message = tr("msg_board_refresh_exhausted")
            return
        }
        var next = clone(orders || [])
        var changed = 0
        while (next.length < 3) next.push(null)
        for (var i=0; i<3; ++i) {
            if (!orderSlotUnlocked(i)) continue
            var o = next[i]
            if (o && o.status === "accepted") continue
            next[i] = generateOrder(i, orderVisibleSignature(o))
            if (orderVisibleSignature(next[i]) !== orderVisibleSignature(o)) changed++
        }
        if (changed <= 0) {
            message = tr("msg_no_refreshable_orders")
            return
        }
        orders = next
        orderRefreshesUsed++
        message = tr("msg_board_refreshed")
        root.playSfx("order_accept", 0.18)
        root.haptic("light")
        markDirty(true)
    }

    function acceptOrder(slot) {
        if (!orders[slot] || orders[slot].status !== "available") return
        var next = clone(orders)
        next[slot].status = "accepted"
        next[slot].acceptedDay = day
        orders = next
        message = tr("msg_order_accepted")
        root.playSfx("order_accept", 0.24)
        markDirty(false)
    }

    function rejectOrder(slot) {
        var o = orders[slot]
        if (!o || o.status !== "available") return
        var next = clone(orders)
        next[slot].status = "rejected"
        next[slot].closedDay = day
        orders = next
        recordOrderHistory("rejected", o)
        addStat("ordersRejected", 1)
        message = tr("msg_order_rejected")
        root.playSfx("order_reject", 0.22)
        root.haptic("light")
        markDirty(true)
    }

    function abandonOrder(slot) {
        var o = orders[slot]
        if (!o || o.status !== "accepted") return
        var next = clone(orders)
        next[slot].status = "abandoned"
        next[slot].closedDay = day
        orders = next
        recordOrderHistory("abandoned", o)
        addStat("ordersAbandoned", 1)
        message = tr("msg_order_abandoned")
        root.playSfx("order_reject", 0.24)
        root.haptic("medium")
        markDirty(true)
    }

    function orderStock(slot) {
        var o = orders[slot]
        if (!o || !o.item) return 0
        return Math.max(0, Number(inventory[o.item] || 0))
    }

    function deliverOrder(slot) {
        var o = orders[slot]
        if (!o || o.status !== "accepted") return
        if (o.special && finiteNumber(o.expiresDay, 0) > 0 && day > finiteNumber(o.expiresDay, 0)) { message = tr("msg_order_expired"); ensureOrders(); return }
        if (orderStock(slot) < finiteNumber(o.amount, 1)) { message = tr("msg_order_not_ready"); return }
        var before = clone(snapshot())
        try {
            if (!consumeItem(o.item, o.amount)) { message = tr("msg_order_not_ready"); return }
            coins += finiteNumber(o.reward, 0)
            reputation++
            addStat("orders", 1)
            recordOrderHistory("completed", o)
            try { GameStats.increment("orders_completed") } catch (e) {}
            if (reputation >= 10) { try { Achievements.unlock("trusted_farmer") } catch (e2) {} }
            var next = clone(orders)
            next[slot].status = "completed"
            next[slot].closedDay = day
            orders = next
            message = tr("msg_order_completed")
            showReward("+" + finiteNumber(o.reward, 0) + " " + tr("coins"), Qt.resolvedUrl("assets/ui/coin.svg"), "color.special")
            root.playSfx("order_deliver", 0.34)
            root.haptic("heavy")
            markDirty(true)
        } catch (e) {
            try { restoreRuntimeSnapshot(before) } catch (rollbackError) {}
            message = tr("msg_transaction_failed")
            console.warn("Harvest Pocket: order delivery transaction rolled back:", e)
        }
    }

    function projectCost(project, phase) {
        var p = Math.max(1, phase)
        return {coins:Math.round(project.coinBase * Math.pow(2.15,p-1)), item:Math.round(project.itemBase * Math.pow(1.75,p-1))}
    }

    function advanceProject(project) {
        var current = finiteNumber(projectLevels[project.id], 0)
        if (current >= 5) return
        if (reputation < project.unlockRep) { message = tr("msg_reputation_required") + " " + project.unlockRep; return }
        var cost = projectCost(project, current + 1)
        if (coins < cost.coins || finiteNumber(inventory[project.item], 0) < cost.item) { message = tr("msg_project_resources"); return }
        var before = clone(snapshot())
        try {
            if (!consumeItem(project.item, cost.item)) { message = tr("msg_project_resources"); return }
            coins -= cost.coins
            var levels = clone(projectLevels)
            levels[project.id] = current + 1
            projectLevels = levels
            addStat("projects", 1)
            maxEnergy = Math.max(maxEnergy, Math.min(40, 15 + farmLevel + finiteNumber(projectLevels.irrigation, 0)))
            energy = Math.min(energy, maxEnergy)
            message = tr("msg_project_advanced") + " " + tr(project.key)
            root.playSfx("upgrade", 0.30)
            root.haptic("heavy")
            markDirty(true)
        } catch (e) {
            try { restoreRuntimeSnapshot(before) } catch (rollbackError) {}
            message = tr("msg_transaction_failed")
            console.warn("Harvest Pocket: project transaction rolled back:", e)
        }
    }

    function cycleSeedSelection(step) {
        var indexes = cropChooserIndexes
        if (!indexes || indexes.length === 0) return
        var pos = indexes.indexOf(selectedSeed)
        if (pos < 0) pos = 0
        else pos = (pos + step + indexes.length) % indexes.length
        selectedSeed = indexes[pos]
    }

    function selectCropShortcut(slot) {
        var indexes = cropChooserIndexes
        if (!indexes || slot < 0 || slot >= indexes.length) return
        selectedSeed = indexes[slot]
    }

    function moveSelection(dx, dy) {
        var x = selectedPlot % columns
        var y = Math.floor(selectedPlot / columns)
        x = Math.max(0, Math.min(columns - 1, x + dx))
        y = Math.max(0, Math.min(rows - 1, y + dy))
        var candidate = Math.min(activePlotCount - 1, y * columns + x)
        selectedPlot = Math.max(0, candidate)
    }

    function pause() {
        if (saveDirty) writeSave(true)
        try { if (typeof GameAudio !== "undefined" && typeof GameAudio.pauseAll === "function") GameAudio.pauseAll() } catch (e) {}
    }
    function resume() {
        forceActiveFocus()
        try { if (typeof GameAudio !== "undefined" && typeof GameAudio.resumeAll === "function") GameAudio.resumeAll() } catch (e) {}
        Qt.callLater(root.syncAmbientAudio)
    }
    function background() {
        if (saveDirty) writeSave(true)
        try { if (typeof GameAudio !== "undefined" && typeof GameAudio.pauseAll === "function") GameAudio.pauseAll() } catch (e) {}
    }
    function foreground() {
        forceActiveFocus()
        try { if (typeof GameAudio !== "undefined" && typeof GameAudio.resumeAll === "function") GameAudio.resumeAll() } catch (e) {}
        Qt.callLater(root.syncAmbientAudio)
    }
    function save() { writeSave(true) }
    function close() { stopAmbientAudio(); writeSave(true) }
    function unload() { stopAmbientAudio(); writeSave(true) }

    Timer {
        id: initializationRetry
        interval: 80
        repeat: true
        running: !root.initializationDone
        onTriggered: root.ensureInitialized()
    }

    Timer {
        id: saveDebounce
        interval: 550
        repeat: false
        onTriggered: root.writeSave(false)
    }

    Timer {
        id: visualPulse
        interval: root.visualQuality === "low" ? 1500 : 900
        repeat: true
        running: !root.reducedMotion && root.visible && (root.activeTab === 0 || root.activeTab === 1)
        onTriggered: root.animationPulse++
    }

    SequentialAnimation {
        id: warningShake
        running: false
        NumberAnimation { target: root; property: "warningShakeOffset"; to: -10; duration: 45 }
        NumberAnimation { target: root; property: "warningShakeOffset"; to: 9; duration: 55 }
        NumberAnimation { target: root; property: "warningShakeOffset"; to: -7; duration: 55 }
        NumberAnimation { target: root; property: "warningShakeOffset"; to: 6; duration: 55 }
        NumberAnimation { target: root; property: "warningShakeOffset"; to: -3; duration: 50 }
        NumberAnimation { target: root; property: "warningShakeOffset"; to: 0; duration: 65 }
    }

    SequentialAnimation {
        id: warningEdge
        running: false
        NumberAnimation { target: root; property: "warningEdgeOpacity"; from: 0; to: 1; duration: root.reducedMotion ? 70 : 120 }
        PauseAnimation { duration: root.reducedMotion ? 120 : 300 }
        NumberAnimation { target: root; property: "warningEdgeOpacity"; to: 0; duration: root.reducedMotion ? 120 : 520 }
    }

    SequentialAnimation {
        id: tabSwitchAnimation
        running: false
        ParallelAnimation {
            NumberAnimation { target: root; property: "tabContentOpacity"; to: 0.0; duration: 85; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "tabContentOffset"; to: -root.tabSlideDirection * 8; duration: 85; easing.type: Easing.OutQuad }
        }
        ScriptAction {
            script: {
                root.activeTab = root.pendingTab
                root.pendingTab = -1
                root.tabContentOffset = root.tabSlideDirection * 12
                scroll.contentY = 0
            }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "tabContentOpacity"; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "tabContentOffset"; to: 0; duration: 150; easing.type: Easing.OutCubic }
        }
    }

    Keys.onPressed: function(event) {
        if (root.inputLocked) { event.accepted = true; return }
        if (event.key === Qt.Key_N) { nextDay(); event.accepted = true; return }
        if (root.activeTab !== 0) return
        if (event.key === Qt.Key_Left || event.key === Qt.Key_A) moveSelection(-1,0)
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) moveSelection(1,0)
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_W) moveSelection(0,-1)
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_S) moveSelection(0,1)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) interact(selectedPlot)
        else if (event.key === Qt.Key_F) fertilize(selectedPlot)
        else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) selectCropShortcut(event.key - Qt.Key_1)
        else return
        event.accepted = true
    }

    Rectangle {
        anchors.fill: parent
        color: GameTheme.color("color.background")
    }

    StickyHud {
        id: stickyHud
        z: 20
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 6
        width: Math.min(parent.width - 12, root.wideLayout ? 1180 : parent.width - 12)
        compact: root.compactLayout
        coinsLabel: root.tr("coins")
        coinsValue: root.fmt(root.coins)
        energyLabel: root.tr("energy")
        energyValue: root.fmt(root.energy) + "/" + root.fmt(root.maxEnergy)
        dayLabel: root.tr("day")
        dayValue: String(root.day)
        seasonLabel: root.tr("season")
        seasonValue: root.tr(root.seasonKey)
        weatherLabel: root.tr("weather")
        weatherValue: root.tr("weather_" + root.weather)
        levelLabel: root.tr("level")
        levelValue: String(root.farmLevel)
        reputationLabel: root.tr("reputation")
        reputationValue: String(root.reputation)
    }

    AdaptiveNavigation {
        id: topNavigation
        z: 20
        visible: !root.compactLayout
        mode: "top"
        dense: root.wideLayout
        currentIndex: root.activeTab
        anchors.top: stickyHud.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 5
        width: Math.min(parent.width - 12, root.wideLayout ? 760 : 900)
        farmText: root.tr("tab_farm")
        animalsText: root.tr("tab_animals")
        marketText: root.tr("tab_market")
        workshopText: root.tr("tab_workshop")
        journalText: root.tr("tab_journal")
        onSelected: function(index) { root.switchTab(index) }
    }

    AdaptiveNavigation {
        id: bottomNavigation
        z: 20
        visible: root.compactLayout
        mode: "bottom"
        dense: false
        currentIndex: root.activeTab
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 6
        farmText: root.tr("tab_farm")
        animalsText: root.tr("tab_animals")
        marketText: root.tr("tab_market")
        workshopText: root.tr("tab_workshop")
        journalText: root.tr("tab_journal")
        onSelected: function(index) { root.switchTab(index) }
    }

    ContextActionBar {
        id: farmActionBar
        z: 21
        visible: root.activeTab === 0
        enabled: !root.inputLocked
        compact: root.compactLayout
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 12, root.wideLayout ? 1180 : parent.width - 12)
        anchors.bottom: root.compactLayout ? bottomNavigation.top : parent.bottom
        anchors.bottomMargin: 6
        cropIcon: Qt.resolvedUrl("assets/crops/" + root.selectedCrop.id + ".svg")
        cropName: root.tr(root.selectedCrop.key)
        seedInfo: root.tr("label_seed") + ": " + root.fmt(Number(root.inventory[root.selectedCrop.id + "Seed"] || 0))
        buyText: root.tr("buy_seed")
        buySubText: root.fmt(Math.max(1, Math.round(root.selectedCrop.seedCost * (1 - Number(root.projectLevels.research_center || 0) * 0.03)))) + " " + root.tr("coins")
        fertilizeText: root.tr("fertilize")
        fertilizerInfo: root.fmt(Number(root.inventory.fertilizer || 0))
        harvestText: root.tr("harvest_selected")
        harvestInfo: root.selectedPlotReady ? (root.energy > 0 ? root.tr("ready_to_harvest") : root.tr("msg_no_energy")) : ""
        harvestVisible: root.selectedPlotReady
        canHarvest: root.selectedPlotReady && root.energy > 0
        nextDayText: root.nextDayWarningArmed ? root.tr("next_day_confirm") : root.tr("next_day")
        nextDaySubText: root.nextDayWarningArmed ? root.tr("next_day_warning_short") : ""
        canBuySeed: root.cropUnlocked(root.selectedCrop)
        canFertilize: Number(root.inventory.fertilizer || 0) > 0 && root.selectedPlotState && root.selectedPlotState.crop !== "" && !root.selectedPlotState.fertilized && !root.selectedPlotReady
        warningArmed: root.nextDayWarningArmed
        transitionRunning: root.nextDayTransitionRunning
        onBuySeed: root.buySeed(root.selectedSeed)
        onFertilize: root.fertilize(root.selectedPlot)
        onHarvest: root.harvest(root.selectedPlot)
        onNextDay: root.nextDay()
    }

    Flickable {
        id: scroll
        anchors.fill: parent
        anchors.topMargin: stickyHud.height + 12 + (topNavigation.visible ? topNavigation.height + 5 : 0)
        anchors.bottomMargin: (farmActionBar.visible ? farmActionBar.height + 12 : 6) + (bottomNavigation.visible ? bottomNavigation.height + 5 : 0)
        contentWidth: width
        contentHeight: mainColumn.implicitHeight + root.contentPadding * 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: mainColumn
            enabled: !root.inputLocked
            x: Math.max(root.contentPadding, (scroll.width - width) / 2) + root.warningShakeOffset + root.tabContentOffset
            y: root.contentPadding
            width: Math.max(220, Math.min(root.contentMaxWidth, scroll.width - root.contentPadding * 2))
            opacity: root.tabContentOpacity
            spacing: Math.max(8, GameTheme.number("alias.card.gap"))

            Column {
                width: parent.width
                spacing: 9
                visible: activeTab === 0

                UiPanel {
                    width: parent.width
                    implicitHeight: farmHeader.implicitHeight + 20
                    Row {
                        id: farmHeader
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        Image { width:42; height:42; source:Qt.resolvedUrl("assets/weather/"+weather+".svg"); fillMode:Image.PreserveAspectFit; cache:true }
                        Column {
                            width: Math.max(100, parent.width - 58)
                            UiText { width:parent.width; text:tr(seasonKey)+" - "+tr("day")+" "+seasonDay+"/7 - "+tr("weather_"+weather); font.bold:true }
                            UiText { width:parent.width; text:tr("farm_weather_hint_"+weather); colorToken:"color.textMuted"; sizeToken:"metric.font.xs" }
                        }
                    }
                }

                UiPanel {
                    width: parent.width
                    implicitHeight: plantingColumn.implicitHeight + 18
                    Column {
                        id: plantingColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 9
                        spacing: 8

                        Flow {
                            width: parent.width
                            spacing: 7
                            Row {
                                spacing: 7
                                Image { width:26; height:26; source:Qt.resolvedUrl("assets/ui/seed.svg"); fillMode:Image.PreserveAspectFit; cache:true }
                                UiText { anchors.verticalCenter:parent.verticalCenter; text:tr("planting"); font.bold:true }
                            }
                            Row {
                                spacing: 5
                                Image { width:22; height:22; source:Qt.resolvedUrl("assets/seasons/"+["spring","summer","autumn","winter"][root.seasonIndex]+".svg"); fillMode:Image.PreserveAspectFit; cache:true }
                                UiText { anchors.verticalCenter:parent.verticalCenter; text:tr("current_season")+": "+tr(root.seasonKey); colorToken:"color.textMuted"; sizeToken:"metric.font.xs" }
                            }
                            UiButton { compact:true; primary:!root.showAllCrops; text:tr("this_season"); onActivated:{root.showAllCrops=false; root.ensureSeasonSelection()} }
                            UiButton { compact:true; primary:root.showAllCrops; text:tr("all_crops"); onActivated:root.showAllCrops=true }
                        }

                        Flow {
                            id: cropChooser
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: root.cropChooserIndexes
                                SeasonCropButton {
                                    property int cropIndex: Number(modelData)
                                    property var crop: FarmData.crops[cropIndex]
                                    selected: root.selectedSeed === cropIndex
                                    enabled: root.cropUnlocked(crop)
                                    iconSource: Qt.resolvedUrl("assets/crops/"+crop.id+".svg")
                                    cropName: tr(crop.key)
                                    seedCount: Number(root.inventory[crop.id+"Seed"]||0)
                                    seasons: crop.seasons
                                    currentSeason: root.seasonIndex
                                    inCurrentSeason: root.cropNaturallyInSeason(crop)
                                    onActivated: root.selectedSeed=cropIndex
                                }
                            }
                        }

                        UiPanel {
                            width: parent.width
                            implicitHeight: selectedCropFlow.implicitHeight + 16
                            surfaceToken: "surface.control"
                            Flow {
                                id: selectedCropFlow
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 9
                                Image { width:48; height:48; source:Qt.resolvedUrl("assets/crops/"+root.selectedCrop.id+".svg"); fillMode:Image.PreserveAspectFit; cache:true }
                                Column {
                                    width: Math.max(150, Math.min(360, selectedCropFlow.width - 210))
                                    spacing: 2
                                    UiText { width:parent.width; text:tr(root.selectedCrop.key); font.bold:true }
                                    UiText { width:parent.width; text:tr("grows_in")+": "+root.cropSeasonText(root.selectedCrop); colorToken:"color.textMuted"; sizeToken:"metric.font.xs" }
                                    UiText { width:parent.width; text:tr("growth_days")+": "+root.selectedCrop.days+" | "+tr("label_seed")+": "+fmt(Number(root.inventory[root.selectedCrop.id+"Seed"]||0)); colorToken:"color.textMuted"; sizeToken:"metric.font.xs" }
                                    UiText { width:parent.width; text:tr(root.cropPlantStatusKey(root.selectedCrop)); font.bold:true; sizeToken:"metric.font.xs" }
                                }
                            }
                        }
                    }
                }

                UiPanel {
                    width: parent.width
                    implicitHeight: farmGrid.implicitHeight + 20
                    Grid {
                        id: farmGrid
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        columns: root.columns
                        spacing: root.width < 560 ? 5 : 7
                        Repeater {
                            model: root.plotCount
                            FarmPlot {
                                property var p: root.plotState(index)
                                width: Math.max(54, Math.min(88, (mainColumn.width - 42 - farmGrid.spacing*(root.columns-1)) / root.columns))
                                height: width
                                plotIndex: index
                                plotData: p
                                unlocked: index < root.activePlotCount
                                selected: index === root.selectedPlot
                                soilSource: root.soilSource(p, index)
                                cropSource: root.cropSource(p)
                                sprinklerCovered: index < root.effectiveSprinklerCoverage
                                waterSource: root.waterSourceForPlot(index, p)
                                fieldState: root.fieldStateFor(index, p)
                                zoneIndex: root.irrigationZoneForPlot(index)
                                zoneCoverage: root.irrigationZoneCoverage(root.irrigationZoneForPlot(index))
                                selectedZone: root.irrigationZoneForPlot(index) === root.selectedIrrigationZone
                                greenhouseCovered: index < Math.min(root.activePlotCount, root.greenhouseCount)
                                ready: p.crop!=="" && p.age>=root.cropDef(p.crop).days
                                reducedMotion: root.reducedMotion || root.visualQuality==="low"
                                animationPulse: root.animationPulse
                                swayAmount: root.weather==="wind" ? 2.4 : (root.weather==="storm" ? 3.0 : 0.75)
                                actionSerial: root.visualActionSerial
                                actionKind: root.visualActionKind
                                actionActive: index === root.visualActionPlot
                                wateringToolSource: Qt.resolvedUrl("assets/tools/watering_"+["basic","copper","steel","gold","master"][root.wateringTier-1]+".svg")
                                onActivated: function(i){ root.interact(i) }
                            }
                        }
                    }
                }

                UiPanel {
                    width: parent.width
                    implicitHeight: smartFieldsColumn.implicitHeight + 20
                    Column {
                        id: smartFieldsColumn
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Flow {
                            width: parent.width
                            spacing: 8
                            Row {
                                spacing: 7
                                Image { width:24; height:24; source:Qt.resolvedUrl("assets/projects/irrigation.svg"); fillMode:Image.PreserveAspectFit; cache:true }
                                UiText { anchors.verticalCenter:parent.verticalCenter; text:tr("smart_fields"); font.bold:true }
                            }
                            UiText {
                                width: Math.max(150, Math.min(parent.width, implicitWidth))
                                text: {
                                    var source = root.waterSourceForPlot(root.selectedPlot, root.plotState(root.selectedPlot))
                                    return tr("selected_field_state")+": "+tr(root.fieldStateKey(root.fieldStateFor(root.selectedPlot, root.plotState(root.selectedPlot))))+
                                           " | "+tr("water_source")+": "+tr("water_source_"+(source.length>0?source:"none"))
                                }
                                colorToken:"color.textMuted"
                                sizeToken:"metric.font.xs"
                            }
                        }
                        UiText { width:parent.width; text:tr("irrigation_zones_help"); colorToken:"color.textMuted"; sizeToken:"metric.font.xs"; wrapMode:Text.WordWrap }
                        Flow {
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: 5
                                IrrigationZoneChip {
                                    zoneLetter: root.irrigationZoneLetter(index)
                                    coverage: root.irrigationZoneCoverage(index)
                                    activePlots: Math.max(0, Math.min(8, root.activePlotCount - index * 8))
                                    selected: index === root.selectedIrrigationZone
                                    reducedMotion: root.reducedMotion
                                    zoneText: root.tr("zone")
                                    coverageText: root.tr("coverage")
                                    onActivated: {
                                        var first = Math.min(root.activePlotCount - 1, index * 8)
                                        if (first >= 0) root.selectedPlot = first
                                    }
                                }
                            }
                        }
                        Flow {
                            width: parent.width
                            spacing: 7
                            IconButton {
                                compact:true
                                iconSource:Qt.resolvedUrl("assets/ui/water.svg")
                                text:tr("water_all_dry")
                                subText: root.batchWaterUnlocked ? (root.dryFieldCount+" "+tr("dry_fields")) : tr("unlock_watering_tier_3")
                                enabled: root.batchWaterUnlocked && root.dryFieldCount > 0 && root.energy > 0
                                onActivated:root.batchWaterAllDry()
                            }
                            IconButton {
                                compact:true
                                iconSource:Qt.resolvedUrl("assets/tools/basket.svg")
                                text:tr("harvest_all_ready")
                                subText: root.batchHarvestUnlocked ? (root.readyFieldCount+" "+tr("ready_fields")) : tr("unlock_level_10")
                                enabled: root.batchHarvestUnlocked && root.readyFieldCount > 0 && root.energy > 0
                                onActivated:root.batchHarvestAllReady()
                            }
                            IconButton {
                                compact:true
                                iconSource:Qt.resolvedUrl("assets/ui/fertilizer.svg")
                                text:tr("fertilize_zone")+" "+root.irrigationZoneLetter(root.selectedIrrigationZone)
                                subText: root.batchFertilizeUnlocked ? (root.selectedZoneFertilizableCount+" "+tr("fields")) : tr("unlock_level_8")
                                enabled: root.batchFertilizeUnlocked && root.selectedZoneFertilizableCount > 0 && Number(root.inventory.fertilizer||0) > 0
                                onActivated:root.batchFertilizeSelectedZone()
                            }
                        }
                    }
                }

                UiPanel {
                    width: parent.width
                    implicitHeight: progressColumn.implicitHeight + 20
                    Column {
                        id: progressColumn
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 7
                        Row {
                            width:parent.width
                            spacing:8
                            Image { width:24;height:24;source:Qt.resolvedUrl("assets/ui/xp.svg");fillMode:Image.PreserveAspectFit }
                            UiText { text:tr("farm_progress"); font.bold:true }
                            UiText { text:fmt(farmXp)+" / "+fmt(xpNeeded); colorToken:"color.textMuted" }
                        }
                        ProgressBar { width:parent.width; value:farmXp; maximum:xpNeeded }
                        Flow {
                            width:parent.width
                            spacing:7
                            IconButton {
                                compact:true
                                iconSource:Qt.resolvedUrl("assets/ui/expand.svg")
                                text: landStage>=4 ? tr("land_max") : tr("expand_land")
                                subText: landStage>=4 ? (activePlotCount+"/40") : (fmt(FarmData.landCosts[landStage+1])+" "+tr("coins")+" - "+tr("level")+" "+FarmData.landLevels[landStage+1])
                                enabled:landStage<4
                                onActivated:root.expandLand()
                            }
                            UiText { width:Math.max(100,parent.width-250); text:tr("farm_interaction_hint"); colorToken:"color.textMuted"; sizeToken:"metric.font.xs" }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 9
                visible: activeTab === 1

                UiPanel {
                    width:parent.width
                    implicitHeight:animalIntro.implicitHeight+20
                    Column { id:animalIntro;anchors.fill:parent;anchors.margins:10;spacing:4
                        UiText{text:tr("animals_title");font.bold:true;sizeToken:"metric.font.md"}
                        UiText{width:parent.width;text:tr("animals_help");colorToken:"color.textMuted";sizeToken:"metric.font.sm"}
                    }
                }

                Repeater {
                    model: FarmData.animals.length
                    UiPanel {
                        id: animalCard
                        property var animal: FarmData.animals[index]
                        property int animalCount: Number(root.animalCounts[animal.id] || 0)
                        property int mood: Number(root.animalMood[animal.id] === undefined ? 50 : root.animalMood[animal.id])
                        property int displayAnimalCount: Math.min(6, Math.max(0, animalCount))
                        visible: root.farmLevel >= Math.max(1, animal.level - 2) || animalCount > 0
                        width: mainColumn.width
                        implicitHeight: animalColumn.implicitHeight + 20
                        Column {
                            id: animalColumn
                            anchors.fill:parent; anchors.margins:10; spacing:7
                            Row {
                                width:parent.width; spacing:8
                                Image{width:42;height:42;source:Qt.resolvedUrl("assets/animals/"+animal.id+"_idle.svg");fillMode:Image.PreserveAspectFit;cache:true}
                                Column {
                                    width: Math.max(100, parent.width - 52)
                                    UiText {
                                        text: tr(animal.key) + " - " + animalCard.animalCount
                                        font.bold: true
                                    }
                                    UiText {
                                        text: tr("label_happiness") + " " + mood + "% - " + tr(animal.productKey) + " " + Number(inventory[animal.product] || 0)
                                        colorToken: "color.textMuted"
                                        sizeToken: "metric.font.xs"
                                    }
                                }
                            }
                            ProgressBar {width:parent.width;value:mood;maximum:100;fillColor:GameTheme.color(mood>=75?"color.primary":(mood>=40?"color.special":"color.danger"))}
                            Row {
                                width:parent.width; spacing:2
                                Repeater {
                                    id: animalSpriteRepeater
                                    model: animalCard.displayAnimalCount
                                    AnimalSprite {
                                        width: animalCard.displayAnimalCount > 0
                                               ? Math.min(68, (animalColumn.width - Math.max(0, animalCard.displayAnimalCount - 1) * 2) / animalCard.displayAnimalCount)
                                               : 0
                                        height: 56
                                        animalId: animalCard.animal.id
                                        spriteIndex: index
                                        animationPulse: root.animationPulse
                                        reducedMotion: root.reducedMotion || root.visualQuality === "low"
                                        happiness: animalCard.mood
                                        visibleScene: root.activeTab === 1
                                    }
                                }
                            }
                            Flow {width:parent.width;spacing:6
                                IconButton{compact:true;iconSource:Qt.resolvedUrl("assets/animals/"+animal.id+"_happy.svg");text:tr("buy")+" "+tr(animal.key);subText:fmt(animal.buyBase+animalCard.animalCount*animal.buyStep)+" "+tr("coins");enabled:root.farmLevel>=animal.level;onActivated:root.buyAnimal(animal.id)}
                                UiText{width:Math.max(100,parent.width-230);text:tr("label_capacity")+" "+root.totalInBuilding(animal.building)+"/"+root.animalCapacity(animal.id)+" - "+tr(animal.buildingKey)+" "+root.buildingLevelFor(animal.building);colorToken:"color.textMuted";sizeToken:"metric.font.xs"}
                            }
                        }
                    }
                }

                UiPanel {
                    width:parent.width
                    implicitHeight:buildingFlow.implicitHeight+18
                    Flow {id:buildingFlow;anchors.fill:parent;anchors.margins:9;spacing:7
                        IconButton{compact:true;iconSource:Qt.resolvedUrl("assets/buildings/coop.svg");text:tr("building_coop")+" "+coopLevel;subText:farmLevel<5&&coopLevel===0?(tr("msg_unlock_level")+" 5"):(coopLevel>=5?tr("max_level"):(fmt(FarmData.buildingCosts[coopLevel+1])+" "+tr("coins")));enabled:coopLevel<5&&farmLevel>=5;onActivated:upgradeAnimalBuilding("coop")}
                        IconButton{compact:true;iconSource:Qt.resolvedUrl("assets/buildings/barn.svg");text:tr("building_barn")+" "+barnLevel;subText:farmLevel<8&&barnLevel===0?(tr("msg_unlock_level")+" 8"):(barnLevel>=5?tr("max_level"):(fmt(FarmData.barnCosts[barnLevel+1])+" "+tr("coins")));enabled:barnLevel<5&&farmLevel>=8;onActivated:upgradeAnimalBuilding("barn")}
                        IconButton{compact:true;iconSource:Qt.resolvedUrl("assets/buildings/apiary.svg");text:tr("building_apiary")+" "+apiaryLevel;subText:farmLevel<12&&apiaryLevel===0?(tr("msg_unlock_level")+" 12"):(apiaryLevel>=5?tr("max_level"):(fmt(FarmData.apiaryCosts[apiaryLevel+1])+" "+tr("coins")));enabled:apiaryLevel<5&&farmLevel>=12;onActivated:upgradeAnimalBuilding("apiary")}
                        IconButton{compact:true;iconSource:Qt.resolvedUrl("assets/ui/feed.svg");text:tr("buy_feed");subText:"+4 - 12 "+tr("coins");onActivated:root.buyFeed()}
                    }
                }
            }

            Column {
                width:parent.width
                spacing:9
                visible:activeTab===2

                UiPanel {width:parent.width;implicitHeight:marketIntro.implicitHeight+20
                    Column{id:marketIntro;anchors.fill:parent;anchors.margins:10;spacing:5
                        UiText{text:tr("market_title");font.bold:true;sizeToken:"metric.font.md"}
                        UiText{width:parent.width;text:tr("market_help");colorToken:"color.textMuted";sizeToken:"metric.font.sm"}
                        Flow {width:parent.width;spacing:6
                            MarketTrendChip{label:tr("market_vegetables");deltaPercent:root.marketPercentDelta("vegetable");iconSource:root.marketTrendIcon("vegetable")}
                            MarketTrendChip{label:tr("market_fruit");deltaPercent:root.marketPercentDelta("fruit");iconSource:root.marketTrendIcon("fruit")}
                            MarketTrendChip{label:tr("market_grain");deltaPercent:root.marketPercentDelta("grain");iconSource:root.marketTrendIcon("grain")}
                            MarketTrendChip{label:tr("market_animals");deltaPercent:root.marketPercentDelta("animal");iconSource:root.marketTrendIcon("animal")}
                            MarketTrendChip{label:tr("market_processed");deltaPercent:root.marketPercentDelta("processed");iconSource:root.marketTrendIcon("processed")}
                        }
                        Flow {width:parent.width;spacing:7
                            IconButton{compact:true;iconSource:Qt.resolvedUrl("assets/ui/refresh.svg");text:tr("refresh_board")+" "+root.orderRefreshRemaining+"/"+root.orderRefreshBudget;enabled:root.orderRefreshRemaining>0&&root.refreshableOrderCount>0;onActivated:root.refreshOrderBoard()}
                            UiPanel{implicitWidth:Math.max(220,forecastRow.implicitWidth+18);implicitHeight:42
                                Row{id:forecastRow;anchors.centerIn:parent;spacing:7
                                    Image{width:22;height:22;source:root.marketTrendIcon(root.marketForecast().category);fillMode:Image.PreserveAspectFit;cache:true}
                                    Column{spacing:1;UiText{text:tr("market_forecast");sizeToken:"metric.font.xs";colorToken:"color.textMuted"}UiText{text:root.marketForecastText();sizeToken:"metric.font.sm";font.bold:true}}
                                }
                            }
                        }
                    }
                }

                UiPanel {width:parent.width;implicitHeight:sellFlow.implicitHeight+18
                    Flow{id:sellFlow;anchors.fill:parent;anchors.margins:9;spacing:6
                        Repeater {model:FarmData.crops.length
                            IconButton{property var crop:FarmData.crops[index];visible:Number(inventory[crop.id]||0)>0;compact:true;iconSource:Qt.resolvedUrl("assets/products/"+crop.id+".svg");text:tr(crop.key)+" "+fmt(Number(inventory[crop.id]||0));subText:tr("sell_one")+" - "+fmt(Math.max(1,Math.round(root.marketPrice(crop.id)*root.qualityMultiplier(root.bestQualityAvailable(crop.id)))));onActivated:root.sellItem(crop.id)}
                        }
                        Repeater {model:FarmData.animals.length
                            IconButton{property var animal:FarmData.animals[index];visible:Number(inventory[animal.product]||0)>0;compact:true;iconSource:Qt.resolvedUrl("assets/products/"+animal.product+".svg");text:tr(animal.productKey)+" "+fmt(Number(inventory[animal.product]||0));subText:tr("sell_one")+" - "+fmt(root.marketPrice(animal.product));onActivated:root.sellItem(animal.product)}
                        }
                        Repeater {model:FarmData.recipes.length
                            IconButton{property var recipe:FarmData.recipes[index];visible:recipe.output!=="feed"&&Number(inventory[recipe.output]||0)>0;compact:true;iconSource:Qt.resolvedUrl("assets/products/"+recipe.output+".svg");text:tr(recipe.key)+" "+fmt(Number(inventory[recipe.output]||0));subText:tr("sell_one")+" - "+fmt(root.marketPrice(recipe.output));onActivated:root.sellItem(recipe.output)}
                        }
                    }
                }

                Repeater {model:3
                    UiPanel {
                        id: orderCard
                        property int slot: index
                        property var o: (root.orders && slot < root.orders.length && root.orders[slot]) ? root.orders[slot] : null
                        visible: !!root.orderSlotUnlocked(slot)
                        width: mainColumn.width
                        implicitHeight: orderColumn.implicitHeight + 20
                        Column{id:orderColumn;anchors.fill:parent;anchors.margins:10;spacing:7
                            Row{width:parent.width;spacing:8
                                Image{width:30;height:30;source:orderCard.o&&orderCard.o.special?Qt.resolvedUrl("assets/ui/sparkle.svg"):Qt.resolvedUrl("assets/ui/order.svg");fillMode:Image.PreserveAspectFit;cache:true}
                                UiText{text:tr("order_slot")+" "+(orderCard.slot+1)+(orderCard.o&&orderCard.o.special?" - "+tr("special_order"):"");font.bold:true;colorToken:"color.accent"}
                            }
                            UiText{width:parent.width;text:orderCard.o&&orderCard.o.item?(tr(FarmData.itemKey(orderCard.o.item))+" x"+orderCard.o.amount+" - "+orderCard.o.reward+" "+tr("coins")):tr(root.orderStatusKey(orderCard.o));font.bold:true}
                            UiText{visible:!!orderCard.o;text:tr(root.orderStatusKey(orderCard.o));colorToken:(orderCard.o&&orderCard.o.status==="expired")?"color.danger":((orderCard.o&&orderCard.o.status==="completed")?"color.success":"color.textMuted");sizeToken:"metric.font.xs"}
                            Row{visible:!!orderCard.o&&orderCard.o.special&&(orderCard.o.status==="available"||orderCard.o.status==="accepted");spacing:5
                                Image{width:18;height:18;source:Qt.resolvedUrl("assets/ui/clock.svg");fillMode:Image.PreserveAspectFit;cache:true}
                                UiText{text:root.orderExpiryText(orderCard.o);colorToken:"color.warning";sizeToken:"metric.font.xs"}
                            }
                            UiText{visible: !!orderCard.o && orderCard.o.status === "accepted";text:tr("stock")+" "+root.orderStock(orderCard.slot)+"/"+(orderCard.o?orderCard.o.amount:0);colorToken:"color.textMuted"}
                            Flow{width:parent.width;spacing:6
                                IconButton{visible: !!orderCard.o && orderCard.o.status === "available";compact:true;iconSource:Qt.resolvedUrl("assets/ui/order.svg");text:tr("accept_order");onActivated:root.acceptOrder(orderCard.slot)}
                                IconButton{visible: !!orderCard.o && orderCard.o.status === "available";compact:true;iconSource:Qt.resolvedUrl("assets/ui/warning.svg");text:tr("reject_order");onActivated:root.rejectOrder(orderCard.slot)}
                                IconButton{visible: !!orderCard.o && orderCard.o.status === "accepted";compact:true;primary:root.orderStock(orderCard.slot)>=(orderCard.o?orderCard.o.amount:999999);iconSource:Qt.resolvedUrl("assets/ui/market.svg");text:tr("deliver_order");enabled:root.orderStock(orderCard.slot)>=(orderCard.o?orderCard.o.amount:999999);onActivated:root.deliverOrder(orderCard.slot)}
                                IconButton{visible: !!orderCard.o && orderCard.o.status === "accepted";compact:true;iconSource:Qt.resolvedUrl("assets/ui/warning.svg");text:tr("abandon_order");onActivated:root.abandonOrder(orderCard.slot)}
                            }
                        }
                    }
                }
                UiPanel {visible:reputation<20;width:parent.width;implicitHeight:lockedOrderText.implicitHeight+20;UiText{id:lockedOrderText;anchors.fill:parent;anchors.margins:10;text:reputation<5?tr("order_unlock_second"):tr("order_unlock_third");colorToken:"color.textMuted"}}
            }

            Column {
                width:parent.width
                spacing:9
                visible:activeTab===3

                UiPanel {width:parent.width;implicitHeight:upgradeFlow.implicitHeight+18
                    Flow{id:upgradeFlow;anchors.fill:parent;anchors.margins:9;spacing:7
                        IconButton{compact:true;iconSource:Qt.resolvedUrl("assets/tools/watering_"+["basic","copper","steel","gold","master"][wateringTier-1]+".svg");text:tr("watering_can")+" "+wateringTier;subText:wateringTier>=5?tr("max_level"):(tr("coverage")+" "+FarmData.wateringCounts[wateringTier-1]+" -> "+FarmData.wateringCounts[wateringTier]+" - "+fmt(FarmData.toolCosts[wateringTier])+" "+tr("coins"));enabled:wateringTier<5;onActivated:root.upgradeWatering()}
                        IconButton{compact:true;iconSource:Qt.resolvedUrl("assets/tools/sprinkler.svg");text:tr("sprinkler")+" "+sprinklerLevel;subText:farmLevel<4&&sprinklerLevel===0?(tr("msg_unlock_level")+" 4"):(sprinklerLevel>=5?tr("max_level"):(tr("coverage")+" "+FarmData.sprinklerCoverage[sprinklerLevel+1]+" - "+fmt(FarmData.sprinklerCosts[sprinklerLevel+1])+" "+tr("coins")));enabled:sprinklerLevel<5&&farmLevel>=4;onActivated:root.upgradeSprinkler()}
                        IconButton{compact:true;iconSource:Qt.resolvedUrl("assets/field/greenhouse_overlay.svg");text:tr("greenhouse")+" "+greenhouseLevel;subText:farmLevel<10&&greenhouseLevel===0?(tr("msg_unlock_level")+" 10"):(greenhouseLevel>=5?tr("max_level"):(tr("offseason_slots")+" "+FarmData.greenhouseCoverage[greenhouseLevel+1]+" - "+fmt(FarmData.greenhouseCosts[greenhouseLevel+1])+" "+tr("coins")));enabled:greenhouseLevel<5&&farmLevel>=10;onActivated:root.upgradeGreenhouse()}
                        IconButton{compact:true;iconSource:Qt.resolvedUrl("assets/tools/fertilizer_bag.svg");text:tr("buy_fertilizer");subText:"+2 - 18 "+tr("coins");onActivated:root.buyFertilizer()}
                    }
                }

                Repeater {model:FarmData.processingBuildings.length
                    UiPanel {property var building:FarmData.processingBuildings[index];width:mainColumn.width;visible: farmLevel >= building.level - 1 || !!processingBuilt[building.id];implicitHeight:buildingRow.implicitHeight+20
                        Flow{id:buildingRow;anchors.fill:parent;anchors.margins:10;spacing:10
                            Image{width:58;height:58;source:Qt.resolvedUrl("assets/buildings/"+building.id+".svg");fillMode:Image.PreserveAspectFit;cache:true}
                            Column {
                                width: root.compactLayout ? Math.max(120, buildingRow.width - 78) : Math.max(180, Math.min(460, buildingRow.width - 310))
                                spacing: 3
                                UiText {
                                    text: tr(building.key)
                                    font.bold: true
                                }
                                UiText {
                                    width: parent.width
                                    text: processingBuilt[building.id] ? tr("building_operational") : (tr("unlock_level") + " " + building.level)
                                    colorToken: "color.textMuted"
                                    sizeToken: "metric.font.xs"
                                }
                            }
                            IconButton{width:root.compactLayout?buildingRow.width:implicitWidth;visible:!processingBuilt[building.id];compact:true;iconSource:Qt.resolvedUrl("assets/ui/workshop.svg");text:tr("build");subText:fmt(building.cost)+" "+tr("coins");enabled:farmLevel>=building.level;onActivated:root.buildProcessing(building.id)}
                        }
                    }
                }

                Repeater {model:FarmData.recipes.length
                    UiPanel {property var recipe:FarmData.recipes[index];visible: !!processingBuilt[recipe.building] || farmLevel >= recipe.level; width:mainColumn.width;implicitHeight:recipeRow.implicitHeight+20
                        Flow{id:recipeRow;anchors.fill:parent;anchors.margins:10;spacing:9
                            Image{width:48;height:48;source:Qt.resolvedUrl("assets/products/"+recipe.output+".svg");fillMode:Image.PreserveAspectFit;cache:true}
                            Column {
                                width: root.compactLayout ? Math.max(120, recipeRow.width - 68) : Math.max(180, Math.min(460, recipeRow.width - 280))
                                spacing: 2
                                UiText {
                                    text: tr(recipe.key)
                                    font.bold: true
                                }
                                UiText {
                                    width: parent.width
                                    text: root.recipeInputText(recipe) + " -> " + recipe.amount + " " + tr(recipe.key) + " - " + recipe.energy + " " + tr("energy")
                                    colorToken: "color.textMuted"
                                    sizeToken: "metric.font.xs"
                                }
                            }
                            IconButton{width:root.compactLayout?recipeRow.width:implicitWidth;compact:true;iconSource:Qt.resolvedUrl("assets/ui/workshop.svg");text:tr("craft");enabled:root.canCraft(recipe);onActivated:root.craft(recipe)}
                        }
                    }
                }
            }

            Column {
                width:parent.width
                spacing:9
                visible:activeTab===4

                UiPanel {width:parent.width;implicitHeight:journalIntro.implicitHeight+20
                    Column {
                        id: journalIntro
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4
                        UiText {
                            text: tr("journal_title")
                            font.bold: true
                            sizeToken: "metric.font.md"
                        }
                        UiText {
                            width: parent.width
                            text: tr("journal_help")
                            colorToken: "color.textMuted"
                        }
                    }
                }

                UiPanel {width:parent.width;implicitHeight:statsFlow.implicitHeight+18
                    Flow{id:statsFlow;anchors.fill:parent;anchors.margins:9;spacing:6
                        HudChip{label:tr("stat_planted");value:fmt(Number(lifetimeStats.planted||0))}
                        HudChip{label:tr("stat_harvested");value:fmt(Number(lifetimeStats.harvested||0))}
                        HudChip{label:tr("stat_sold");value:fmt(Number(lifetimeStats.sold||0))}
                        HudChip{label:tr("stat_orders");value:fmt(Number(lifetimeStats.orders||0))}
                        HudChip{label:tr("stat_crafted");value:fmt(Number(lifetimeStats.crafted||0))}
                    }
                }

                UiPanel {width:parent.width;implicitHeight:orderHistoryColumn.implicitHeight+18
                    Column{id:orderHistoryColumn;anchors.fill:parent;anchors.margins:9;spacing:7
                        UiText{text:tr("order_history");font.bold:true;sizeToken:"metric.font.md"}
                        Flow{width:parent.width;spacing:6
                            HudChip{label:tr("order_history_completed");value:fmt(Number(root.lifetimeStats.orders||0));valueColorToken:"color.success"}
                            HudChip{label:tr("order_history_rejected");value:fmt(Number(root.lifetimeStats.ordersRejected||0));valueColorToken:"color.textMuted"}
                            HudChip{label:tr("order_history_abandoned");value:fmt(Number(root.lifetimeStats.ordersAbandoned||0));valueColorToken:"color.warning"}
                            HudChip{label:tr("highest_reward");value:fmt(root.highestOrderReward)+" "+tr("coins");valueColorToken:"color.special"}
                        }
                        UiText{visible:root.orderHistory.length>0;text:tr("recent_orders");font.bold:true;colorToken:"color.textMuted";sizeToken:"metric.font.sm"}
                        Repeater{model:Math.min(8,root.orderHistory.length)
                            UiPanel{property var entry:root.orderHistory[index];width:orderHistoryColumn.width;implicitHeight:historyRow.implicitHeight+12;surfaceToken:"surface.panel"
                                Flow{id:historyRow;anchors.fill:parent;anchors.margins:6;spacing:7
                                    Image{width:24;height:24;source:entry.special?Qt.resolvedUrl("assets/ui/sparkle.svg"):Qt.resolvedUrl("assets/ui/order.svg");fillMode:Image.PreserveAspectFit;cache:true}
                                    UiText{text:tr(FarmData.itemKey(entry.item))+" x"+entry.amount;sizeToken:"metric.font.sm"}
                                    UiText{text:tr("order_status_"+entry.outcome);colorToken:entry.outcome==="completed"?"color.success":"color.textMuted";sizeToken:"metric.font.xs"}
                                    UiText{text:tr("day")+" "+entry.day+" - "+entry.reward+" "+tr("coins");colorToken:"color.textMuted";sizeToken:"metric.font.xs"}
                                }
                            }
                        }
                    }
                }

                UiPanel {width:parent.width;implicitHeight:masteryFlow.implicitHeight+18
                    Flow{id:masteryFlow;anchors.fill:parent;anchors.margins:9;spacing:7
                        Repeater{model:FarmData.crops.length
                            IconButton{property var crop:FarmData.crops[index];compact:true;iconSource:Qt.resolvedUrl("assets/crops/"+crop.id+".svg");text:tr(crop.key);subText:tr("mastery_tier_"+root.masteryTier(crop.id))+" - "+fmt(Number(root.cropHarvests[crop.id]||0));enabled:false}
                        }
                    }
                }

                Repeater {model:FarmData.projects.length
                    UiPanel {property var project:FarmData.projects[index];property int phase:Number(root.projectLevels[project.id]||0);property var cost:root.projectCost(project,Math.min(5,phase+1));width:mainColumn.width;implicitHeight:projectRow.implicitHeight+20
                        Flow{id:projectRow;anchors.fill:parent;anchors.margins:10;spacing:10
                            Image{width:58;height:58;source:Qt.resolvedUrl("assets/projects/"+project.icon+".svg");fillMode:Image.PreserveAspectFit;cache:true}
                            Column {
                                width: Math.max(120, Math.min(360, projectRow.width - 78))
                                spacing: 3
                                UiText {
                                    text: tr(project.key) + " - " + tr("phase") + " " + phase + "/5"
                                    font.bold: true
                                }
                                UiText {
                                    width: parent.width
                                    text: phase >= 5 ? tr("project_complete") : (fmt(cost.coins) + " " + tr("coins") + " + " + fmt(cost.item) + " " + tr(project.itemKey) + " - " + tr("reputation") + " " + project.unlockRep)
                                    colorToken: "color.textMuted"
                                    sizeToken: "metric.font.xs"
                                }
                            }
                            IconButton{compact:true;visible:phase<5;iconSource:Qt.resolvedUrl("assets/ui/expand.svg");text:tr("contribute");enabled:reputation>=project.unlockRep&&coins>=cost.coins&&Number(inventory[project.item]||0)>=cost.item;onActivated:root.advanceProject(project)}
                        }
                    }
                }
            }

            UiPanel {
                width:parent.width
                implicitHeight:messageText.implicitHeight+18
                UiText {
                    id:messageText
                    anchors.fill:parent
                    anchors.margins:9
                    text:(message.length>0?message:tr("status_ready"))+(showHints?" - "+tr("global_controls_hint"):"")
                    horizontalAlignment:Text.AlignHCenter
                    colorToken:"color.textMuted"
                    sizeToken:"metric.font.xs"
                }
            }
        }
    }

    AmbientWeatherLayer {
        id: ambientWeather
        z: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topNavigation.visible ? topNavigation.bottom : stickyHud.bottom
        anchors.bottom: farmActionBar.visible ? farmActionBar.top : (bottomNavigation.visible ? bottomNavigation.top : parent.bottom)
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        reducedMotion: root.reducedMotion
        ambientEnabled: root.activeTab === 0 && root.visible && !root.nextDayTransitionRunning
        weatherKey: root.weather
    }

    VisualFeedbackLayer {
        id: visualFeedback
        z: 940
        anchors.fill: parent
        reducedMotion: root.reducedMotion
        dayLabel: root.tr("day_transition")
        onCommitRequested: {
            try {
                if (root.commitNextDay())
                    visualFeedback.commitApplied(root.seasonIndex, root.weather, root.tr(root.seasonKey), root.tr("weather_" + root.weather))
                else
                    visualFeedback.forceFinish()
            } catch (e) {
                console.warn("Harvest Pocket: day commit failed; recovering transition:", e)
                visualFeedback.forceFinish()
            }
        }
        onTransitionStarted: {
            root.nextDayTransitionRunning = true
            dayTransitionWatchdog.restart()
            root.stopAmbientAudio()
            root.forceActiveFocus()
        }
        onTransitionFinished: {
            dayTransitionWatchdog.stop()
            root.nextDayTransitionRunning = false
            root.forceActiveFocus()
            Qt.callLater(root.syncAmbientAudio)
        }
    }

    Timer {
        id: dayTransitionWatchdog
        interval: root.reducedMotion ? 2200 : 5000
        repeat: false
        onTriggered: {
            if (!root.nextDayTransitionRunning) return
            console.warn("Harvest Pocket: day transition watchdog recovered a stalled transition")
            visualFeedback.forceFinish()
        }
    }

    RewardFeedbackLayer {
        id: rewardLayer
        z: 850
        anchors.fill: parent
        reducedMotion: root.reducedMotion
    }

    UiPanel {
        id: nextDayWarningBanner
        z: 920
        anchors.top: parent.top
        anchors.topMargin: root.contentPadding
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - root.contentPadding * 2, 560)
        implicitHeight: warningBannerRow.implicitHeight + 18
        visible: root.warningEdgeOpacity > 0.001
        opacity: root.warningEdgeOpacity
        border.width: 2
        border.color: GameTheme.color("color.danger")
        Row {
            id: warningBannerRow
            anchors.fill: parent
            anchors.margins: 9
            spacing: 9
            Image {
                width: 30; height: 30
                anchors.verticalCenter: parent.verticalCenter
                source: Qt.resolvedUrl("assets/ui/warning.svg")
                fillMode: Image.PreserveAspectFit
                cache: true
            }
            UiText {
                width: Math.max(120, warningBannerRow.width - 48)
                text: tr("msg_next_day_warning")
                font.bold: true
                colorToken: "color.danger"
                sizeToken: "metric.font.sm"
            }
        }
    }

    // Lightweight danger edge: nested borders simulate an inward shadow without blur/shaders.
    Item {
        anchors.fill: parent
        z: 900
        visible: root.warningEdgeOpacity > 0.001
        opacity: root.warningEdgeOpacity
        enabled: false
        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 5; border.color: GameTheme.color("color.danger"); opacity: 0.86 }
        Rectangle { anchors.fill: parent; anchors.margins: 6; color: "transparent"; border.width: 7; border.color: GameTheme.color("color.danger"); opacity: 0.42 }
        Rectangle { anchors.fill: parent; anchors.margins: 16; color: "transparent"; border.width: 10; border.color: GameTheme.color("color.danger"); opacity: 0.18 }
    }

    Connections {
        target: typeof GameI18n !== "undefined" ? GameI18n : null
        ignoreUnknownSignals: true
        function onChanged() { root.i18nRevision++; root.message = "" }
        function onLanguageChanged() { root.i18nRevision++; root.message = "" }
    }

    Connections {
        target: typeof GameInput !== "undefined" ? GameInput : null
        ignoreUnknownSignals: true
        function onActionPressed(action, value) {
            if (root.inputLocked || root.activeTab !== 0) return
            if (action === "move_left") root.moveSelection(-1,0)
            else if (action === "move_right") root.moveSelection(1,0)
            else if (action === "up") root.moveSelection(0,-1)
            else if (action === "down") root.moveSelection(0,1)
            else if (action === "fire") root.interact(root.selectedPlot)
            else if (action === "next") root.cycleSeedSelection(1)
        }
    }

    // Root lifecycle methods above are the primary host contract. These
    // signals are compatibility fallbacks for hosts that also expose them.
    Connections {
        target: typeof Lifecycle !== "undefined" ? Lifecycle : null
        ignoreUnknownSignals: true
        function onSaveRequested() { if (root.initializationDone && root.saveDirty) root.writeSave(true) }
        function onBackgrounded() { if (root.initializationDone && root.saveDirty) root.writeSave(true); try { if (typeof GameAudio !== "undefined" && typeof GameAudio.pauseAll === "function") GameAudio.pauseAll() } catch (e) {} }
    }


    Component.onCompleted: {
        root.inventory = root.defaultInventory()
        root.qualityInventory = root.defaultQualityInventory()
        root.cropHarvests = root.defaultCropHarvests()
        root.animalCounts = root.defaultAnimalCounts()
        root.animalMood = root.defaultAnimalMood()
        root.processingBuilt = root.defaultProcessingBuilt()
        root.projectLevels = root.defaultProjectLevels()
        root.lifetimeStats = root.defaultLifetimeStats()
        Qt.callLater(root.preloadAudio)
        Qt.callLater(root.ensureInitialized)
    }

    onActiveTabChanged: Qt.callLater(root.syncAmbientAudio)
    onWeatherChanged: Qt.callLater(root.syncAmbientAudio)
    onVisibleChanged: Qt.callLater(root.syncAmbientAudio)
    onGameLoadedChanged: Qt.callLater(root.syncAmbientAudio)

    Component.onDestruction: {
        root.stopAmbientAudio()
        if (root.gameLoaded && root.saveDirty) root.writeSave(true)
    }
}
