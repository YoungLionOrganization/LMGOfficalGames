import QtQuick

Rectangle {
    id: root

    property alias text: label.text
    property color normalColor: "#2A1A11"
    property color pressedColor: "#4A2D1B"
    property color borderColor: "#9A5B2E"
    property color textColor: "#F3DCB0"

    signal clicked()

    implicitWidth: 110
    implicitHeight: 42
    radius: Math.max(0, Math.min(11, height / 2))
    color: !enabled ? "#211812" : (tap.pressed ? pressedColor : normalColor)
    border.color: enabled ? borderColor : "#4A3A30"
    border.width: 1
    opacity: enabled ? 1.0 : 0.55

    Text {
        id: label
        anchors.centerIn: parent
        width: Math.max(0, parent.width - 12)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        color: root.textColor
        font.pixelSize: Math.max(11, Math.min(15, root.height * 0.34))
        font.bold: true
    }

    TapHandler {
        id: tap
        enabled: root.enabled
        onTapped: root.clicked()
    }
}
