import QtQuick
UiPanel {
    id: root
    property string text: ""
    property bool primary: false
    property bool compact: false
    signal activated()
    surfaceToken: "surface.control"
    color: primary ? GameTheme.color("color.primary") : GameTheme.color("color.surfaceInteractive")
    border.color: hover.hovered ? GameTheme.color("color.primaryHover") : GameTheme.color("color.border")
    implicitHeight: compact ? GameTheme.number("metric.control.sm") : GameTheme.number("alias.button.height")
    implicitWidth: Math.max(GameTheme.number("alias.button.touchTarget"), label.implicitWidth + GameTheme.number("alias.button.paddingX") * 2)
    scale: tap.pressed ? GameTheme.number("alias.button.pressedScale") : (hover.hovered ? GameTheme.number("alias.button.hoverScale") : 1.0)
    opacity: enabled ? 1.0 : 0.45
    HoverHandler { id: hover; enabled: root.enabled }
    TapHandler { id: tap; enabled: root.enabled; onTapped: { Haptics.light(); root.activated() } }
    UiText {
        id: label
        anchors.centerIn: parent
        text: root.text
        colorToken: root.primary ? "color.background" : "color.text"
        sizeToken: "metric.font.sm"
        font.bold: true
    }
}
