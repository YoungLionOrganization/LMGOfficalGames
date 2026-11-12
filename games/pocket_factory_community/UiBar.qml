import QtQuick
Rectangle {
    id: root
    property real value: 0
    property real maximum: 100
    property string colorToken: "color.primary"
    implicitHeight: Math.max(4, GameTheme.number("metric.border.strong") * 3)
    radius: height / 2
    color: GameTheme.color("color.surfaceInteractive")
    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.maximum > 0 ? root.value / root.maximum : 0))
        height: parent.height
        radius: parent.radius
        color: GameTheme.color(root.colorToken)
    }
}
