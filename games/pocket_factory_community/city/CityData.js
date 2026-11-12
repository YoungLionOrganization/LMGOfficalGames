.pragma library

var thresholds = [[0, 1, 3, 6, 12], [0, 10, 100, 1000, 100000]]
var names = ["Workshop", "Factory", "Industrial campus", "Megafactory", "Factory city"]
var families = ["Production", "Quality", "Logistics", "Automation"]
var patents = ["Precision Die", "Servo Cell", "Modular Line", "Measurement Bench", "Traceable Batch",
               "Automatic Inspection", "Smart Rack", "Rail Transfer", "Dispatch Hub", "Smart Sensor",
               "Shift Control", "Autonomous Cell"]
var patentCosts = [[6, 20, 60], [8, 40, 160]]
var zones = ["Materials yard", "Production halls", "Research campus", "Warehouse",
             "Rail logistics", "Energy and recycling", "City center"]
// World coordinates in a fixed 960 by 540 plan. New districts never move old ones.
var layout = [[150, 224, 0, 0, 0], [353, 190, 0, 0, 0], [505, 111, 2, 1, 1],
              [487, 321, 0, 2, 0], [710, 300, 1, 2, 2], [234, 410, 3, 3, 3], [770, 125, 4, 3, 3]]
var projects = ["Central Laboratory", "Smart Warehouse", "Freight Station", "Circular Energy Plant", "City Center"]
var projectZones = [2, 3, 4, 5, 6]
var phases = ["Foundation", "Commissioning", "Specialization"]
var priorities = ["Balanced", "Contract", "Shipping"]
var modes = ["Off", "Low", "Full"]
var reserves = [0, 0.10, 0.25]
var statuses = ["Running", "Waiting for input", "Storage full", "Reserved input", "Locked", "Manual"]
var products = [
    ["die_sets", "Precision die sets", 1, 0.90, 1.15, 1.22],
    ["calipers", "Digital calipers", 1, 0.78, 0.95, 1.17],
    ["bearings_4", "Ceramic bearings", 2, 1.15, 1.28, 1.08],
    ["tooling_4", "Modular toolheads", 3, 0.82, 1.25, 1.42],
    ["relays_4", "Industrial relays", 1, 1.10, 1.22, 1.00],
    ["storage_cells", "Storage cells", 2, 0.86, 1.10, 1.25],
    ["inverters", "Grid inverters", 2, 0.80, 1.30, 1.48],
    ["grid_modules", "Grid control modules", 3, 0.68, 1.42, 1.82],
    ["pallets_4", "Smart pallets", 1, 1.20, 1.17, 0.95],
    ["rail_kit", "Rail coupler kits", 2, 1.00, 1.15, 1.24],
    ["cargo_robot", "Cargo robots", 3, 0.74, 1.35, 1.65],
    ["dispatch_node", "Dispatch nodes", 4, 0.64, 1.50, 2.00]
]
var orders = [
    ["Sample batch", 0, ["made", "shipped"]],
    ["Series production", 1, ["components", "made", "shipped"]],
    ["Input efficiency", 1, ["efficient", "shipped"]],
    ["Precision product", 2, ["precision", "shipped"]],
    ["Stock buffer", 2, ["stock", "shipped"]],
    ["Rail dispatch", 2, ["rail", "shipped"]],
    ["Multi-product delivery", 3, ["precision", "energy", "logistics"]],
    ["City infrastructure", 4, ["energy", "logistics", "rail"]]
]
var events = ["made", "shipped", "components", "efficient", "precision", "stock", "rail", "energy", "logistics"]

function number(value, fallback, max) {
    return typeof value === "number" && isFinite(value) && value >= 0 ? Math.min(value, max) : fallback
}

function level(value, max) {
    return Math.floor(number(value, 0, max))
}

function normalize(value) {
    var old = value && typeof value === "object" ? value : {}
    var state = { patents: [], equipped: [], projects: [], unlocked: [], route: -1,
                  priority: level(old.priority, 2), reserve: level(old.reserve, 2),
                  district: level(old.district, 4), order: null, completed: [], routeStock: [] }
    for (var i = 0; i < 4; ++i) {
        state.patents.push(level(old.patents && old.patents[i], 3))
        if (state.patents[i] && Array.isArray(old.equipped) && old.equipped.indexOf(i) !== -1 &&
                state.equipped.length < 2) state.equipped.push(i)
    }
    for (var p = 0; p < 5; ++p) state.projects.push(level(old.projects && old.projects[p], 3))
    for (var r = 0; r < products.length; ++r) {
        if (Array.isArray(old.unlocked) && old.unlocked.indexOf(r) !== -1) state.unlocked.push(r)
        state.routeStock.push(number(old.routeStock && old.routeStock[r], 0, 1e300))
    }
    if (state.unlocked.indexOf(old.route) !== -1) state.route = old.route
    for (var o = 0; o < orders.length; ++o) {
        if (Array.isArray(old.completed) && old.completed.indexOf(o) !== -1) state.completed.push(o)
    }
    var order = old.order
    if (order && Number.isInteger(order.id) && order.id >= 0 && order.id < orders.length &&
            state.completed.indexOf(order.id) === -1) {
        var steps = orders[order.id][2].length
        var stage = level(order.stage, steps)
        var target = Math.max(1, number(order.target, 1, 1e12))
        state.order = { id: order.id, stage: stage, target: target,
                        progress: number(order.progress, 0, target), reward: number(order.reward, 0, 1e15) }
    }
    return state
}

function districtFor(state, progress, mega) {
    var cuts = thresholds[mega ? 1 : 0]
    var rank = 0
    for (var i = 1; i < cuts.length; ++i) {
        if (progress >= cuts[i] && (i !== 4 || state.projects[4] === 3)) rank = i
    }
    return Math.max(rank, state.district)
}

function bonus(state, family) {
    return state.equipped.indexOf(family) >= 0 ? state.patents[family] * 0.05 : 0
}

function overhead(state, family) {
    return state.equipped.indexOf(family) >= 0 ? state.patents[family] * 0.02 : 0
}

function routeCost(index, mega) {
    return (mega ? 12 : 8) * (products[index][2] + 1) + (index % 4) * 3
}

function projectCost(index, phase, mega) {
    return (mega ? 15 : 10) * (index + 1) * (phase + 1)
}

function projectReady(state, index, progress, mega) {
    if (index === 4)
        return progress >= thresholds[mega ? 1 : 0][4] && state.projects.slice(0, 4).every(function(n) { return n === 3 })
    return districtFor(state, progress, mega) >= [1, 1, 2, 3][index]
}

function orderOffer(index, district, income) {
    var target = 4 * Math.pow(3, district) * (1 + index)
    var reward = Math.max(100, Math.round(income * 30)) * (district + 1) * (index + 2)
    return { id: index, stage: 0, target: target, progress: 0, reward: Math.min(1e15, reward) }
}

function orderProgress(order, counts) {
    if (!order) return null
    var steps = orders[order.id][2]
    if (order.stage >= steps.length) return order
    var amount = number(counts[steps[order.stage]], 0, 1e12)
    if (!amount) return order
    var progress = order.progress + amount
    return { id: order.id, stage: progress >= order.target ? order.stage + 1 : order.stage,
             target: order.target, progress: progress >= order.target ? 0 : progress, reward: order.reward }
}

function stockStatus(stock, needed, capacity, reserve) {
    if (stock + 0.000001 < needed) return 1
    if (stock + 0.000001 < needed + capacity * reserves[reserve]) return 3
    return 0
}

function available(stock, capacity, reserve) {
    return Math.max(0, stock - capacity * reserves[reserve])
}

// Keep specialist products attached to actual stored output after a route change.
function dispatchLots(saved, total, produced, route, consumed) {
    var lots = saved.slice()
    var stored = 0
    for (var i = 0; i < lots.length; ++i) {
        lots[i] = Math.max(0, Math.min(lots[i], total - stored))
        stored += lots[i]
    }
    if (route >= 0) lots[route] += produced
    var standard = Math.max(0, total - stored) + (route < 0 ? produced : 0)
    var remaining = Math.max(0, consumed - standard)
    var weighted = Math.min(consumed, standard)
    var families = [0, 0, 0]
    for (var j = 0; j < lots.length && remaining > 0.000000001; ++j) {
        var take = Math.min(lots[j], remaining)
        lots[j] -= take
        remaining -= take
        weighted += take * products[j][5]
        families[Math.floor(j / 4)] += take
    }
    return { lots: lots, factor: consumed > 0 ? weighted / consumed : 1, families: families }
}
