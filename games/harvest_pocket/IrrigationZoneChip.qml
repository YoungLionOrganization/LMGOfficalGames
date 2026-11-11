import QtQuick

Rectangle {
    id: root
    property string zoneLetter: "A"
    property int coverage: 0
    property int activePlots: 0
    property bool selected: false
    property bool reducedMotion: false
    property string zoneText: "Zone"
    property string coverageText: "Coverage"
    signal activated()

    readonly property int effectiveCoverage: Math.max(0, Math.min(root.activePlots, root.coverage))
    width: Math.max(106, Math.min(146, content.implicitWidth + 22))
    height: 48
    radius: 9
    color: root.selected ? GameTheme.color("color.surfaceInteractive") : GameTheme.color("color.surfaceRaised")
    border.width: root.selected ? 2 : 1
    border.color: root.selected ? GameTheme.color("color.primary") : GameTheme.color("color.border")
    opacity: root.activePlots > 0 ? 1.0 : 0.46

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 1
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.zoneText + " " + root.zoneLetter
            color: GameTheme.color("color.primary")
            font.pixelSize: Math.max(10, GameTheme.number("metric.font.sm"))
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.coverageText + " " + root.effectiveCoverage + "/" + root.activePlots
            color: GameTheme.color("color.textMuted")
            font.pixelSize: Math.max(9, GameTheme.number("metric.font.xs"))
        }
    }

    TapHandler { enabled: root.activePlots > 0; onTapped: root.activated() }
    HoverHandler { id: hover; enabled: root.activePlots > 0 }
    scale: hover.hovered && !root.reducedMotion ? 1.015 : 1.0
    Behavior on scale { NumberAnimation { duration: root.reducedMotion ? 0 : 90 } }
}
