import QtQuick
import "city" as City
import "city/CityData.js" as Data

Item {
    id: root
    required property var game
    required property var city
    required property var prefs
    readonly property bool compact: width < 680
    readonly property var titles: ["Factory","Research","Contracts","Progress","Settings and help"]

    function t(key, fallback) { return game.tr("city." + key, fallback) }
    function fmt(value) { return game.fmt(value) }
    function translate(key, fallback) { return game.tr(key, fallback) }

    Rectangle { anchors.fill: parent; color: GameTheme.color("alias.page.background.normal") }

    Component {
        id: navComponent
        Row {
            height: root.compact ? 56 : 48
            spacing: 4
            Repeater {
                model: root.titles
                delegate: City.CityButton {
                    required property int index
                    required property string modelData
                    width: (parent.width - 16) / 5
                    height: parent.height
                    text: root.compact && index === 4 ? "⚙" : root.t("tab." + index, modelData)
                    Accessible.name: root.t("tab." + index, modelData)
                    primary: root.game.page === index
                    onActivated: root.game.setPage(index)
                }
            }
        }
    }

    Loader {
        id: topNav
        anchors.top: parent.top
        anchors.topMargin: Math.max(0, Viewport.safeTop)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        visible: active
        active: !root.compact
        sourceComponent: navComponent
    }
    Loader {
        id: bottomNav
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(0, Viewport.safeBottom)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        visible: active
        active: root.compact
        sourceComponent: navComponent
    }
    City.FactoryHud {
        id: hud
        z: 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        y: Math.max(0, Viewport.safeTop) + (topNav.active ? topNav.height + 6 : 0)
        height: implicitHeight
        translate: root.translate
        line: root.game.dashboard[root.game.bottleneck()]
        balance: root.t("community_hud", "%1 coins · estimated %2 coins/s")
            .arg(root.fmt(root.game.coins)).arg(root.fmt(root.game.forecast(-1, 0)))
    }
    Flickable {
        id: scroll
        anchors.fill: parent
        anchors.topMargin: hud.y + hud.height + 4
        anchors.bottomMargin: Math.max(0, Viewport.safeBottom) + (bottomNav.active ? bottomNav.height + 8 : 0)
        clip: true
        contentWidth: width
        contentHeight: body.implicitHeight + 24
        boundsBehavior: Flickable.StopAtBounds
        Connections { target: root.game; function onPageChanged() { scroll.contentY = 0 } }

        Column {
            id: body
            width: Math.max(1, Math.min(1100, scroll.width - 24))
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            spacing: 10
            City.CityText {
                width: parent.width; heading: true
                text: root.t("community_title", "Pocket Factory Community")
            }
            City.CityText {
                width: parent.width
                visible: root.game.page !== 0
                text: root.t("community_balance", "%1 coins · %2 research").arg(root.fmt(root.game.coins)).arg(root.fmt(root.game.research))
            }
            City.CityText {
                width: parent.width
                visible: text.length > 0
                text: root.game.message
                Accessible.ignored: !visible
            }
            City.CityButton {
                visible: root.game.page === 0 && root.game.guideStep === 0
                width: parent.width
                primary: true
                enabled: root.city.writable
                text: root.t("guide_mine","Run the ore drill to start the line.")
                onActivated: root.game.manual(0)
            }
            City.CityPanel {
                width: parent.width
                page: root.game.page
                city: root.city
                prefs: root.prefs
                translate: root.translate
                format: root.fmt
                currencyName: root.t("research_currency", "research")
                lines: root.game.dashboard
                buildingLevels: root.game.buildingLevels
                researchLevel: root.game.efficiencyLevel
                selectedLine: root.game.selectedLine
                selectedZone: root.game.selectedZone
                bottleneck: root.game.bottleneck()
                paused: root.game.suspended
                offlineSummary: root.game.offlineText
                onZoneSelected: function(zone) { root.game.selectZone(zone) }
                onLineSelected: function(line) { root.game.selectLine(line); scroll.contentY = Math.max(0, lineCard.y - 6) }
            }
            Column {
                id: lineCard
                width: parent.width
                visible: root.game.page === 0
                spacing: 7
                readonly property int line: root.game.selectedLine
                readonly property var quote: root.game.purchase(line)
                readonly property real delta: Math.max(0, root.game.forecast(line, quote.count) - root.game.forecast(-1, 0))
                City.CityText {
                    width: parent.width
                    visible: root.game.guideStep < 3
                    text: [root.t("guide_mine","Run the ore drill to start the line."),
                           root.t("guide_sale","Follow the arrows through the six lines and run the Export Dock for your first sale."),
                           root.t("guide_expand","Upgrade a line to expand its building.")][Math.min(root.game.guideStep, 2)]
                }
                City.CityText { width: parent.width; heading: true; text: root.game.dashboard[lineCard.line].name }
                City.CityText { width: parent.width; text: root.game.lineDetails(lineCard.line) }
                Flow {
                    width: parent.width
                    spacing: 5
                    Repeater {
                        model: [1,10,0]
                        delegate: City.CityButton {
                            required property int modelData
                            text: modelData === 0 ? root.t("max_buy", "Max") : "×" + modelData
                            primary: root.game.buyMode === modelData
                            onActivated: root.game.buyMode = modelData
                        }
                    }
                }
                City.CityText {
                    width: parent.width
                    text: root.t("quote","%1 upgrades · %2 coins · +%3 coins/s")
                        .arg(lineCard.quote.count).arg(root.fmt(lineCard.quote.cost)).arg(root.fmt(lineCard.delta)) +
                        (lineCard.delta > 0 ? " · " + root.t("payback", "Payback: %1 s").arg(root.fmt(lineCard.quote.cost / lineCard.delta)) : "")
                }
                Flow {
                    width: parent.width; spacing: 6
                    City.CityButton {
                        text: root.t("run","Run line")
                        primary: true
                        enabled: root.city.writable && [0,5].indexOf(root.game.lineStatus(lineCard.line)) >= 0
                        onActivated: root.game.manual(lineCard.line)
                    }
                    City.CityButton {
                        text: root.t("buy_upgrade","Buy upgrades")
                        enabled: root.city.writable && lineCard.quote.count > 0
                        onActivated: root.game.buy(lineCard.line)
                    }
                    City.CityButton {
                        text: root.game.lines[lineCard.line].manager ? root.t("hired","Manager hired") :
                             root.t("hire","Hire manager · %1 coins").arg(root.fmt(root.game.managerCost(lineCard.line)))
                        enabled: root.city.writable && !root.game.lines[lineCard.line].manager &&
                                 root.game.coins >= root.game.managerCost(lineCard.line)
                        onActivated: root.game.hire(lineCard.line)
                    }
                }
            }
            City.CityButton {
                visible: root.game.page === 0
                text: root.t("storage","Upgrade storage · %1 coins").arg(root.fmt(root.game.storageCost()))
                enabled: root.city.writable && root.game.coins >= root.game.storageCost()
                onActivated: root.game.buyStorage()
            }
            City.CityButton {
                visible: root.game.page === 1
                text: root.t("efficiency","Research efficiency · %1 research").arg(5 + root.game.efficiencyLevel * 4)
                enabled: root.city.writable && root.game.research >= 5 + root.game.efficiencyLevel * 4
                onActivated: root.game.buyEfficiency()
            }
            City.CityText {
                width: parent.width; visible: root.game.page === 2
                text: root.t("regular_contract","Regular contract · %1 · %2/%3")
                     .arg(root.t("contract." + root.game.contract.kind, root.game.contract.kind))
                     .arg(root.fmt(root.game.contract.progress)).arg(root.fmt(root.game.contract.amount))
            }
            City.CityText {
                width: parent.width; visible: root.game.page === 3
                text: root.t("crowns","Crowns: %1").arg(root.fmt(root.game.crowns))
            }
            City.CityText {
                width: parent.width; visible: root.game.page === 3 && root.game.confirmPrestige
                text: root.t("reset_crown","Resets coins, stock, research, efficiency, storage and lines. Keeps Crowns, reputation, patents and district projects.")
            }
            Flow {
                visible: root.game.page === 3
                width: parent.width; spacing: 6
                City.CityButton {
                    primary: root.game.confirmPrestige
                    enabled: root.city.writable && root.game.coins >= root.game.prestigeCost()
                    text: root.game.confirmPrestige ? root.t("confirm_reset","Confirm prestige") :
                            root.t("prestige_cost","Earn a Crown · %1 coins").arg(root.fmt(root.game.prestigeCost()))
                    onActivated: root.game.prestige()
                }
                City.CityButton {
                    visible: root.game.confirmPrestige
                    text: root.t("cancel","Cancel")
                    onActivated: root.game.confirmPrestige = false
                }
            }
            City.CityText {
                width: parent.width; visible: root.game.page === 4
                text: root.t("help","Select a production line to see its inputs and outputs. On the map, select a district to open its controls.")
            }
            City.CityButton {
                visible: root.game.page === 4
                text: root.t("save_now","Save now")
                enabled: root.city.writable
                onActivated: root.game.persist()
            }
        }
    }
}
