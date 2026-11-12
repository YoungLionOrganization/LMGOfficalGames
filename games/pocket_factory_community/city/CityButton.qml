import QtQuick

Rectangle {
    id: root
    property string text
    property bool primary: false
    signal activated()
    activeFocusOnTab: visible && enabled
    implicitHeight: Math.max(44, label.implicitHeight + 14)
    implicitWidth: Math.min(210, Math.max(68, label.implicitWidth + 20))
    radius: 8
    color: primary ? GameTheme.color("alias.button.accent.normal") : GameTheme.color("alias.button.background.normal")
    border.color: activeFocus || hover.hovered ? GameTheme.color("color.accent") : GameTheme.color("alias.button.border.normal")
    border.width: activeFocus ? 2 : 1
    opacity: enabled ? 1 : 0.48
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: if (enabled) activated()
    Keys.onReturnPressed: if (enabled) activated()
    Keys.onSpacePressed: if (enabled) activated()
    HoverHandler { id: hover }
    TapHandler { onTapped: { root.forceActiveFocus(); root.activated() } }
    Text {
        id: label
        width: Math.max(1, parent.width - 16)
        anchors.centerIn: parent
        text: root.text
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Math.max(12, GameTheme.number("metric.font.sm"))
        font.weight: Font.DemiBold
        color: root.primary ? GameTheme.color("alias.page.background.normal") : GameTheme.color("color.text")
    }
}
