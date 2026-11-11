import QtQuick
import "js/BoardLogic.js" as BoardLogic
import "js/LevelLogic.js" as LevelLogic
import "components" as Components

FocusScope {
    id: root
    focus: true

    readonly property string gameId: "gem_cascade"
    readonly property int cols: 8
    readonly property int rows: 8
    readonly property int gemTypes: 6
    readonly property string version: "6.7.0"
    readonly property var gemFiles: ["ruby.svg", "sapphire.svg", "emerald.svg", "sunstone.svg", "amethyst.svg", "pearl.svg"]
    // Gameplay-semantic colors stay stable across themes; shape + symbol also distinguish every gem.
    readonly property var gemColors: ["#e05252", "#4b8dec", "#45ad6f", "#e8b53f", "#9b6bd3", "#e77f45"]

    property var board: []
    property var specials: []
    property var ice: []
    property var collected: [0, 0, 0, 0, 0, 0]
    property int selected: -1
    property int cursor: 0
    property int score: 0
    property int level: 1
    property int unlockedLevel: 1
    property int movesLeft: 0
    property int targetScore: 0
    property int targetType: 0
    property int targetCount: 0
    property int targetIce: 0
    property int levelInitialIce: 0
    property int targetBombs: 0
    property int bombsCreated: 0
    property int targetCascade: 0
    property int bestCascadeThisLevel: 0
    property int cascadeDepth: 0
    property int bestCombo: 0
    property int lastEarnedStars: 0
    property var starsByLevel: ({})
    property var bestScores: ({})
    property var boosters: ({ hammer: 3, shuffle: 2, cross: 1, extra: 2 })
    property var statistics: ({ levelsPlayed: 0, levelsCleared: 0, gemsCleared: 0, specialsCreated: 0, bestCascade: 0 })
    property bool tutorialCompleted: false
    property string boosterMode: ""
    property string message: ""
    property string gameState: "Initializing"
    property string stateBeforePause: "Idle"
    property bool initialized: false
    property bool dirty: false
    property var lastStableSnapshot: null
    property int languageRevision: 0
    property int themeRevision: 0

    property int pendingA: -1
    property int pendingB: -1
    property bool pendingReverse: false
    property bool pendingLegal: false
    property var pendingComboPlan: null
    property var currentPlan: null
    property var clearingCells: []
    property real clearProgress: 0
    property bool clearAnimating: false
    property var fallDistance: []
    property var spawnedFlags: []
    property int activeFallMs: 300
    property real swapProgress: 0
    property bool swapAnimating: false
    property int swapA: -1
    property int swapB: -1
    property real fallProgress: 1
    property bool fallAnimating: false
    property real shufflePulse: 0
    property var hintCells: []

    readonly property bool reducedMotion: settingBool("reducedMotion", false)
    readonly property bool showHints: settingBool("showHints", true)
    property bool vibrationEnabled: settingBool("haptics", true)
    property bool soundEnabled: settingBool("sound", true)
    property real impactPhase: 1.0
    property real impactStrength: 0.0
    property string impactColorToken: "color.accent"
    readonly property real boardShakeX: reducedMotion ? 0 : Math.sin(impactPhase * Math.PI * 8.0) * impactStrength * 6.0 * (1.0 - impactPhase)
    readonly property real boardShakeY: reducedMotion ? 0 : Math.sin(impactPhase * Math.PI * 10.0 + 0.8) * impactStrength * 4.0 * (1.0 - impactPhase)
    readonly property real impactFlashOpacity: reducedMotion ? 0 : Math.max(0, impactStrength * 0.16 * (1.0 - impactPhase * 1.35))
    readonly property int swapMs: reducedMotion ? 1 : 150
    readonly property int clearMs: reducedMotion ? 1 : 220
    readonly property int fallMs: reducedMotion ? 1 : 300
    readonly property int invalidHoldMs: reducedMotion ? 1 : 65
    readonly property bool inputReady: initialized && (gameState === "Idle" || gameState === "Selecting")
    readonly property bool levelComplete: gameState === "LevelComplete"
    readonly property bool gameOver: gameState === "LevelFailed"
    readonly property real cascadeMultiplier: cascadeDepth <= 1 ? 1.0 : (cascadeDepth === 2 ? 1.25 : cascadeDepth === 3 ? 1.5 : cascadeDepth === 4 ? 1.75 : 2.0)

    function tr(key, fallback) {
        var touch = languageRevision
        try {
            if (typeof GameI18n !== "undefined") {
                var translated = GameI18n.text(key, fallback)
                if (translated !== undefined && translated !== null && String(translated).length > 0) return String(translated)
            }
        } catch (e) {}
        return fallback
    }
    function fallbackColor(token) {
        var map = {
            "color.background":"#10141c", "color.surfaceRaised":"#1b2230",
            "color.surfaceInteractive":"#252e3e", "color.border":"#3b465a",
            "color.text":"#f2f5f8", "color.textMuted":"#9ba8ba",
            "color.primary":"#6c8cff", "color.primaryHover":"#88a2ff",
            "color.accent":"#9d7cff", "color.info":"#58a6ff"
        }
        return map[token] !== undefined ? map[token] : "#f2f5f8"
    }
    function fallbackNumber(token) {
        var map = {
            "alias.page.padding":16, "alias.page.gap":10, "alias.gameTile.gap":4,
            "alias.card.padding":12, "alias.card.gap":8, "alias.card.radius":12, "alias.card.borderWidth":1,
            "alias.button.gap":8, "alias.button.height":44, "alias.button.touchTarget":44,
            "alias.button.paddingX":14, "alias.button.hoverScale":1.02, "alias.button.pressedScale":0.98,
            "metric.control.lg":96, "metric.control.sm":36, "metric.control.xs":28,
            "metric.icon.md":24, "metric.space.xs":8, "metric.space.xxxs":2,
            "metric.font.xs":12, "metric.font.sm":14, "metric.font.md":16, "metric.font.lg":22
        }
        return map[token] !== undefined ? map[token] : 8
    }
    function themeColor(token) {
        var touch = themeRevision
        try {
            if (typeof GameTheme !== "undefined") {
                var v = GameTheme.color(token)
                if (v !== undefined && v !== null && String(v).length > 0) return v
            }
        } catch (e) {}
        return fallbackColor(token)
    }
    function themeNumber(token) {
        var touch = themeRevision
        try {
            if (typeof GameTheme !== "undefined") {
                var n = Number(GameTheme.number(token))
                if (isFinite(n) && n > 0) return n
            }
        } catch (e) {}
        return fallbackNumber(token)
    }
    function settingBool(key, fallback) {
        try {
            if (typeof GameSettings !== "undefined") {
                var v = GameSettings.value(key, fallback)
                if (v !== undefined && v !== null) {
                    if (typeof v === "string") {
                        var t = v.toLowerCase().trim()
                        if (t === "false" || t === "0" || t === "off" || t === "no") return false
                        if (t === "true" || t === "1" || t === "on" || t === "yes") return true
                    }
                    if (typeof v === "number") return v !== 0
                    return Boolean(v)
                }
            }
        } catch (e) {}
        return Boolean(fallback)
    }
    function idx(x, y) { return y * cols + x }
    function xOf(i) { return i % cols }
    function yOf(i) { return Math.floor(i / cols) }
    function randomInt(lo, hi) {
        try {
            if (typeof GameRandom !== "undefined") return Number(GameRandom.nextInt(lo, hi))
        } catch (e) {}
        return lo + Math.floor(Math.random() * Math.max(1, hi - lo + 1))
    }
    function randomFn(lo, hi) { return randomInt(lo, hi) }
    function arrayHas(list, value) { for (var i = 0; i < list.length; ++i) if (Number(list[i]) === value) return true; return false }
    function keysAsNumbers(obj) { var a = []; for (var k in obj) if (Object.prototype.hasOwnProperty.call(obj, k)) a.push(Number(k)); return a }
    function copyObject(o) { return JSON.parse(JSON.stringify(o)) }
    function normalizedIntArray(v, expected, fallback) {
        var out = []
        if (!v || v.length === undefined) return fallback.slice()
        for (var i = 0; i < expected; ++i) out.push(Number(v[i] === undefined ? fallback[i] : v[i]))
        return out
    }
    function haptic(kind) {
        if (!vibrationEnabled) return
        try {
            if (typeof Haptics === "undefined") return
            if (kind === "heavy") Haptics.heavy()
            else if (kind === "medium") Haptics.medium()
            else Haptics.light()
        } catch (e) {}
    }
    function playSfx(name) {
        if (!soundEnabled) return
        try {
            if (audioLoader.status === Loader.Ready && audioLoader.item) audioLoader.item.play(name)
        } catch (e) {}
    }
    function toggleVibrationPreference() {
        vibrationEnabled = !vibrationEnabled
        message = vibrationEnabled ? tr("vibration_on", "Vibration on") : tr("vibration_off", "Vibration off")
        if (vibrationEnabled) haptic("light")
        markDirty(true)
    }
    function toggleSoundPreference() {
        soundEnabled = !soundEnabled
        message = soundEnabled ? tr("sound_on", "Sound on") : tr("sound_off", "Sound off")
        if (audioLoader.status === Loader.Ready && audioLoader.item) audioLoader.item.enabled = soundEnabled
        if (soundEnabled) playSfx("button")
        markDirty(true)
    }
    function triggerImpact(strength, soundKind) {
        if (reducedMotion) {
            if (strength >= 0.70) haptic("heavy")
            else if (strength >= 0.30) haptic("medium")
            return
        }
        impactStrength = Math.max(0, Math.min(1, Number(strength || 0)))
        impactColorToken = soundKind === "line" ? "color.info" : (soundKind === "prism" ? "color.primary" : "color.accent")
        impactPhase = 0
        impactAnimation.restart()
        if (impactStrength >= 0.70) haptic("heavy")
        else if (impactStrength >= 0.30) haptic("medium")
    }
    function hasAdjacentSpecial(p) {
        var x = xOf(p), y = yOf(p)
        if (x > 0 && Number(specials[p - 1] || 0) > BoardLogic.NORMAL) return true
        if (x + 1 < cols && Number(specials[p + 1] || 0) > BoardLogic.NORMAL) return true
        if (y > 0 && Number(specials[p - cols] || 0) > BoardLogic.NORMAL) return true
        if (y + 1 < rows && Number(specials[p + cols] || 0) > BoardLogic.NORMAL) return true
        return false
    }
    function planSound(plan) {
        if (!plan) return "match"
        var label = String(plan.label || "")
        if (label.indexOf("prism") >= 0) return "prism"
        if (label.indexOf("nova") >= 0) return "nova"
        if (label.indexOf("bomb") >= 0) return "bomb"
        if (label.indexOf("line") >= 0) return "line"
        if (plan.create) {
            for (var k in plan.create) if (Object.prototype.hasOwnProperty.call(plan.create, k)) {
                var kind = Number(plan.create[k].kind)
                if (kind === BoardLogic.NOVA) return "nova"
                if (kind === BoardLogic.PRISM) return "prism"
                if (kind === BoardLogic.BOMB) return "bomb"
                if (kind === BoardLogic.ROW || kind === BoardLogic.COLUMN) return "line"
            }
        }
        if (cascadeDepth >= 3) return "cascade3"
        if (cascadeDepth >= 2) return "cascade2"
        return "match"
    }
    function activateSpecialCell(p) {
        var sp = Number(specials[p] || 0)
        if (!inputReady || sp <= BoardLogic.NORMAL || movesLeft <= 0) return
        var plan = BoardLogic.singleSpecialPlan(board, specials, p, cols, rows)
        if (!plan) return
        selected = -1
        hintCells = []
        movesLeft = Math.max(0, movesLeft - 1)
        markDirty(false)
        cascadeDepth = 1
        message = tr("special_activated", "Special activated")
        beginClear(plan)
    }
    function serviceContextReady() {
        if (typeof GameI18n === "undefined" || typeof GameSave === "undefined" || typeof GameRandom === "undefined") return false
        try {
            if (GameI18n.ready !== undefined && !Boolean(GameI18n.ready)) return false
            if (GameI18n.gameId !== undefined && String(GameI18n.gameId) !== gameId) return false
        } catch (e) { return false }
        try {
            if (GameSave.ready !== undefined && !Boolean(GameSave.ready)) return false
            if (GameSave.gameId !== undefined && String(GameSave.gameId) !== gameId) return false
        } catch (e2) { return false }
        return true
    }

    function iceRemaining() {
        var n = 0
        for (var i = 0; i < ice.length; ++i) if (Number(ice[i]) > 0) n += Number(ice[i])
        return n
    }
    function iceCleared() { return Math.max(0, levelInitialIce - iceRemaining()) }
    function targetCollected() { return Number(collected[targetType] || 0) }
    function objectiveComplete() {
        return score >= targetScore
            && targetCollected() >= targetCount
            && (targetIce <= 0 || iceCleared() >= targetIce)
            && (targetBombs <= 0 || bombsCreated >= targetBombs)
            && (targetCascade <= 0 || bestCascadeThisLevel >= targetCascade)
    }
    function starsText(n) {
        var out = ""
        return String(Math.max(0, Math.min(3, Number(n || 0)))) + "/3"
    }
    function objectiveText() {
        var parts = [tr("objective_score", "Score %1/%2").replace("%1", score).replace("%2", targetScore),
                     tr("objective_collect", "Collect %1/%2").replace("%1", targetCollected()).replace("%2", targetCount)]
        if (targetIce > 0) parts.push(tr("objective_ice", "Ice %1/%2").replace("%1", iceCleared()).replace("%2", targetIce))
        if (targetBombs > 0) parts.push(tr("objective_bombs", "Bombs %1/%2").replace("%1", bombsCreated).replace("%2", targetBombs))
        if (targetCascade > 0) parts.push(tr("objective_cascade", "Cascade %1/%2").replace("%1", bestCascadeThisLevel).replace("%2", targetCascade))
        return parts.join("  -  ")
    }

    function decisionContext() {
        return {
            targetType: targetType,
            targetCount: targetCount,
            collectedCount: targetCollected(),
            targetBombs: targetBombs,
            bombsCreated: bombsCreated,
            targetCascade: targetCascade,
            bestCascade: bestCascadeThisLevel,
            movesLeft: movesLeft,
            ice: ice
        }
    }

    function makeFreshBoard() {
        var generated = BoardLogic.generateBoard(cols, rows, gemTypes, randomFn)
        if (!generated) throw new Error("Gem Cascade: unable to generate a playable board")
        board = generated.board
        specials = generated.specials
        ice = []
        for (var i = 0; i < cols * rows; ++i) ice.push(0)
    }
    function seedIce(layers) {
        var a = ice.slice(), placed = 0, guard = 0
        while (placed < layers && guard++ < 1200) {
            var p = randomInt(cols, cols * rows - cols - 1)
            if (a[p] < 2) { a[p] += 1; ++placed }
        }
        ice = a
        levelInitialIce = layers
    }
    function configureLevel(n) {
        var cfg = LevelLogic.config(n)
        movesLeft = cfg.moves
        targetScore = cfg.targetScore
        targetType = cfg.collectType
        targetCount = cfg.collectCount
        targetIce = cfg.iceLayers
        targetBombs = cfg.bombTarget
        targetCascade = cfg.cascadeTarget
    }
    function startLevel(n, preserveCampaign) {
        level = Math.max(1, Number(n || 1))
        configureLevel(level)
        score = 0
        collected = [0, 0, 0, 0, 0, 0]
        bombsCreated = 0
        bestCascadeThisLevel = 0
        lastEarnedStars = 0
        cascadeDepth = 0
        selected = -1
        cursor = 0
        boosterMode = ""
        hintCells = []
        message = ""
        makeFreshBoard()
        seedIce(targetIce)
        if (!preserveCampaign) statistics.levelsPlayed = Number(statistics.levelsPlayed || 0) + 1
        gameState = "Idle"
        markDirty(true)
        if (!tutorialCompleted && level === 1) { tutorial.page = 0; tutorial.open = true }
    }

    function requestTap(i) {
        forceActiveFocus()
        if (!inputReady || i < 0 || i >= board.length) return
        cursor = i
        hintCells = []
        if (boosterMode === "hammer") { useTargetBooster("hammer", i); return }
        if (boosterMode === "cross") { useTargetBooster("cross", i); return }
        var tappedSpecial = Number(specials[i] || 0) > BoardLogic.NORMAL
        if (selected < 0) {
            if (tappedSpecial && !hasAdjacentSpecial(i)) { activateSpecialCell(i); return }
            selected = i; gameState = "Selecting"; haptic("light"); playSfx("select")
            if (tappedSpecial) message = tr("special_tap_hint", "Tap again to activate, or tap a neighboring special to combine.")
            return
        }
        var selectedSpecial = Number(specials[selected] || 0) > BoardLogic.NORMAL
        if (selected === i) {
            if (selectedSpecial) { activateSpecialCell(i); return }
            selected = -1; gameState = "Idle"; return
        }
        if (selectedSpecial && tappedSpecial && BoardLogic.adjacent(selected, i, cols)) {
            var aSpecial = selected
            selected = -1
            requestSwap(aSpecial, i)
            return
        }
        if (!BoardLogic.adjacent(selected, i, cols)) {
            if (tappedSpecial && !hasAdjacentSpecial(i)) { selected = -1; gameState = "Idle"; activateSpecialCell(i); return }
            selected = i; gameState = "Selecting"
            if (tappedSpecial) message = tr("special_tap_hint", "Tap again to activate, or tap a neighboring special to combine.")
            return
        }
        var a = selected
        selected = -1
        requestSwap(a, i)
    }
    function requestSwipe(i, dx, dy) {
        forceActiveFocus()
        if (!inputReady) return
        var tx = xOf(i), ty = yOf(i)
        if (Math.abs(dx) >= Math.abs(dy)) tx += dx > 0 ? 1 : -1
        else ty += dy > 0 ? 1 : -1
        if (tx < 0 || tx >= cols || ty < 0 || ty >= rows) return
        selected = -1
        requestSwap(i, idx(tx, ty))
    }
    function requestSwap(a, b) {
        if (!inputReady || !BoardLogic.adjacent(a, b, cols)) return
        pendingA = a; pendingB = b; pendingReverse = false
        pendingLegal = BoardLogic.isLegalSwap(board, specials, a, b, cols, rows)
        pendingComboPlan = BoardLogic.comboPlan(board, specials, a, b, cols, rows)
        gameState = "Swapping"
        playSfx("swap")
        beginSwapAnimation(a, b, "finishForwardSwap")
    }
    function beginSwapAnimation(a, b, action) {
        swapA = a; swapB = b
        swapAnimating = false; swapProgress = 0
        swapAnimating = true; swapProgress = 1
        phaseTimer.action = action; phaseTimer.interval = swapMs; phaseTimer.restart()
    }
    function commitSwap(a, b) {
        var swapped = BoardLogic.swapPair(board, specials, a, b)
        board = swapped.board; specials = swapped.specials
    }
    function finishForwardSwap() {
        swapAnimating = false; swapProgress = 0
        commitSwap(pendingA, pendingB)
        if (pendingComboPlan !== null) {
            movesLeft = Math.max(0, movesLeft - 1)
            markDirty(false)
            cascadeDepth = 1
            message = tr("special_combo", "Special combo!")
            playSfx("combo")
            beginClear(pendingComboPlan)
            return
        }
        var runs = BoardLogic.findRuns(board, cols, rows)
        if (!pendingLegal) {
            message = tr("no_match", "That swap does not create a match")
            pendingReverse = true
            haptic("light")
            playSfx("invalid")
            phaseTimer.action = "beginReverseSwap"; phaseTimer.interval = invalidHoldMs; phaseTimer.restart()
            return
        }
        movesLeft = Math.max(0, movesLeft - 1)
        markDirty(false)
        cascadeDepth = 1
        haptic("medium")
        beginClear(BoardLogic.buildMatchPlan(board, specials, cols, rows, pendingA, pendingB))
    }
    function beginReverseSwap() {
        if (!pendingReverse || pendingA < 0 || pendingB < 0) { gameState = "Idle"; return }
        beginSwapAnimation(pendingA, pendingB, "finishReverseSwap")
    }
    function finishReverseSwap() {
        swapAnimating = false; swapProgress = 0
        commitSwap(pendingA, pendingB)
        pendingA = -1; pendingB = -1; pendingReverse = false; pendingLegal = false
        gameState = "Idle"
    }

    function beginClear(plan) {
        currentPlan = plan
        var ns = specials.slice()
        if (plan.transformed) for (var tk in plan.transformed) if (Object.prototype.hasOwnProperty.call(plan.transformed, tk)) ns[Number(tk)] = Number(plan.transformed[tk])
        specials = ns
        var expanded = BoardLogic.expandSpecials(board, specials, plan.clear || {}, cols, rows)
        currentPlan.clear = expanded.clear
        var soundKind = planSound(plan)
        playSfx(soundKind)
        var expandedCount = keysAsNumbers(expanded.clear).length
        var triggeredSpecials = keysAsNumbers(expanded.triggered || {}).length
        var impact = 0
        if (soundKind === "nova") impact = 0.92
        else if (soundKind === "prism") impact = 0.72
        else if (soundKind === "bomb") impact = 0.62
        else if (soundKind === "line") impact = 0.38
        else if (triggeredSpecials > 0) impact = 0.34
        if (expandedCount >= 28) impact = Math.max(impact, 0.78)
        else if (expandedCount >= 16) impact = Math.max(impact, 0.50)
        if (impact > 0) triggerImpact(impact, soundKind)
        clearingCells = keysAsNumbers(expanded.clear)
        clearAnimating = false; clearProgress = 0
        clearAnimating = true; clearProgress = 1
        gameState = cascadeDepth > 1 ? "Cascading" : "Clearing"
        if (cascadeDepth > 1) message = tr("cascade_multiplier", "Cascade x%1").replace("%1", cascadeMultiplier)
        phaseTimer.action = "commitClear"; phaseTimer.interval = clearMs; phaseTimer.restart()
    }
    function commitClear() {
        var clear = currentPlan && currentPlan.clear ? currentPlan.clear : {}
        var create = currentPlan && currentPlan.create ? currentPlan.create : {}
        var nb = board.slice(), ns = specials.slice(), ni = ice.slice(), nc = collected.slice()
        var clearedCount = 0, specialHits = 0, createdNova = 0
        for (var k in clear) {
            if (!Object.prototype.hasOwnProperty.call(clear, k)) continue
            var p = Number(k)
            if (nb[p] >= 0) { nc[nb[p]] = Number(nc[nb[p]] || 0) + 1; ++clearedCount }
            if (Number(ns[p] || 0) !== BoardLogic.NORMAL) ++specialHits
            nb[p] = -1; ns[p] = BoardLogic.NORMAL
            if (Number(ni[p] || 0) > 0) ni[p] = Number(ni[p]) - 1
        }
        var createdCount = 0
        for (var c in create) {
            if (!Object.prototype.hasOwnProperty.call(create, c)) continue
            var cp = Number(c), spec = create[c]
            nb[cp] = Number(spec.type); ns[cp] = Number(spec.kind); ++createdCount
            if (spec.kind === BoardLogic.BOMB) ++bombsCreated
            if (spec.kind === BoardLogic.NOVA) ++createdNova
            if (Number(ni[cp] || 0) > 0) ni[cp] = Number(ni[cp]) - 1
        }
        board = nb; specials = ns; ice = ni; collected = nc
        clearAnimating = false; clearProgress = 0; clearingCells = []
        var comboBonus = 0
        if (currentPlan && currentPlan.label) {
            if (currentPlan.label === "line_line") comboBonus = 180
            else if (currentPlan.label === "bomb_bomb") comboBonus = 320
            else if (currentPlan.label === "line_bomb") comboBonus = 260
            else if (currentPlan.label === "prism_normal") comboBonus = 240
            else if (currentPlan.label === "prism_line") comboBonus = 420
            else if (currentPlan.label === "prism_bomb") comboBonus = 480
            else if (currentPlan.label === "prism_nova") comboBonus = 560
            else if (currentPlan.label === "prism_prism") comboBonus = 700
            else if (currentPlan.label === "line_nova") comboBonus = 420
            else if (currentPlan.label === "bomb_nova") comboBonus = 520
            else if (currentPlan.label === "nova_nova") comboBonus = 680
            else if (currentPlan.label === "tap_nova") comboBonus = 120
        }
        score += Math.round(clearedCount * 30 * cascadeMultiplier + createdCount * 160 + createdNova * 90 + specialHits * 45 + comboBonus)
        bestCascadeThisLevel = Math.max(bestCascadeThisLevel, cascadeDepth)
        bestCombo = Math.max(bestCombo, cascadeDepth)
        statistics.gemsCleared = Number(statistics.gemsCleared || 0) + clearedCount
        statistics.specialsCreated = Number(statistics.specialsCreated || 0) + createdCount
        statistics.bestCascade = Math.max(Number(statistics.bestCascade || 0), bestCascadeThisLevel)
        try { GameStats.submitHighScore(score); GameStats.submitHighScore(bestCombo, "best_combo") } catch (e) {}
        var collapsed = BoardLogic.collapseAndRefill(board, specials, cols, rows, gemTypes, randomFn, decisionContext())
        board = collapsed.board; specials = collapsed.specials; fallDistance = collapsed.fallDistance; spawnedFlags = collapsed.spawned
        var maxDistance = 0
        for (var fd = 0; fd < fallDistance.length; ++fd) maxDistance = Math.max(maxDistance, Number(fallDistance[fd] || 0))
        activeFallMs = reducedMotion ? 1 : Math.max(120, Math.min(420, 80 + maxDistance * 40))
        gameState = "Falling"
        fallAnimating = false; fallProgress = 0
        fallAnimating = true; fallProgress = 1
        phaseTimer.action = "finishFall"; phaseTimer.interval = activeFallMs; phaseTimer.restart()
    }
    function finishFall() {
        fallAnimating = false; fallProgress = 1; fallDistance = []; spawnedFlags = []
        var runs = BoardLogic.findRuns(board, cols, rows)
        if (runs.length > 0) {
            cascadeDepth += 1
            if (cascadeDepth > 32) {
                // Hard safety cap: regenerate rather than permit an infinite cascade.
                message = tr("cascade_safety", "Cascade safety reset")
                startShuffle(false)
                return
            }
            beginClear(BoardLogic.buildMatchPlan(board, specials, cols, rows, -1, -1))
            return
        }
        settleBoard()
    }
    function settleBoard() {
        cascadeDepth = 0
        currentPlan = null
        pendingComboPlan = null
        pendingA = -1; pendingB = -1; pendingLegal = false
        checkEndState()
        if (levelComplete || gameOver) { markDirty(true); return }
        if (!BoardLogic.hasPlayableAction(board, specials, cols, rows)) {
            message = tr("no_moves_shuffle", "No more moves! Shuffling...")
            startShuffle(false)
            return
        }
        gameState = "Idle"
        markDirty(false)
    }

    function boosterDisplayName(name) {
        if (name === "hammer") return tr("booster_hammer", "Hammer")
        if (name === "shuffle") return tr("booster_shuffle", "Shuffle")
        if (name === "cross") return tr("booster_cross", "Cross Blast")
        if (name === "extra") return tr("booster_extra", "Extra Moves")
        return name
    }
    function awardLevelBoosters(levelNumber, stars, previousStars) {
        var rewards = LevelLogic.boosterRewards(levelNumber, stars, previousStars)
        var names = []
        var next = copyObject(boosters)
        for (var key in rewards) {
            if (!Object.prototype.hasOwnProperty.call(rewards, key)) continue
            var amount = Number(rewards[key] || 0)
            if (amount <= 0) continue
            next[key] = Number(next[key] || 0) + amount
            names.push(boosterDisplayName(key) + " x" + amount)
        }
        if (names.length > 0) {
            boosters = next
            playSfx("booster")
            return names.join(", ")
        }
        return ""
    }

    function checkEndState() {
        if (objectiveComplete()) {
            gameState = "LevelComplete"
            var stars = LevelLogic.starCount(score, targetScore, true)
            lastEarnedStars = stars
            var previousStars = Number(starsByLevel[String(level)] || 0)
            var rewardSummary = awardLevelBoosters(level, stars, previousStars)
            var starMap = copyObject(starsByLevel), scoreMap = copyObject(bestScores)
            starMap[String(level)] = Math.max(previousStars, stars)
            scoreMap[String(level)] = Math.max(Number(scoreMap[String(level)] || 0), score)
            starsByLevel = starMap; bestScores = scoreMap
            unlockedLevel = Math.max(unlockedLevel, level + 1)
            statistics.levelsCleared = Number(statistics.levelsCleared || 0) + 1
            message = tr("level_clear_stars", "Level cleared - %1").replace("%1", starsText(stars))
            if (rewardSummary.length > 0)
                message += " | " + tr("booster_reward", "Reward: %1").replace("%1", rewardSummary)
            playSfx(stars === 3 ? "star" : "win")
            try {
                GameStats.increment("levels_cleared"); GameStats.submitHighScore(level, "best_level")
                Achievements.unlock("gem_level_" + Math.min(30, level)); if (stars === 3) Achievements.unlock("three_star_clear")
            } catch (e) {}
            haptic("heavy")
        } else if (movesLeft <= 0) {
            gameState = "LevelFailed"
            message = tr("out_of_moves", "Out of moves")
            haptic("medium")
            playSfx("fail")
        } else gameState = "Idle"
    }

    function hintPair() {
        if (!inputReady || !showHints) return
        var action = BoardLogic.findBestAction(board, specials, cols, rows, decisionContext())
        if (!action || !action.cells || action.cells.length === 0) { startShuffle(false); return }
        hintCells = action.cells.slice()
        selected = action.cells[0]
        cursor = action.cells.length > 1 ? action.cells[1] : action.cells[0]
        gameState = "Selecting"
        if (action.type === "activate")
            message = tr("hint_best_special", "Best action: activate this special")
        else
            message = tr("hint_best_move", "Best move highlighted")
    }
    function startShuffle(consumeBooster) {
        if (gameState === "Shuffling") return
        if (consumeBooster) {
            if (Number(boosters.shuffle || 0) <= 0 || !inputReady) return
            var b = copyObject(boosters); b.shuffle = Number(b.shuffle) - 1; boosters = b
            markDirty(false)
        }
        selected = -1; boosterMode = ""; hintCells = []
        gameState = "Shuffling"
        shufflePulse = 1
        playSfx("shuffle")
        phaseTimer.action = "commitShuffle"; phaseTimer.interval = reducedMotion ? 1 : 180; phaseTimer.restart()
    }
    function commitShuffle() {
        var shuffled = BoardLogic.shufflePairs(board, specials, cols, rows, randomFn)
        if (!shuffled) shuffled = BoardLogic.generateBoard(cols, rows, gemTypes, randomFn)
        if (!shuffled) { shufflePulse = 0; gameState = "Idle"; return }
        board = shuffled.board; specials = shuffled.specials
        shufflePulse = 0
        message = tr("shuffled", "Board shuffled")
        playSfx("shuffle")
        gameState = "Idle"
        markDirty(false)
    }

    function activateBooster(name) {
        if (!inputReady) return
        if (name === "shuffle") { startShuffle(true); return }
        if (name === "extra") {
            if (Number(boosters.extra || 0) <= 0) return
            var be = copyObject(boosters); be.extra = Number(be.extra) - 1; boosters = be
            movesLeft += 5; message = tr("extra_moves_used", "+5 moves"); haptic("medium"); playSfx("booster"); markDirty(true); return
        }
        if (Number(boosters[name] || 0) <= 0) return
        boosterMode = boosterMode === name ? "" : name
        message = boosterMode.length ? tr("booster_pick_gem", "Choose a gem") : ""
        if (boosterMode.length) playSfx("select")
    }
    function useTargetBooster(name, p) {
        if (!inputReady || Number(boosters[name] || 0) <= 0) return
        var b = copyObject(boosters); b[name] = Number(b[name]) - 1; boosters = b; boosterMode = ""
        markDirty(false)
        var clear = {}
        if (name === "hammer") clear[p] = true
        else {
            for (var x = 0; x < cols; ++x) clear[idx(x, yOf(p))] = true
            for (var y = 0; y < rows; ++y) clear[idx(xOf(p), y)] = true
        }
        cascadeDepth = 1
        message = tr("booster_used", "Booster used")
        haptic(name === "cross" ? "heavy" : "medium")
        playSfx("booster")
        beginClear({ clear: clear, create: {}, transformed: {}, specialCreated: { line: 0, bomb: 0, prism: 0 } })
    }
    function retryLevel() { startLevel(level, false) }
    function nextLevel() { startLevel(level + 1, false) }
    function moveCursor(dx, dy) {
        if (!inputReady) return
        var x = Math.max(0, Math.min(cols - 1, xOf(cursor) + dx))
        var y = Math.max(0, Math.min(rows - 1, yOf(cursor) + dy))
        cursor = idx(x, y)
    }
    function togglePause() {
        if (gameState === "Paused") {
            gameState = stateBeforePause === "Selecting" ? "Selecting" : "Idle"
            message = ""
            try { if (audioLoader.status === Loader.Ready && audioLoader.item) audioLoader.item.resumeAll() } catch (e) {}
            return
        }
        if (!inputReady) return
        stateBeforePause = gameState; gameState = "Paused"; message = tr("paused", "Paused")
        try { if (audioLoader.status === Loader.Ready && audioLoader.item) audioLoader.item.pauseAll() } catch (e) {}
        forceSave()
    }
    function prepareForBackground() {
        if (!initialized) return
        try { if (audioLoader.status === Loader.Ready && audioLoader.item) audioLoader.item.pauseAll() } catch (e0) {}
        saveTimer.stop()
        phaseTimer.stop()
        // An animation is a transaction. If the app is suspended mid-transaction,
        // roll back to the last stable board rather than persisting a half-swap/clear/fall.
        if (!inputReady && gameState !== "Paused" && gameState !== "LevelComplete" && gameState !== "LevelFailed" && lastStableSnapshot !== null) {
            swapAnimating = false; clearAnimating = false; fallAnimating = false
            swapProgress = 0; clearProgress = 0; fallProgress = 1; shufflePulse = 0
            clearingCells = []; hintCells = []; spawnedFlags = []; fallDistance = []
            pendingReverse = false
            restoreSnapshot(copyObject(lastStableSnapshot))
        }
        if (gameState !== "Paused" && gameState !== "LevelComplete" && gameState !== "LevelFailed") {
            stateBeforePause = gameState === "Selecting" ? "Idle" : gameState
            gameState = "Paused"
            message = tr("paused", "Paused")
            markDirty(true)
        } else {
            dirty = true
            forceSave()
        }
    }

    function campaignSnapshot() {
        return {
            schema: 2,
            version: version,
            level: level,
            unlockedLevel: unlockedLevel,
            starsByLevel: starsByLevel,
            bestScores: bestScores,
            boosters: boosters,
            preferences: { sound: soundEnabled, vibration: vibrationEnabled },
            tutorialCompleted: tutorialCompleted,
            bestCombo: bestCombo,
            statistics: statistics
        }
    }
    function stableActiveSnapshot() {
        if (!(gameState === "Idle" || gameState === "Selecting" || gameState === "LevelComplete" || gameState === "LevelFailed" || gameState === "Paused")) return null
        return {
            board: board,
            specials: specials,
            ice: ice,
            collected: collected,
            score: score,
            movesLeft: movesLeft,
            targetScore: targetScore,
            targetType: targetType,
            targetCount: targetCount,
            targetIce: targetIce,
            levelInitialIce: levelInitialIce,
            targetBombs: targetBombs,
            bombsCreated: bombsCreated,
            targetCascade: targetCascade,
            bestCascadeThisLevel: bestCascadeThisLevel,
            state: gameState === "Selecting" ? "Idle" : gameState
        }
    }
    function markDirty(immediate) {
        if (!initialized) return
        dirty = true
        if (immediate) forceSave()
        else saveTimer.restart()
    }
    function snapshotForSave() {
        var active = stableActiveSnapshot()
        if (active !== null) {
            var fresh = { campaign: campaignSnapshot(), active: active }
            lastStableSnapshot = copyObject(fresh)
            return fresh
        }
        if (lastStableSnapshot !== null) return copyObject(lastStableSnapshot)
        return { campaign: campaignSnapshot(), active: null }
    }
    function forceSave() {
        if (!initialized || !dirty || !serviceContextReady()) return
        var payload = snapshotForSave()
        try {
            GameSave.set("snapshotJson", JSON.stringify(payload))
            GameSave.set("schema", 2)
            GameSave.save("autosave")
            dirty = false
        } catch (e) { console.warn("Gem Cascade save failed:", e) }
    }
    function restoreSnapshot(payload) {
        if (!payload || !payload.campaign) return false
        var c = payload.campaign
        level = Math.max(1, Number(c.level || 1)); unlockedLevel = Math.max(level, Number(c.unlockedLevel || level))
        starsByLevel = c.starsByLevel || {}; bestScores = c.bestScores || {}
        boosters = c.boosters || { hammer: 3, shuffle: 2, cross: 1, extra: 2 }
        if (c.preferences) {
            if (c.preferences.sound !== undefined) soundEnabled = Boolean(c.preferences.sound)
            if (c.preferences.vibration !== undefined) vibrationEnabled = Boolean(c.preferences.vibration)
        }
        tutorialCompleted = Boolean(c.tutorialCompleted); bestCombo = Number(c.bestCombo || 0)
        statistics = c.statistics || { levelsPlayed: 0, levelsCleared: 0, gemsCleared: 0, specialsCreated: 0, bestCascade: 0 }
        var a = payload.active
        if (!a || !a.board || a.board.length !== cols * rows || !a.specials || a.specials.length !== cols * rows || !a.ice || a.ice.length !== cols * rows) {
            startLevel(level, true); return true
        }
        board = normalizedIntArray(a.board, 64, []); specials = normalizedIntArray(a.specials, 64, []); ice = normalizedIntArray(a.ice, 64, [])
        collected = normalizedIntArray(a.collected || [0,0,0,0,0,0], 6, [0,0,0,0,0,0])
        score = Number(a.score || 0); movesLeft = Number(a.movesLeft || 0); targetScore = Number(a.targetScore || 0)
        targetType = Number(a.targetType || 0); targetCount = Number(a.targetCount || 0); targetIce = Number(a.targetIce || 0); levelInitialIce = Number(a.levelInitialIce || targetIce)
        targetBombs = Number(a.targetBombs || 0); bombsCreated = Number(a.bombsCreated || 0); targetCascade = Number(a.targetCascade || 0); bestCascadeThisLevel = Number(a.bestCascadeThisLevel || 0)
        var savedState = String(a.state || "Idle")
        gameState = savedState === "LevelComplete" || savedState === "LevelFailed" || savedState === "Paused" ? savedState : "Idle"
        return true
    }
    function migrateLegacySave() {
        try {
            var oldBoard = GameSave.get("board", [])
            if (!oldBoard || oldBoard.length !== 64) return false
            level = Number(GameSave.get("level", 1)); configureLevel(level)
            board = normalizedIntArray(oldBoard, 64, []); specials = normalizedIntArray(GameSave.get("specials", []), 64, []); ice = normalizedIntArray(GameSave.get("ice", []), 64, [])
            collected = normalizedIntArray(GameSave.get("collected", [0,0,0,0,0,0]), 6, [0,0,0,0,0,0])
            score = Number(GameSave.get("score", 0)); movesLeft = Number(GameSave.get("moves", movesLeft)); targetScore = Number(GameSave.get("targetScore", targetScore))
            targetType = Number(GameSave.get("targetType", targetType)); targetCount = Number(GameSave.get("targetCount", targetCount)); targetIce = Number(GameSave.get("targetIce", targetIce))
            levelInitialIce = Number(GameSave.get("levelInitialIce", targetIce)); bestCombo = Number(GameSave.get("bestCombo", 0))
            gameState = Boolean(GameSave.get("levelComplete", false)) ? "LevelComplete" : (Boolean(GameSave.get("gameOver", false)) ? "LevelFailed" : "Idle")
            return true
        } catch (e) { return false }
    }
    function sanitizeRestoredBoard() {
        if (board.length !== cols * rows || specials.length !== cols * rows || ice.length !== cols * rows) return false
        for (var i = 0; i < board.length; ++i) {
            if (!isFinite(Number(board[i])) || Number(board[i]) < 0 || Number(board[i]) >= gemTypes) return false
            if (!isFinite(Number(specials[i])) || Number(specials[i]) < BoardLogic.NORMAL || Number(specials[i]) > BoardLogic.NOVA) return false
            if (!isFinite(Number(ice[i])) || Number(ice[i]) < 0 || Number(ice[i]) > 2) ice[i] = Math.max(0, Math.min(2, Number(ice[i]) || 0))
        }
        if (gameState === "LevelComplete" || gameState === "LevelFailed") return true
        if (BoardLogic.findRuns(board, cols, rows).length === 0 && BoardLogic.hasPlayableAction(board, specials, cols, rows)) return true
        var recovered = BoardLogic.shufflePairs(board, specials, cols, rows, randomFn)
        if (!recovered) recovered = BoardLogic.generateBoard(cols, rows, gemTypes, randomFn)
        if (!recovered) return false
        board = recovered.board; specials = recovered.specials
        gameState = gameState === "Paused" ? "Paused" : "Idle"
        return true
    }

    function loadGame() {
        var restored = false
        try {
            if (GameSave.load("autosave")) {
                var json = String(GameSave.get("snapshotJson", ""))
                if (json.length > 0) restored = restoreSnapshot(JSON.parse(json))
                if (!restored) restored = migrateLegacySave()
            }
        } catch (e) { console.warn("Gem Cascade load failed:", e) }
        if (!restored) startLevel(1, true)
        if (!sanitizeRestoredBoard()) startLevel(level, true)
        var active = stableActiveSnapshot()
        lastStableSnapshot = active !== null ? copyObject({ campaign: campaignSnapshot(), active: active }) : null
        dirty = false
    }
    function initializeGame() {
        if (initialized || !serviceContextReady()) return
        initialized = true
        try { GameRandom.seed("gem-cascade-v65") } catch (e) {}
        loadGame()
        forceActiveFocus()
        if (!tutorialCompleted && level === 1 && gameState === "Idle") { tutorial.page = 0; tutorial.open = true }
    }

    Timer { id: phaseTimer; property string action: ""; onTriggered: {
        if (action === "finishForwardSwap") root.finishForwardSwap()
        else if (action === "beginReverseSwap") root.beginReverseSwap()
        else if (action === "finishReverseSwap") root.finishReverseSwap()
        else if (action === "commitClear") root.commitClear()
        else if (action === "finishFall") root.finishFall()
        else if (action === "commitShuffle") root.commitShuffle()
    } }
    Timer { id: saveTimer; interval: 450; repeat: false; onTriggered: root.forceSave() }
    Timer { id: hostWaitTimer; interval: 80; repeat: true; running: !root.initialized; onTriggered: root.initializeGame() }

    Behavior on swapProgress { enabled: root.swapAnimating; NumberAnimation { duration: root.swapMs; easing.type: Easing.InOutCubic } }
    Behavior on clearProgress { enabled: root.clearAnimating; NumberAnimation { duration: root.clearMs; easing.type: Easing.OutCubic } }
    Behavior on fallProgress { enabled: root.fallAnimating; NumberAnimation { duration: root.activeFallMs; easing.type: Easing.OutCubic } }
    Behavior on shufflePulse { NumberAnimation { duration: root.reducedMotion ? 1 : 160; easing.type: Easing.InOutCubic } }
    NumberAnimation {
        id: impactAnimation
        target: root
        property: "impactPhase"
        from: 0
        to: 1
        duration: root.reducedMotion ? 1 : 190
        easing.type: Easing.OutCubic
    }

    Rectangle { anchors.fill: parent; color: root.themeColor("color.background") }

    Loader {
        id: audioLoader
        active: true
        asynchronous: true
        source: "components/AudioBus.qml"
        onLoaded: { if (item) item.enabled = root.soundEnabled }
        onStatusChanged: { if (status === Loader.Ready && item) item.enabled = root.soundEnabled }
    }
    onSoundEnabledChanged: {
        if (audioLoader.status === Loader.Ready && audioLoader.item) audioLoader.item.enabled = soundEnabled
    }

    Connections {
        target: typeof Lifecycle !== "undefined" ? Lifecycle : null
        ignoreUnknownSignals: true
        function onSaveRequested() { root.forceSave() }
        function onBackgrounded() { root.prepareForBackground() }
        function onPaused() { root.forceSave() }
        function onClosing() { root.forceSave() }
        function onUnloading() { root.forceSave() }
    }
    Connections {
        target: typeof GameI18n !== "undefined" ? GameI18n : null
        ignoreUnknownSignals: true
        function onReadyChanged() { root.languageRevision++; root.initializeGame() }
        function onLocaleChanged() { root.languageRevision++; root.initializeGame() }
        function onLanguageChanged() { root.languageRevision++; root.initializeGame() }
        function onTranslationsChanged() { root.languageRevision++ }
        function onGameIdChanged() { root.languageRevision++; root.initializeGame() }
    }
    Connections {
        target: typeof GameSave !== "undefined" ? GameSave : null
        ignoreUnknownSignals: true
        function onReadyChanged() { root.initializeGame() }
        function onGameIdChanged() { root.initializeGame() }
    }
    Connections {
        target: typeof GameTheme !== "undefined" ? GameTheme : null
        ignoreUnknownSignals: true
        function onThemeChanged() { root.themeRevision++ }
        function onChanged() { root.themeRevision++ }
    }

    function physicalKey(e, name) {
        var sc = Number(e.nativeScanCode || 0)
        var os = Qt.platform.os
        var winEvdev = {w:17,a:30,s:31,d:32,h:35,p:25,r:19,space:57}
        var x11 = {w:25,a:38,s:39,d:40,h:43,p:33,r:27,space:65}
        var mac = {w:13,a:0,s:1,d:2,h:4,p:35,r:15,space:49}
        if (os === "windows") return sc === Number(winEvdev[name])
        if (os === "osx" || os === "macos") return sc === Number(mac[name])
        if (sc <= 0) return false
        if (os === "linux") return sc === Number(winEvdev[name]) || sc === Number(x11[name])
        return false
    }
    function keyMatches(e, logicalKey, physicalName) { return e.key === logicalKey || (physicalName && physicalKey(e, physicalName)) }

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(e) {
        if (e.key === Qt.Key_Escape || keyMatches(e, Qt.Key_P, "p")) root.togglePause()
        else if (e.key === Qt.Key_Left || keyMatches(e, Qt.Key_A, "a")) root.moveCursor(-1, 0)
        else if (e.key === Qt.Key_Right || keyMatches(e, Qt.Key_D, "d")) root.moveCursor(1, 0)
        else if (e.key === Qt.Key_Up || keyMatches(e, Qt.Key_W, "w")) root.moveCursor(0, -1)
        else if (e.key === Qt.Key_Down || keyMatches(e, Qt.Key_S, "s")) root.moveCursor(0, 1)
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || keyMatches(e, Qt.Key_Space, "space")) root.requestTap(root.cursor)
        else if (keyMatches(e, Qt.Key_H, "h")) root.hintPair()
        else if (keyMatches(e, Qt.Key_R, "r") && root.inputReady) root.retryLevel()
        else return
        e.accepted = true
    }

    property real pagePadding: Math.max(8, root.themeNumber("alias.page.padding"))
    property real pageGap: Math.max(6, root.themeNumber("alias.page.gap"))
    property bool portrait: height > width * 1.05
    property real boardAvailableWidth: Math.max(80, page.width - (portrait ? 0 : Math.min(300, page.width * 0.28)) - (portrait ? 0 : pageGap))
    property real boardAvailableHeight: Math.max(80, playArea.height)
    property real cellGap: Math.max(1, root.themeNumber("alias.gameTile.gap"))
    property real cellSize: Math.max(6, Math.min(82, Math.min((boardAvailableWidth - cellGap * 7) / 8, (boardAvailableHeight - cellGap * 7) / 8)))
    property real boardPixelSize: cellSize * 8 + cellGap * 7

    Column {
        id: page
        anchors.fill: parent
        anchors.topMargin: root.pagePadding + root.SafeArea.margins.top
        anchors.bottomMargin: root.pagePadding + root.SafeArea.margins.bottom
        anchors.leftMargin: root.pagePadding + root.SafeArea.margins.left
        anchors.rightMargin: root.pagePadding + root.SafeArea.margins.right
        spacing: root.pageGap

        UiPanel { themeRevision: root.themeRevision;
            width: parent.width
            implicitHeight: header.implicitHeight + root.themeNumber("alias.card.padding") * 2
            surfaceToken: "surface.panel"
            Flow {
                id: header
                anchors.fill: parent
                anchors.margins: root.themeNumber("alias.card.padding")
                spacing: root.themeNumber("alias.card.gap")
                UiText { themeRevision: root.themeRevision; text: root.tr("title", "Gem Cascade"); font.bold: true; sizeToken: "metric.font.lg" }
                HudChip { themeRevision: root.themeRevision; label: root.tr("level", "Level"); value: String(root.level) }
                HudChip { themeRevision: root.themeRevision; label: root.tr("score", "Score"); value: String(root.score) }
                HudChip { themeRevision: root.themeRevision; label: root.tr("moves", "Moves"); value: String(root.movesLeft); valueColorToken: root.movesLeft > 5 ? "color.accent" : "color.info" }
                HudChip { themeRevision: root.themeRevision; label: root.tr("stars", "Stars"); value: root.starsText(Number(root.starsByLevel[String(root.level)] || 0)); valueColorToken: "color.accent" }
                HudChip { themeRevision: root.themeRevision; label: root.tr("cascade", "Cascade"); value: "x" + (root.cascadeDepth > 0 ? root.cascadeMultiplier : 1) }
            }
        }

        UiPanel { themeRevision: root.themeRevision;
            width: parent.width
            implicitHeight: objectiveColumn.implicitHeight + root.themeNumber("alias.card.padding") * 2
            surfaceToken: "surface.card"
            Column {
                id: objectiveColumn
                anchors.fill: parent
                anchors.margins: root.themeNumber("alias.card.padding")
                spacing: root.themeNumber("metric.space.xs")
                Row {
                    width: parent.width
                    spacing: Math.max(4, root.themeNumber("metric.space.xs"))
                    Image {
                        width: Math.max(22, root.themeNumber("metric.icon.md")); height: width
                        source: Qt.resolvedUrl("assets/gems/" + root.gemFiles[root.targetType])
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                    UiText { themeRevision: root.themeRevision;
                        width: Math.max(1, parent.width - x)
                        text: root.objectiveText()
                        font.bold: true
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                UiBar { themeRevision: root.themeRevision; width: parent.width; height: Math.max(5, root.themeNumber("metric.space.xs")); value: Math.min(1, root.score / Math.max(1, root.targetScore)); to: 1; fillToken: "color.primary" }
            }
        }

        Item {
            id: playArea
            width: parent.width
            height: Math.max(120, parent.height - y - actions.implicitHeight - statusText.implicitHeight - root.pageGap * 2)

            Row {
                id: landscapeRow
                anchors.centerIn: parent
                spacing: root.pageGap

                Item {
                    id: boardStage
                    width: root.boardPixelSize
                    height: root.boardPixelSize
                    scale: 1.0 - root.shufflePulse * 0.08
                    opacity: 1.0 - root.shufflePulse * 0.60
                    transform: Translate { x: root.boardShakeX; y: root.boardShakeY }
                    Grid {
                        id: grid
                        anchors.fill: parent
                        columns: root.cols
                        spacing: root.cellGap
                        Repeater {
                            model: root.cols * root.rows
                            Components.GemCell { themeRevision: root.themeRevision;
                                cellIndex: index
                                gem: Number(root.board[index] === undefined ? -1 : root.board[index])
                                special: Number(root.specials[index] || 0)
                                iceLayer: Number(root.ice[index] || 0)
                                selected: index === root.selected
                                cursor: index === root.cursor
                                clearing: root.arrayHas(root.clearingCells, index)
                                clearProgress: root.clearProgress
                                hint: root.arrayHas(root.hintCells, index)
                                cellSize: root.cellSize
                                reducedMotion: root.reducedMotion
                                gemFiles: root.gemFiles
                                gemColors: root.gemColors
                                swapX: index === root.swapA ? (root.xOf(root.swapB) - root.xOf(root.swapA)) * root.cellSize * root.swapProgress
                                     : index === root.swapB ? (root.xOf(root.swapA) - root.xOf(root.swapB)) * root.cellSize * root.swapProgress : 0
                                swapY: index === root.swapA ? (root.yOf(root.swapB) - root.yOf(root.swapA)) * root.cellSize * root.swapProgress
                                     : index === root.swapB ? (root.yOf(root.swapA) - root.yOf(root.swapB)) * root.cellSize * root.swapProgress : 0
                                fallY: index < root.fallDistance.length ? -Number(root.fallDistance[index] || 0) * root.cellSize * (1 - root.fallProgress) : 0
                                spawned: index < root.spawnedFlags.length ? Boolean(root.spawnedFlags[index]) : false
                                fallProgress: root.fallProgress
                                shufflePulse: root.shufflePulse
                                onTapped: function(i) { root.requestTap(i) }
                                onSwiped: function(i, dx, dy) { root.requestSwipe(i, dx, dy) }
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        z: 20
                        radius: Math.max(8, root.themeNumber("alias.card.radius"))
                        color: root.themeColor(root.impactColorToken)
                        opacity: root.impactFlashOpacity
                        visible: opacity > 0.001
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        z: 21
                        width: parent.width * (0.42 + 0.68 * root.impactPhase)
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: root.impactStrength > 0 ? Math.max(1, 3 * (1 - root.impactPhase)) : 0
                        border.color: root.themeColor(root.impactColorToken)
                        opacity: Math.max(0, root.impactStrength * 0.58 * (1 - root.impactPhase))
                        visible: opacity > 0.001
                    }
                    Repeater {
                        model: root.reducedMotion || root.impactStrength <= 0 ? 0 : 6
                        Rectangle {
                            required property int index
                            anchors.centerIn: parent
                            z: 22
                            width: Math.max(3, root.cellSize * 0.075)
                            height: width
                            radius: width / 2
                            color: root.themeColor(root.impactColorToken)
                            opacity: Math.max(0, root.impactStrength * (1 - root.impactPhase))
                            transform: Translate {
                                x: Math.cos(index * Math.PI / 3) * root.boardPixelSize * 0.24 * root.impactPhase
                                y: Math.sin(index * Math.PI / 3) * root.boardPixelSize * 0.24 * root.impactPhase
                            }
                        }
                    }
                }

                UiPanel { themeRevision: root.themeRevision;
                    visible: !root.portrait && root.width >= 760
                    width: Math.min(290, root.width * 0.26)
                    height: root.boardPixelSize
                    surfaceToken: "surface.panel"
                    Column {
                        anchors.fill: parent
                        anchors.margins: root.themeNumber("alias.card.padding")
                        spacing: root.themeNumber("alias.card.gap")
                        UiText { themeRevision: root.themeRevision; width: parent.width; text: root.tr("boosters", "Boosters"); font.bold: true }
                        Components.BoosterButton { themeRevision: root.themeRevision; interactionEnabled: root.inputReady; width: parent.width; rootText: root.tr("booster_hammer", "Hammer"); count: Number(root.boosters.hammer || 0); active: root.boosterMode === "hammer"; iconSource: Qt.resolvedUrl("assets/icons/booster_hammer.svg"); onActivated: root.activateBooster("hammer") }
                        Components.BoosterButton { themeRevision: root.themeRevision; interactionEnabled: root.inputReady; width: parent.width; rootText: root.tr("booster_shuffle", "Shuffle"); count: Number(root.boosters.shuffle || 0); iconSource: Qt.resolvedUrl("assets/icons/booster_shuffle.svg"); onActivated: root.activateBooster("shuffle") }
                        Components.BoosterButton { themeRevision: root.themeRevision; interactionEnabled: root.inputReady; width: parent.width; rootText: root.tr("booster_cross", "Cross Blast"); count: Number(root.boosters.cross || 0); active: root.boosterMode === "cross"; iconSource: Qt.resolvedUrl("assets/icons/booster_cross.svg"); onActivated: root.activateBooster("cross") }
                        Components.BoosterButton { themeRevision: root.themeRevision; interactionEnabled: root.inputReady; width: parent.width; rootText: root.tr("booster_extra", "Extra Moves"); count: Number(root.boosters.extra || 0); iconSource: Qt.resolvedUrl("assets/icons/booster_extra.svg"); onActivated: root.activateBooster("extra") }
                        UiText { themeRevision: root.themeRevision; width: parent.width; text: root.tr("controls_desktop", "Mouse/touch: click or drag - Keyboard: WASD/arrows, Enter, H, P/Esc"); colorToken: "color.textMuted"; sizeToken: "metric.font.xs" }
                    }
                }
            }
        }

        Flow {
            id: actions
            width: parent.width
            height: implicitHeight
            spacing: root.themeNumber("alias.button.gap")
            UiButton { themeRevision: root.themeRevision; text: root.tr("hint_button", "Hint"); shortcutText: "H"; enabled: root.inputReady && root.showHints; onActivated: root.hintPair() }
            UiButton { themeRevision: root.themeRevision; text: root.gameState === "Paused" ? root.tr("resume", "Resume") : root.tr("pause", "Pause"); shortcutText: "Esc"; enabled: root.inputReady || root.gameState === "Paused"; onActivated: root.togglePause() }
            UiButton { themeRevision: root.themeRevision; text: root.tr("guide", "Guide"); onActivated: { tutorial.page = 0; tutorial.open = true } }
            Components.BoosterButton { themeRevision: root.themeRevision; interactionEnabled: root.inputReady; visible: root.portrait || root.width < 760; rootText: root.tr("booster_hammer_short", "Hammer"); count: Number(root.boosters.hammer || 0); active: root.boosterMode === "hammer"; iconSource: Qt.resolvedUrl("assets/icons/booster_hammer.svg"); onActivated: root.activateBooster("hammer") }
            Components.BoosterButton { themeRevision: root.themeRevision; interactionEnabled: root.inputReady; visible: root.portrait || root.width < 760; rootText: root.tr("booster_shuffle_short", "Shuffle"); count: Number(root.boosters.shuffle || 0); iconSource: Qt.resolvedUrl("assets/icons/booster_shuffle.svg"); onActivated: root.activateBooster("shuffle") }
            Components.BoosterButton { themeRevision: root.themeRevision; interactionEnabled: root.inputReady; visible: root.portrait || root.width < 760; rootText: root.tr("booster_cross_short", "Cross"); count: Number(root.boosters.cross || 0); active: root.boosterMode === "cross"; iconSource: Qt.resolvedUrl("assets/icons/booster_cross.svg"); onActivated: root.activateBooster("cross") }
            Components.BoosterButton { themeRevision: root.themeRevision; interactionEnabled: root.inputReady; visible: root.portrait || root.width < 760; rootText: root.tr("booster_extra_short", "+5"); count: Number(root.boosters.extra || 0); iconSource: Qt.resolvedUrl("assets/icons/booster_extra.svg"); onActivated: root.activateBooster("extra") }
            UiButton { themeRevision: root.themeRevision; visible: root.levelComplete; text: root.tr("next_level", "Next Level"); primary: true; onActivated: root.nextLevel() }
            UiButton { themeRevision: root.themeRevision; visible: root.gameOver; text: root.tr("retry", "Retry"); primary: true; onActivated: root.retryLevel() }
        }

        UiText { themeRevision: root.themeRevision;
            id: statusText
            width: parent.width
            text: root.message.length > 0 ? root.message : root.tr("gameplay_tip", "Match 4 => Line - T/L => Bomb - Match 5 => Prism - Match 6 => Nova - Click specials to trigger or combine adjacent specials.")
            colorToken: "color.textMuted"
            horizontalAlignment: Text.AlignHCenter
            sizeToken: "metric.font.xs"
        }
    }

    Rectangle {
        visible: root.gameState === "Paused"
        anchors.fill: parent
        z: 80
        color: Qt.rgba(0, 0, 0, 0.45)
        MouseArea { anchors.fill: parent }
        UiPanel { themeRevision: root.themeRevision;
            width: Math.min(parent.width - 32, 360)
            implicitHeight: pauseColumn.implicitHeight + root.themeNumber("alias.card.padding") * 2
            anchors.centerIn: parent
            Column {
                id: pauseColumn
                anchors.fill: parent
                anchors.margins: root.themeNumber("alias.card.padding")
                spacing: root.themeNumber("alias.card.gap")
                UiText { themeRevision: root.themeRevision; width: parent.width; text: root.tr("paused", "Paused"); font.bold: true; horizontalAlignment: Text.AlignHCenter; sizeToken: "metric.font.lg" }
                Row {
                    width: parent.width
                    spacing: root.themeNumber("alias.button.gap")
                    UiButton {
                        themeRevision: root.themeRevision
                        width: Math.max(1, (parent.width - parent.spacing) / 2)
                        text: root.soundEnabled ? root.tr("sound_on", "Sound on") : root.tr("sound_off", "Sound off")
                        onActivated: root.toggleSoundPreference()
                    }
                    UiButton {
                        themeRevision: root.themeRevision
                        width: Math.max(1, (parent.width - parent.spacing) / 2)
                        text: root.vibrationEnabled ? root.tr("vibration_on", "Vibration on") : root.tr("vibration_off", "Vibration off")
                        onActivated: root.toggleVibrationPreference()
                    }
                }
                UiButton { themeRevision: root.themeRevision; width: parent.width; text: root.tr("resume", "Resume"); primary: true; onActivated: root.togglePause() }
            }
        }
    }

    Components.TutorialOverlay {
        themeRevision: root.themeRevision
        id: tutorial
        translate: function(k, f) { return root.tr(k, f) }
        onFinished: { root.tutorialCompleted = true; root.markDirty(true) }
        onDismissed: {
            if (!root.tutorialCompleted) { root.tutorialCompleted = true; root.markDirty(true) }
            root.forceActiveFocus()
        }
    }

    Connections {
        target: typeof GameInput !== "undefined" ? GameInput : null
        ignoreUnknownSignals: true
        function onActionPressed(action, value) {
            if (action === "move_left") root.moveCursor(-1, 0)
            else if (action === "move_right") root.moveCursor(1, 0)
            else if (action === "up") root.moveCursor(0, -1)
            else if (action === "down") root.moveCursor(0, 1)
            else if (action === "fire" || action === "select") root.requestTap(root.cursor)
            else if (action === "hint") root.hintPair()
            else if (action === "pause") root.togglePause()
        }
    }

    Component.onCompleted: initializeGame()
    Component.onDestruction: forceSave()
}
