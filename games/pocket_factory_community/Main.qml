import QtQuick
import "city" as City
import "city/CityData.js" as Data

Item {
    id: root
    property real coins: 100
    property real research: 0
    property real reputation: 0
    property real crowns: 0
    property int storageLevel: 1
    property int efficiencyLevel: 0
    property var stock: [0, 0, 0, 0, 0]
    property var lines: freshLines()
    property var buildingLevels: [1,1,1,1,1,1]
    property var contract: ({kind:"goods", amount:10, progress:0, reward:120, research:2})
    property string message: ""
    property string offlineText: ""
    property bool ready: false
    property bool saveBlocked: false
    property bool suspended: false
    property double lastCheckpoint: 0
    property double wentBackground: 0
    property int page: 0
    property int selectedLine: 0
    property int selectedZone: -1
    property int buyMode: 1
    property int guideStep: 0
    property bool confirmPrestige: false

    readonly property var lineKeys: ["mine","smelter","circuit","assembly","robotics","export"]
    readonly property var lineNames: ["Ore Drill","Smelter","Circuit Lab","Assembly","Robotics","Export Dock"]
    readonly property var resources: ["Ore","Parts","Circuits","Goods","Robots"]
    readonly property var resourceKeys: ["ore","parts","circuits","goods","robots"]
    readonly property var inputs: [[],[[0,2]],[[0,2],[1,1]],[[1,2],[2,1]],[[3,2],[2,2]],[[4,1]]]
    readonly property var orderInputs: ({ parts: 1, goods: 3, robots: 4, exports: 5 })
    readonly property real cap: 50 + storageLevel * 75 + crowns * 25
    readonly property real multiplier: 1 + crowns * 0.20
    readonly property var route: cityProgress.state.route < 0 ? null : Data.products[cityProgress.state.route]
    readonly property var dashboard: lineKeys.map(function(key, i) {
        return { name: tr("line_" + key, lineNames[i]), status: lineStatus(i), details: lineDetails(i) }
    })

    City.CityPreferences { id: preferences }
    City.CityProgress {
        id: cityProgress
        mega: false
        progress: root.crowns
        currency: root.research
        income: root.forecast(-1, 0)
        writable: root.ready && !root.saveBlocked && !root.suspended
        onSpendResearch: function(amount) { root.research -= amount }
        onPayReward: function(amount) { root.coins += amount }
        onChanged: autosaveSoon.restart()
    }

    function tr(key, fallback) {
        if (!GameI18n.language) return fallback
        return GameI18n.text(key, fallback)
    }
    function fmt(value) {
        if (!isFinite(value)) return "∞"
        if (value >= 1e12) return value.toExponential(2)
        if (value >= 1e6) return (value / 1e6).toFixed(1) + "M"
        if (value >= 1e3) return (value / 1e3).toFixed(1) + "K"
        return (Math.round(value * 10) / 10).toString()
    }
    function freshLines() {
        return [0,1,2,3,4,5].map(function() { return {level:1, manager:false, progress:0} })
    }
    function speed(i, additional) {
        var patent = 1 + Data.bonus(cityProgress.state, 0) - Data.overhead(cityProgress.state, 3)
        var routing = i === 4 && route ? route[3] : 1
        var dispatch = i === 5 ? 1 + Data.bonus(cityProgress.state, 2) : 1
        return (0.18 + (lines[i].level + additional) * 0.055) * (1 + efficiencyLevel * 0.08) *
                multiplier * routing * patent * dispatch / (1 + Data.overhead(cityProgress.state, 1))
    }
    function inputCost(i, amount) {
        var routeCost = i === 4 && route ? route[4] : 1
        return amount * routeCost * (1 + Data.overhead(cityProgress.state, 0) +
                                    (i === 5 ? Data.overhead(cityProgress.state, 2) : 0))
    }
    function salePrice(level, factor) {
        return (28 + level * 7) * multiplier * (factor === undefined ? (route ? route[5] : 1) : factor) *
               (1 + Data.bonus(cityProgress.state, 1))
    }
    function outputUnits(i, additional) {
        return Math.max(1, Math.floor((1 + (lines[i].level + additional - 1) * 0.25) * multiplier))
    }
    function lineStatus(i) {
        if (i < 5 && stock[i] >= cap) return 2
        for (var pair of inputs[i]) {
            var result = Data.stockStatus(stock[pair[0]], inputCost(i, pair[1]), cap, cityProgress.state.reserve)
            if (result !== 0) return result
        }
        return lines[i].manager ? 0 : 5
    }
    function lineDetails(i) {
        var needs = inputs[i].map(function(pair) {
            return tr(resourceKeys[pair[0]], resources[pair[0]]) + " " + fmt(stock[pair[0]]) + "/" + fmt(inputCost(i, pair[1]))
        })
        var output = i === 5 ? fmt(salePrice(lines[i].level)) + " " + tr("coins","Coins")
                              : tr(resourceKeys[i], resources[i]) + " " + fmt(stock[i]) + "/" + fmt(cap)
        return (needs.length ? needs.join(" + ") + " → " : "") + output
    }
    function forecast(selected, count) {
        var rates = []
        for (var i = 0; i < 6; i++) {
            var amount = i === selected ? count : 0
            var rate = lines[i].manager ? Math.min(5, speed(i, amount)) : 0
            for (var pair of inputs[i]) rate = Math.min(rate, rates[pair[0]] / inputCost(i, pair[1]))
            rates[i] = rate * (i === 5 ? 1 : outputUnits(i, amount))
        }
        return rates[5] * salePrice(lines[5].level + (selected === 5 ? count : 0))
    }
    function bottleneck() {
        for (var i = 5; i >= 0; i--) if (lineStatus(i) === 2) return i
        for (var j = 0; j < 6; j++) if (lineStatus(j) === 1 || lineStatus(j) === 3) return j
        return selectedLine
    }
    function purchase(i) {
        var limit = buyMode === 0 ? 1024 : buyMode
        var cost = 0
        var count = 0
        while (count < limit) {
            var next = Math.round((40 + i * 50) * Math.pow(1.65, lines[i].level - 1 + count))
            if (!isFinite(next) || cost + next > coins) break
            cost += next
            count++
        }
        return { cost: cost, count: count }
    }
    function replaceLine(i, line) {
        var copy = lines.slice()
        copy[i] = line
        lines = copy
    }
    function buy(i) {
        if (!cityProgress.writable) return
        var quote = purchase(i)
        if (!quote.count) return
        coins -= quote.cost
        replaceLine(i, Object.assign({}, lines[i], {level:lines[i].level + quote.count}))
        buildingLevels = lines.map(function(line) { return line.level })
        GameStats.increment("line_upgrades", quote.count)
        if (lines[i].level >= 10) Achievements.unlock("industrial_line_10")
        if (guideStep === 2) guideStep = 3
        persist()
    }
    function managerCost(i) { return Math.round(250 * Math.pow(2.1, i) * (1 + crowns * 0.1)) }
    function hire(i) {
        var cost = managerCost(i)
        if (!cityProgress.writable || lines[i].manager || coins < cost) return
        coins -= cost
        replaceLine(i, Object.assign({}, lines[i], { manager:true }))
        GameStats.increment("managers_hired")
        if (lines.every(function(line) { return line.manager })) Achievements.unlock("fully_automated")
        persist()
    }
    function nextContract() {
        var kinds = ["goods","robots","parts","exports"]
        var kind = kinds[GameRandom.nextInt(0, kinds.length - 1)]
        var base = kind === "robots" ? 4 : kind === "exports" ? 6 : 12
        var amount = base + GameRandom.nextInt(0, base) + Math.floor(reputation / 12)
        return { kind:kind, amount:amount, progress:0, research:2 + Math.floor(amount / 8),
                 reward:Math.round(amount * (kind === "robots" ? 55 : kind === "exports" ? 38 : 16) * multiplier) }
    }
    function advanceContract(kind, amount) {
        if (contract.kind !== kind) return
        var progress = Math.min(contract.amount, contract.progress + amount)
        if (progress < contract.amount) {
            contract = Object.assign({}, contract, { progress:progress })
            return
        }
        coins += contract.reward
        research += contract.research
        reputation += 3
        GameStats.increment("contracts_completed")
        Achievements.unlock(GameStats.counter("contracts_completed") >= 10 ? "contracts_10" : "first_contract")
        message = tr("city.reward", "Reward: %1").arg(fmt(contract.reward))
        contract = nextContract()
    }
    function produce(i) {
        var status = lineStatus(i)
        if (status !== 0 && status !== 5) return false
        var next = stock.slice()
        var units = i === 5 ? 1 : Math.min(outputUnits(i, 0), cap - next[i])
        if (units <= 0) return false
        for (var pair of inputs[i]) next[pair[0]] = Math.max(0, next[pair[0]] - inputCost(i, pair[1]))
        if (i < 5) next[i] += units
        var oldRobotStock = stock[4]
        stock = next
        var counts = {}
        var dispatch = null
        if (i === 1) { advanceContract("parts", units); counts.components = units }
        if (i === 3 || i === 4) { advanceContract(i === 3 ? "goods" : "robots", units); counts.made = units }
        if (i === 4 && route && route[4] < 1) counts.efficient = units
        if (i === 5) {
            dispatch = Data.dispatchLots(cityProgress.state.routeStock, oldRobotStock, 0, -1, oldRobotStock - next[4])
            coins += salePrice(lines[5].level, dispatch.factor)
            reputation++
            advanceContract("exports", 1)
            GameStats.increment("factory_exports")
            counts.shipped = 1
            if (cityProgress.state.projects[2] >= 2) counts.rail = 1
            var consumed = oldRobotStock - next[4]
            counts.precision = dispatch.families[0] / consumed
            counts.energy = dispatch.families[1] / consumed
            counts.logistics = dispatch.families[2] / consumed
            if (guideStep < 2) guideStep = lines.some(function(line) { return line.level > 1 }) ? 3 : 2
        }
        if (i === 0 && guideStep < 1) guideStep = 1
        if (i === 4 && next[i] >= cap * 0.6) counts.stock = units
        if (i === 4 && route) dispatch = Data.dispatchLots(cityProgress.state.routeStock, oldRobotStock, units, cityProgress.state.route, 0)
        if (dispatch) cityProgress.recordLots(dispatch.lots, counts)
        else cityProgress.record(counts)
        return true
    }
    function manual(i) {
        if (!cityProgress.writable) return
        if (!produce(i)) { message = dashboard[i].details; return }
        GameStats.increment("manual_cycles")
        Haptics.light()
        persist()
    }
    function tick() {
        var order = [0,1,2,3,4,5]
        if (cityProgress.state.priority > 0) {
            var favored = cityProgress.state.priority === 1 ? orderInputs[contract.kind] : 5
            var start = order.indexOf(favored)
            if (start > 0) {
                order.splice(start, 1)
                order.unshift(favored)
            }
        }
        var copy = lines.slice()
        var changed = false
        for (var i of order) {
            if (!copy[i].manager) continue
            var elapsed = copy[i].progress + speed(i, 0) * 0.20
            if (elapsed >= 1) elapsed = produce(i) ? elapsed - 1 : 0.95
            copy[i] = Object.assign({}, copy[i], { progress:Math.min(1, elapsed) })
            changed = true
        }
        if (changed) lines = copy
    }

    function storageCost() { return Math.round(350 * Math.pow(1.8, storageLevel - 1)) }
    function buyStorage() {
        if (!cityProgress.writable || coins < storageCost()) return
        coins -= storageCost()
        storageLevel++
        GameStats.increment("storage_upgrades")
        persist()
    }
    function buyEfficiency() {
        var cost = 5 + efficiencyLevel * 4
        if (!cityProgress.writable || research < cost) return
        research -= cost
        efficiencyLevel++
        GameStats.increment("research_bought")
        persist()
    }
    function prestigeCost() { return 10000 * Math.pow(2, crowns) }
    function prestige() {
        if (!cityProgress.writable || coins < prestigeCost()) return
        if (!confirmPrestige) { confirmPrestige = true; return }
        confirmPrestige = false
        crowns++
        coins = 100
        stock = [0,0,0,0,0]
        research = 0
        storageLevel = 1
        efficiencyLevel = 0
        lines = freshLines()
        buildingLevels = [1,1,1,1,1,1]
        contract = nextContract()
        cityProgress.commit({ route: -1, routeStock: Data.normalize(null).routeStock })
        Achievements.unlock("first_crown")
        GameStats.increment("prestiges")
        message = tr("city.crown_gained","Crown earned · %1").arg(tr("city.district." + cityProgress.district, Data.names[cityProgress.district]))
        persist()
    }
    function settleAway(saved) {
        var elapsed = Math.max(0, Date.now() - saved) / 60000
        var minutes = Math.min(240, elapsed)
        if (elapsed < 1) return
        var earned = lines[5].manager ? minutes * (2 + lines[5].level * 0.7) *
                     multiplier * (1 + Data.bonus(cityProgress.state, 3)) : 0
        coins += earned
        if (earned) GameStats.increment("offline_minutes", Math.floor(minutes))
        offlineText = tr("city.community_offline", "Away %1 min · calculated %2 min · +%3 coins · %4")
                .arg(fmt(elapsed)).arg(fmt(minutes)).arg(fmt(earned))
                .arg(!lines[5].manager ? tr("city.no_manager", "Export Dock needs a manager") :
                     (elapsed > minutes ? tr("city.offline_limit", "Offline time limit") :
                      tr("city.offline_estimate", "Estimated income")))
    }
    function snapshot(now) {
        return { coins:coins, stock:stock, research:research, reputation:reputation, crowns:crowns,
                 storageLevel:storageLevel, efficiencyLevel:efficiencyLevel, lines:lines, contract:contract,
                 timestamp:now, district:cityProgress.state, page:page, selectedLine:selectedLine,
                 selectedZone:selectedZone, buyMode:buyMode, guideStep:guideStep }
    }
    function save() {
        if (!ready || saveBlocked) return
        lastCheckpoint = wentBackground || Date.now()
        GameSave.set("community_v3", snapshot(lastCheckpoint))
    }
    function persist() {
        if (!ready || saveBlocked) return
        save()
        if (!GameSave.save("autosave"))
            message = tr("city.save_error","Save failed: %1").arg(GameSave.lastError)
    }
    function setPage(index) { page = index; confirmPrestige = false; autosaveSoon.restart() }
    function selectLine(index) { selectedLine = index; setPage(0) }
    function selectZone(index) {
        selectedZone = index
        selectedLine = [0,3,2,4,5,4,5][index]
        setPage(Data.layout[index][4])
    }
    function restore(state) {
        function value(key, fallback, cap) { return Data.number(state[key], fallback, cap) }
        coins = value("coins", 100, 1e300)
        research = value("research", 0, 1e300)
        reputation = value("reputation", 0, 1e300)
        crowns = Math.floor(value("crowns", 0, 1e12))
        storageLevel = Math.floor(Math.max(1, value("storageLevel", 1, 1024)))
        efficiencyLevel = Math.floor(value("efficiencyLevel", 0, 1000000))
        stock = Array.isArray(state.stock) && state.stock.length === 5 ?
                    state.stock.map(function(n) { return Data.number(n, 0, cap) }) : [0,0,0,0,0]
        if (Array.isArray(state.lines) && state.lines.length === 6)
            lines = state.lines.map(function(line) {
                return { level:Math.max(1, Data.level(line && line.level, 1000000)),
                         manager:!!(line && line.manager), progress:Data.number(line && line.progress, 0, 1) }
            })
        buildingLevels = lines.map(function(line) { return line.level })
        var savedOrder = state.contract
        if (savedOrder && orderInputs[savedOrder.kind] !== undefined) {
            var target = Math.max(1, Data.number(savedOrder.amount, 10, 1e300))
            contract = { kind:savedOrder.kind, amount:target, progress:Data.number(savedOrder.progress, 0, target),
                         reward:Data.number(savedOrder.reward, 120, 1e300), research:Data.number(savedOrder.research, 2, 1e300) }
        }
        cityProgress.restore(state.district)
        page = Data.level(state.page, 4)
        selectedLine = Data.level(state.selectedLine, 5)
        selectedZone = state.selectedZone === -1 ? -1 : Data.level(state.selectedZone, 6)
        buyMode = state.buyMode === 0 || state.buyMode === 10 ? state.buyMode : 1
        guideStep = Data.level(state.guideStep, 3)
        settleAway(value("timestamp", Date.now(), 1e16))
    }
    function initialize() {
        if (ready || GameSave.gameId !== "pocket_factory_community") return
        GameSave.registerMigration(2, 3, function(old) {
            old.community_v3 = { coins:old.coins, stock:[old.ore, old.parts, old.circuits, old.goods, old.robots],
                                 research:old.research, reputation:old.reputation, crowns:old.crowns,
                                 storageLevel:old.storageLevel, efficiencyLevel:old.efficiencyLevel, lines:old.lines,
                                 contract:old.contract, timestamp:old.lastPersistMs, selectedZone:-1, guideStep:3 }
            return old
        })
        if (GameSave.load("autosave")) {
            var state = GameSave.get("community_v3", null)
            if (state && typeof state === "object") restore(state)
            else saveBlocked = true
        } else if (GameSave.hasStoredSlot("autosave")) {
            saveBlocked = true
        } else {
            contract = nextContract()
        }
        ready = true
        if (saveBlocked) message = tr("city.load_error","Existing save could not be loaded: %1").arg(GameSave.lastError)
        else persist()
    }
    function load() { initialize() }
    function start() { initialize() }
    function pause() { suspended = true }
    function resume() { if (!wentBackground) suspended = false }
    function background() {
        if (wentBackground) return
        wentBackground = Date.now()
        suspended = true
        persist()
    }
    function foreground() {
        var saved = wentBackground
        wentBackground = 0
        suspended = false
        if (saved && ready && !saveBlocked) {
            settleAway(saved)
            persist()
        }
    }

    Component.onCompleted: Qt.callLater(initialize)
    Connections { target: GameSave; function onGameChanged() { root.initialize() } }
    Timer { interval: 200; repeat: true; running: cityProgress.writable; onTriggered: root.tick() }
    Timer { interval: 10000; repeat: true; running: cityProgress.writable; onTriggered: root.persist() }
    Timer { id: autosaveSoon; interval: 450; onTriggered: root.persist() }

    CommunityView {
        anchors.fill: parent
        game: root
        city: cityProgress
        prefs: preferences
    }
}
