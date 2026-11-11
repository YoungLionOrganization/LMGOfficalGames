import QtQuick
UiPanel {
    id: root
    property string text: ""
    property bool primary: false
    property bool compact: false
    property string shortcutText: ""
    signal activated()

    function pulseHaptic() {
        try {
            if (typeof Haptics !== "undefined" && typeof Haptics.light === "function") Haptics.light()
        } catch (e) {}
    }
    surfaceToken: "surface.control"
    color: primary ? GameTheme.color("color.primary") : GameTheme.color("color.surfaceInteractive")
    border.color: hover.hovered ? GameTheme.color("color.primaryHover") : GameTheme.color("color.border")
    implicitHeight: compact ? GameTheme.number("metric.control.sm") : GameTheme.number("alias.button.height")
    implicitWidth: Math.min(280, Math.max(GameTheme.number("alias.button.touchTarget"), label.implicitWidth + GameTheme.number("alias.button.paddingX") * 2 + (shortcut.visible ? shortcut.implicitWidth : 0)))
    scale: tap.pressed ? GameTheme.number("alias.button.pressedScale") : (hover.hovered ? GameTheme.number("alias.button.hoverScale") : 1.0)
    opacity: enabled ? 1.0 : 0.45
    HoverHandler { id: hover; enabled: root.enabled }
    Keys.onPressed: function(event) { if (root.enabled && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) { root.pulseHaptic(); root.activated(); event.accepted = true } }
    TapHandler { id: tap; enabled: root.enabled; onTapped: { root.forceActiveFocus(); root.pulseHaptic(); root.activated() } }
    UiText {
        id: label
        anchors.centerIn: parent
        width: Math.max(24, parent.width - GameTheme.number("alias.button.paddingX") * 2)
        horizontalAlignment: Text.AlignHCenter
        text: root.text
        colorToken: root.primary ? "color.background" : "color.text"
        sizeToken: "metric.font.sm"
        font.bold: true
        maximumLineCount: 1
        elide: Text.ElideRight
    }
    UiText {
        id: shortcut
        visible: root.shortcutText.length > 0 && root.width > label.implicitWidth + implicitWidth + GameTheme.number("alias.button.paddingX") * 3
        anchors.right: parent.right
        anchors.rightMargin: GameTheme.number("alias.button.paddingX")
        anchors.verticalCenter: parent.verticalCenter
        text: root.shortcutText
        colorToken: root.primary ? "color.background" : "color.textMuted"
        sizeToken: "metric.font.xs"
    }
}
