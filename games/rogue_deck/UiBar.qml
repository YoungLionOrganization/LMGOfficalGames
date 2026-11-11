import QtQuick
Rectangle {
    id: root
    property real value: 0
    property real from: 0
    property real maximum: 100
    property real to: maximum
    property string colorToken: "color.primary"
    property string fillToken: colorToken
    color: GameTheme.color("color.surfaceInteractive")
    radius: height / 2
    clip: true
    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, (root.value - root.from) / Math.max(0.0001, root.to - root.from)))
        height: parent.height
        radius: parent.radius
        color: GameTheme.color(root.fillToken)
        Behavior on width { NumberAnimation { duration: 120 } }
    }
}
