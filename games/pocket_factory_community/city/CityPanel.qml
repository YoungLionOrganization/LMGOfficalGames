import QtQuick
import "CityData.js" as Data

Column {
    id: root
    required property int page
    required property var city
    required property var prefs
    required property var translate
    required property var format
    property var lines: []
    property var buildingLevels: []
    property int researchLevel: 0
    property string currencyName
    property string offlineSummary
    property int selectedZone: -1
    property int selectedLine: 0
    property int bottleneck: 0
    property bool paused: false
    property bool interactive: true
    signal zoneSelected(int zone)
    signal lineSelected(int line)
    spacing: 8

    function t(key, fallback) { return translate("city." + key, fallback) }
    function status(code) {
        return ["●","◷","▤","◆","○","▷"][code] + " " + t("status." + code, Data.statuses[code])
    }
    function cost(value) { return format(value) + " " + currencyName }
    function zoneName(index) { return t("zone." + index, Data.zones[index]) }
    function eventName(name) { return t("event." + name, ({
        made: "Finished products", shipped: "Shipments", components: "Components",
        efficient: "Efficient batches", precision: "Precision products", stock: "Stored products",
        rail: "Rail shipments", energy: "Energy products", logistics: "Logistics products"
    })[name]) }

    CityText { width: parent.width; heading: true; text: root.t("district." + root.city.district, Data.names[root.city.district]); visible: root.page === 0 }
    CityText { width: parent.width; text: root.offlineSummary; visible: root.page === 0 && text.length > 0 }
    Row {
        width: parent.width
        visible: root.page === 0
        spacing: 10
        readonly property bool wide: width >= 690 && scene.active
        Loader {
            id: scene
            objectName: "factorySceneLoader"
            width: parent.wide ? (parent.width - 10) * 0.65 : parent.width
            height: active ? Math.min(340, Math.max(220, width * 0.57)) : 0
            active: root.page === 0 && root.prefs.mode !== 0
            visible: active
            sourceComponent: FactoryScene {
                city: root.city
                prefs: root.prefs
                lines: root.lines
                buildingLevels: root.buildingLevels
                researchLevel: root.researchLevel
                translate: root.translate
                selectedZone: root.selectedZone
                paused: root.paused
                onZoneSelected: function(zone) { root.zoneSelected(zone) }
            }
        }
        Column {
            visible: parent.wide
            width: parent.wide ? parent.width - scene.width - 10 : 0
            spacing: 5
            CityText { width: parent.width; heading: true; text: root.t("districts", "Factory districts") }
            Repeater {
                model: root.page === 0 && parent.visible ? Data.layout : []
                delegate: CityButton {
                    required property int index
                    required property var modelData
                    width: parent.width
                    visible: modelData[2] <= root.city.district || root.city.state.projects[Data.projectZones.indexOf(index)] > 0
                    text: root.zoneName(index)
                    primary: root.selectedZone === index
                    onActivated: root.zoneSelected(index)
                }
            }
        }
    }
    Flow {
        width: parent.width
        visible: root.page === 0 && (width < 690 || root.prefs.mode === 0)
        spacing: 5
        Repeater {
            model: root.page === 0 && (root.width < 690 || root.prefs.mode === 0) ? Data.layout : []
            delegate: CityButton {
                required property int index
                required property var modelData
                visible: modelData[2] <= root.city.district || root.city.state.projects[Data.projectZones.indexOf(index)] > 0
                text: root.zoneName(index)
                onActivated: root.zoneSelected(index)
            }
        }
    }
    CityButton {
        width: parent.width
        visible: root.page === 0 && root.lines.length > 0
        text: {
            var line = root.lines[root.bottleneck]
            return line ? root.t("bottleneck", "Inspect bottleneck: %1 · %2").arg(line.name).arg(root.status(line.status)) : ""
        }
        onActivated: root.lineSelected(root.bottleneck)
    }
    CityText {
        width: parent.width
        visible: root.page === 0 && root.lines.length > 0
        text: {
            var line = root.lines[root.selectedLine]
            return line ? root.t("line_status", "%1 · %2\n%3").arg(line.name).arg(root.status(line.status)).arg(line.details) : ""
        }
    }
    Flow {
        width: parent.width
        visible: root.page === 0
        spacing: 6
        Repeater {
            model: root.page === 0 ? root.lines.length : 0
            delegate: CityButton {
                required property int index
                text: root.lines[index].name
                primary: root.selectedLine === index
                onActivated: root.lineSelected(index)
            }
        }
    }
    CityText { width: parent.width; heading: true; visible: root.page === 1; text: root.t("patents", "Permanent patents") }
    Repeater {
        model: root.page === 1 ? Data.families : []
        delegate: Column {
            required property int index
            required property string modelData
            width: parent.width
            spacing: 4
            readonly property int tier: root.city.state.patents[index]
            readonly property bool equipped: root.city.state.equipped.indexOf(index) >= 0
            CityText {
                width: parent.width
                text: root.t("family." + parent.index, parent.modelData) + " · " + parent.tier + "/3"
            }
            Flow {
                width: parent.width; spacing: 5
                CityButton {
                    text: {
                        var n = parent.parent.index * 3 + parent.parent.tier
                        return parent.parent.tier >= 3 ? root.t("max", "Complete")
                              : root.t("patent." + n, Data.patents[n]) + " · " + root.cost(root.city.patentCost(parent.parent.index))
                    }
                    enabled: root.city.canPatent(parent.parent.index)
                    onActivated: root.city.buyPatent(parent.parent.index)
                }
                CityButton {
                    enabled: root.city.writable && parent.parent.tier > 0 && (parent.parent.equipped || root.city.state.equipped.length < 2)
                    text: parent.parent.equipped ? root.t("unequip", "Deactivate") : root.t("equip", "Activate")
                    primary: parent.parent.equipped
                    onActivated: root.city.equip(parent.parent.index)
                }
            }
        }
    }
    CityText { width: parent.width; heading: true; visible: root.page === 1; text: root.t("routes", "Production routes") }
    CityButton {
        visible: root.page === 1
        text: root.t("standard", "Standard production")
        primary: root.city.state.route === -1
        enabled: root.city.writable
        onActivated: root.city.selectRoute(-1)
    }
    ListView {
        visible: root.page === 1
        width: parent.width
        height: visible ? 275 : 0
        clip: true
        reuseItems: true
        model: visible ? Data.products : []
        delegate: CityButton {
            required property int index
            required property var modelData
            width: ListView.view.width
            text: root.t("product." + index, modelData[1]) + " · " +
                  root.t("route_stats", "Speed ×%1, input ×%2, value ×%3").arg(modelData[3]).arg(modelData[4]).arg(modelData[5]) +
                  (root.city.state.unlocked.indexOf(index) >= 0 ? "" : " · " + root.cost(Data.routeCost(index, root.city.mega)))
            primary: root.city.state.route === index
            enabled: root.city.writable && (root.city.state.unlocked.indexOf(index) >= 0 || root.city.canRoute(index))
            onActivated: root.city.selectRoute(index)
        }
    }
    CityText { width: parent.width; heading: true; visible: root.page === 2; text: root.t("orders", "Industrial orders") }
    Repeater {
        model: root.page === 2 ? Data.orders : []
        delegate: Column {
            id: orderCard
            required property int index
            required property var modelData
            readonly property var order: root.city.state.order
            readonly property bool active: !!order && order.id === index
            readonly property bool finished: root.city.state.completed.indexOf(index) >= 0
            readonly property bool ready: active && order.stage >= modelData[2].length
            readonly property var offer: active ? order : Data.orderOffer(index, root.city.district, root.city.income)
            width: parent.width
            spacing: 4
            CityText {
                width: parent.width
                text: root.t("order." + orderCard.index, orderCard.modelData[0]) + " · " +
                      (orderCard.finished || orderCard.ready ? root.t("max", "Complete") :
                      (orderCard.active ? root.eventName(orderCard.modelData[2][orderCard.order.stage]) +
                        " " + root.format(orderCard.order.progress) + "/" + root.format(orderCard.order.target)
                       : orderCard.modelData[2].map(root.eventName).join(" → ") + " · " + root.format(orderCard.offer.target))) +
                      (orderCard.finished ? "" : " · " + root.t("reward", "Reward: %1").arg(root.format(orderCard.offer.reward)))
            }
            CityButton {
                visible: !orderCard.finished && (!orderCard.order || orderCard.active)
                enabled: root.city.writable && (orderCard.ready || (!orderCard.order && root.city.district >= orderCard.modelData[1]))
                text: orderCard.ready ? root.t("claim", "Claim reward") : root.t("accept", "Accept order")
                onActivated: orderCard.ready ? root.city.claim() : root.city.acceptOrder(orderCard.index)
            }
        }
    }
    CityText { width: parent.width; heading: true; visible: root.page === 3; text: root.t("projects", "District projects") }
    Repeater {
        model: root.page === 3 ? Data.projects : []
        delegate: CityButton {
            required property int index
            required property string modelData
            readonly property int phase: root.city.state.projects[index]
            width: parent.width
            enabled: root.city.canProject(index)
            text: root.t("project." + index, modelData) + " · " + phase + "/3 · " +
                  (phase === 3 ? root.t("max", "Complete") :
                    root.t("phase." + phase, Data.phases[phase]) + " · " + root.cost(root.city.projectCost(index)))
            onActivated: root.city.buildPhase(index)
        }
    }
    CityText { width: parent.width; heading: true; visible: root.page === 0; text: root.t("priority", "Production priority") }
    Flow {
        visible: root.page === 0; width: parent.width; spacing: 5
        Repeater {
            model: root.page === 0 ? Data.priorities : []
            delegate: CityButton {
                required property int index
                required property string modelData
                text: root.t("priority." + index, modelData)
                enabled: root.city.writable
                primary: root.city.state.priority === index
                onActivated: root.city.commit({ priority: index })
            }
        }
    }
    Flow {
        visible: root.page === 0; width: parent.width; spacing: 5
        Repeater {
            model: root.page === 0 ? Data.reserves : []
            delegate: CityButton {
                required property int index
                required property real modelData
                text: root.t("reserve", "Reserve %1%").arg(modelData * 100)
                enabled: root.city.writable
                primary: root.city.state.reserve === index
                onActivated: root.city.commit({ reserve: index })
            }
        }
    }
    CityText { visible: root.page === 4; width: parent.width; heading: true; text: root.t("scene", "Factory scene") }
    Flow {
        visible: root.page === 4; width: parent.width; spacing: 5
        Repeater {
            model: root.page === 4 ? Data.modes : []
            delegate: CityButton {
                required property int index
                required property string modelData
                text: root.t("mode." + index, modelData)
                primary: root.prefs.mode === index
                onActivated: root.prefs.set("factoryScene", index)
            }
        }
        CityButton {
            text: root.t("motion", "Reduced motion")
            primary: root.prefs.reducedMotion
            onActivated: root.prefs.set("reducedMotion", !root.prefs.reducedMotion)
        }
        CityButton {
            text: root.t("flow", "Show production flow")
            primary: root.prefs.showFlow
            onActivated: root.prefs.set("factoryShowFlow", !root.prefs.showFlow)
        }
    }
}
