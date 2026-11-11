import QtQuick

Rectangle {
    id: root

    property alias text: label.text
    property color normalColor: GameTheme.color("color.surfaceInteractive")
    property color pressedColor: GameTheme.color("color.surfaceHover")
    property color borderColor: GameTheme.color("color.borderStrong")
    property color textColor: GameTheme.color("color.text")
    property bool primary: false
    property string shortcutText: ""
    property bool hapticsEnabled: GameSettings.value("hapticsEnabled", true)

    signal clicked()

    implicitWidth: Math.max(GameTheme.number("alias.button.touchTarget"), label.implicitWidth + GameTheme.number("alias.button.paddingX") * 2)
    implicitHeight: GameTheme.number("alias.button.height")
    radius: GameTheme.number("alias.button.radius")
    color: !enabled ? GameTheme.color("alias.button.background.disabled") : (tap.pressed ? pressedColor : (hover.hovered ? GameTheme.color("alias.button.background.hover") : (primary ? GameTheme.color("color.primary") : normalColor)))
    border.color: activeFocus ? GameTheme.color("alias.button.border.focus") : (enabled ? borderColor : GameTheme.color("alias.button.border.disabled"))
    border.width: activeFocus ? Math.max(2, GameTheme.number("alias.button.borderWidth")) : GameTheme.number("alias.button.borderWidth")
    opacity: enabled ? 1.0 : GameTheme.number("alias.opacity.disabled")
    scale: tap.pressed ? GameTheme.number("alias.scale.pressed") : (hover.hovered ? GameTheme.number("alias.scale.hover") : 1.0)

    Behavior on scale { NumberAnimation { duration: GameTheme.number("alias.motion.fast.duration") } }
    HoverHandler { id: hover; enabled: root.enabled }
    TapHandler {
        id: tap
        enabled: root.enabled
        onTapped: { root.forceActiveFocus(); if (root.hapticsEnabled) Haptics.light(); root.clicked() }
    }
    Keys.onPressed: function(event) {
        if (!root.enabled) return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (root.hapticsEnabled) Haptics.light(); root.clicked(); event.accepted = true
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        width: Math.max(0, parent.width - GameTheme.number("alias.button.paddingX") * 2)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        color: root.primary ? GameTheme.color("color.background") : root.textColor
        font.pixelSize: GameTheme.number("alias.button.fontSize")
        font.bold: true
    }
}
