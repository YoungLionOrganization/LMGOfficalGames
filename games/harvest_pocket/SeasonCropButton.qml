import QtQuick

UiPanel {
    id: root
    property url iconSource
    property string cropName: ""
    property real seedCount: 0
    property var seasons: []
    property int currentSeason: 0
    property bool inCurrentSeason: false
    property bool selected: false
    signal activated()

    function pulseHaptic() {
        try { if (typeof Haptics !== "undefined" && typeof Haptics.light === "function") Haptics.light() } catch (e) {}
    }

    surfaceToken: "surface.control"
    color: selected ? GameTheme.color("color.primary") : GameTheme.color("color.surfaceInteractive")
    border.width: selected ? 2 : 1
    border.color: selected || hover.hovered ? GameTheme.color("color.primaryHover") : GameTheme.color("color.border")
    implicitWidth: 132
    implicitHeight: 76
    opacity: enabled ? (inCurrentSeason ? 1.0 : 0.78) : 0.40
    scale: tap.pressed ? 0.97 : (hover.hovered ? 1.012 : 1.0)
    Behavior on scale { NumberAnimation { duration: 80 } }

    Row {
        anchors.fill: parent
        anchors.margins: 7
        spacing: 7
        Image {
            width: 34; height: 34
            anchors.verticalCenter: parent.verticalCenter
            source: root.iconSource
            fillMode: Image.PreserveAspectFit
            cache: true
        }
        Column {
            width: Math.max(70, parent.width - 48)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            UiText {
                width: parent.width
                text: root.cropName
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
                colorToken: root.selected ? "color.background" : "color.text"
                sizeToken: "metric.font.xs"
            }
            UiText {
                width: parent.width
                text: root.seedCount
                colorToken: root.selected ? "color.background" : "color.textMuted"
                sizeToken: "metric.font.xs"
            }
            Row {
                spacing: 2
                Repeater {
                    model: 4
                    Rectangle {
                        width: 15; height: 15; radius: 4
                        color: "transparent"
                        border.width: index === root.currentSeason ? 1 : 0
                        border.color: root.selected ? GameTheme.color("color.background") : GameTheme.color("color.primary")
                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            source: Qt.resolvedUrl("assets/seasons/" + ["spring","summer","autumn","winter"][index] + ".svg")
                            fillMode: Image.PreserveAspectFit
                            opacity: root.seasons.indexOf(index) >= 0 ? 1.0 : 0.16
                            cache: true
                        }
                    }
                }
            }
        }
    }
    HoverHandler { id: hover; enabled: root.enabled }
    TapHandler { id: tap; enabled: root.enabled; onTapped: { root.forceActiveFocus(); root.pulseHaptic(); root.activated() } }
    Keys.onPressed: function(event) {
        if (root.enabled && (event.key===Qt.Key_Return || event.key===Qt.Key_Enter || event.key===Qt.Key_Space)) {
            root.pulseHaptic(); root.activated(); event.accepted=true
        }
    }
}
