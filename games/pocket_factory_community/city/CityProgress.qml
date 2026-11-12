import QtQuick
import "CityData.js" as Data

QtObject {
    id: root
    objectName: "factoryProgress"
    required property bool mega
    required property real progress
    required property real currency
    required property real income
    property bool writable: false
    property var state: Data.normalize(null)
    readonly property int district: Data.districtFor(state, progress, mega)

    signal spendResearch(real amount)
    signal payReward(real amount)
    signal changed()

    onProgressChanged: {
        if (writable && Data.districtFor(state, progress, mega) > state.district)
            commit({})
    }

    function restore(value) {
        var next = Data.normalize(value)
        next.district = Data.districtFor(next, progress, mega)
        state = next
    }

    function commit(patch) {
        if (!writable) return
        var next = Object.assign({}, state, patch)
        next.district = Data.districtFor(next, progress, mega)
        state = next
        changed()
    }

    function patentCost(family) {
        var tier = state.patents[family]
        return tier >= 3 ? 0 : Data.patentCosts[mega ? 1 : 0][tier]
    }

    function canPatent(family) {
        var tier = state.patents[family]
        return writable && tier < 3 && district >= tier && currency >= patentCost(family)
    }

    function buyPatent(family) {
        if (!canPatent(family)) return
        var levels = state.patents.slice()
        levels[family] += 1
        spendResearch(patentCost(family))
        commit({ patents: levels })
    }

    function equip(family) {
        if (!writable || !state.patents[family]) return
        var list = state.equipped.slice()
        var index = list.indexOf(family)
        if (index >= 0) list.splice(index, 1)
        else if (list.length < 2) list.push(family)
        else return
        commit({ equipped: list })
    }

    function canRoute(index) {
        return writable && district >= Data.products[index][2] &&
                currency >= Data.routeCost(index, mega)
    }

    function selectRoute(index) {
        if (!writable) return
        var list = state.unlocked.slice()
        if (index !== -1 && list.indexOf(index) === -1) {
            if (!canRoute(index)) return
            spendResearch(Data.routeCost(index, mega))
            list.push(index)
        }
        commit({ unlocked: list, route: index })
    }

    function projectCost(index) {
        return Data.projectCost(index, state.projects[index], mega)
    }

    function canProject(index) {
        return writable && state.projects[index] < 3 && currency >= projectCost(index) &&
                Data.projectReady(state, index, progress, mega)
    }

    function buildPhase(index) {
        if (!canProject(index)) return
        var phases = state.projects.slice()
        phases[index] += 1
        spendResearch(projectCost(index))
        commit({ projects: phases })
    }

    function acceptOrder(index) {
        if (!writable || state.order || state.completed.indexOf(index) !== -1 ||
                district < Data.orders[index][1]) return
        commit({ order: Data.orderOffer(index, district, income) })
    }

    function recordLots(lots, counts) {
        if (!writable) return
        var different = state.routeStock.some(function(n, i) { return n !== lots[i] })
        var order = Data.orderProgress(state.order, counts)
        if (different || order !== state.order) commit({ routeStock: lots, order: order })
    }

    function record(counts) {
        if (!writable || !state.order) return
        var next = Data.orderProgress(state.order, counts)
        if (next !== state.order) commit({ order: next })
    }

    function claim() {
        var order = state.order
        if (!writable || !order || order.stage !== Data.orders[order.id][2].length) return
        payReward(order.reward)
        commit({ order: null, completed: state.completed.concat([order.id]) })
    }
}
