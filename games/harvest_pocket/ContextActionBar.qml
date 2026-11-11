import QtQuick

UiPanel {
    id: root

    property bool compact: false
    property url cropIcon
    property string cropName: ""
    property string seedInfo: ""
    property string buyText: ""
    property string buySubText: ""
    property string fertilizeText: ""
    property string fertilizerInfo: ""
    property string harvestText: ""
    property string harvestInfo: ""
    property string nextDayText: ""
    property string nextDaySubText: ""
    property bool canBuySeed: true
    property bool canFertilize: true
    property bool harvestVisible: false
    property bool canHarvest: false
    property bool warningArmed: false
    property bool transitionRunning: false

    signal buySeed()
    signal fertilize()
    signal harvest()
    signal nextDay()

    implicitHeight: actionFlow.implicitHeight + 12
    surfaceToken: "surface.control"

    Flow {
        id: actionFlow
        anchors.fill: parent
        anchors.margins: 6
        spacing: 5

        Item {
            width: root.compact ? actionFlow.width : Math.min(230, Math.max(150, actionFlow.width * 0.24))
            height: 46
            Row {
                anchors.fill: parent
                spacing: 7
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    source: root.cropIcon
                    fillMode: Image.PreserveAspectFit
                    cache: true
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(80, parent.width - 41)
                    spacing: 1
                    UiText { width: parent.width; text: root.cropName; font.bold: true; maximumLineCount: 1; elide: Text.ElideRight }
                    UiText { width: parent.width; text: root.seedInfo; sizeToken: "metric.font.xs"; colorToken: "color.textMuted"; maximumLineCount: 1; elide: Text.ElideRight }
                }
            }
        }

        IconButton {
            width: root.compact ? Math.max(132, (actionFlow.width - actionFlow.spacing) / 2) : Math.min(210, implicitWidth)
            compact: true
            iconSource: Qt.resolvedUrl("assets/ui/seed.svg")
            text: root.buyText
            subText: root.buySubText
            enabled: root.canBuySeed
            onActivated: root.buySeed()
        }
        IconButton {
            width: root.compact ? Math.max(132, (actionFlow.width - actionFlow.spacing) / 2) : Math.min(210, implicitWidth)
            compact: true
            iconSource: Qt.resolvedUrl("assets/ui/fertilizer.svg")
            text: root.fertilizeText
            subText: root.fertilizerInfo
            enabled: root.canFertilize
            onActivated: root.fertilize()
        }
        IconButton {
            visible: root.harvestVisible
            width: root.compact ? actionFlow.width : Math.min(210, implicitWidth)
            compact: true
            primary: true
            iconSource: Qt.resolvedUrl("assets/tools/basket.svg")
            text: root.harvestText
            subText: root.harvestInfo
            enabled: root.canHarvest
            onActivated: root.harvest()
        }
        IconButton {
            width: root.compact ? actionFlow.width : Math.min(230, implicitWidth)
            compact: true
            primary: root.warningArmed
            iconSource: Qt.resolvedUrl(root.warningArmed ? "assets/ui/warning.svg" : "assets/ui/next_day.svg")
            text: root.nextDayText
            subText: root.nextDaySubText
            enabled: !root.transitionRunning
            onActivated: root.nextDay()
        }
    }
}
