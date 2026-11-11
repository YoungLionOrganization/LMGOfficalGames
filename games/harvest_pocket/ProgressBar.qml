import QtQuick
Rectangle {
    id: root
    property real value: 0
    property real maximum: 1
    property color fillColor: GameTheme.color("color.primary")
    radius: height/2
    color: GameTheme.color("color.surfaceInteractive")
    border.color: GameTheme.color("color.border")
    implicitHeight: 8
    Rectangle { anchors.left:parent.left; anchors.top:parent.top; anchors.bottom:parent.bottom; width: Math.max(0,Math.min(parent.width,parent.width*(root.maximum<=0?0:root.value/root.maximum))); radius:parent.radius; color:root.fillColor }
}
