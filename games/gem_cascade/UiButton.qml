import QtQuick
UiPanel {
    id: root
    property string text: ""
    property bool primary: false
    property bool compact: false
    property string shortcutText: ""
    signal activated()
    readonly property bool hapticsEnabled: settingBool("haptics", true)
    function settingBool(key, fallback) {
        try {
            if (typeof GameSettings !== "undefined") {
                var v = GameSettings.value(key, fallback)
                if (v !== undefined && v !== null) {
                    if (typeof v === "string") {
                        var t = v.toLowerCase().trim()
                        if (t === "false" || t === "0" || t === "off" || t === "no") return false
                        if (t === "true" || t === "1" || t === "on" || t === "yes") return true
                    }
                    if (typeof v === "number") return v !== 0
                    return Boolean(v)
                }
            }
        } catch (e) {}
        return Boolean(fallback)
    }
    function tapHaptic() { if (!hapticsEnabled) return; try { if (typeof Haptics !== "undefined") Haptics.light() } catch (e) {} }
    surfaceToken: "surface.control"
    color: primary ? themeColor("color.primary") : themeColor("color.surfaceInteractive")
    border.color: hover.hovered ? themeColor("color.primaryHover") : themeColor("color.border")
    implicitHeight: compact ? themeNumber("metric.control.sm") : themeNumber("alias.button.height")
    implicitWidth: Math.max(themeNumber("alias.button.touchTarget"), label.implicitWidth + themeNumber("alias.button.paddingX") * 2 + (shortcut.visible ? shortcut.implicitWidth : 0))
    scale: tap.pressed ? themeNumber("alias.button.pressedScale") : (hover.hovered ? themeNumber("alias.button.hoverScale") : 1.0)
    opacity: enabled ? 1.0 : 0.45
    HoverHandler { id: hover; enabled: root.enabled }
    Keys.onPressed: function(event) { if (root.enabled && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) { root.tapHaptic(); root.activated(); event.accepted = true } }
    TapHandler { id: tap; enabled: root.enabled; onTapped: { root.forceActiveFocus(); root.tapHaptic(); root.activated() } }
    UiText {
        id: label
        themeRevision: root.themeRevision
        anchors.centerIn: parent
        text: root.text
        colorToken: root.primary ? "color.background" : "color.text"
        sizeToken: "metric.font.sm"
        font.bold: true
    }
    UiText {
        id: shortcut
        themeRevision: root.themeRevision
        visible: root.shortcutText.length > 0 && root.width > label.implicitWidth + implicitWidth + root.themeNumber("alias.button.paddingX") * 3
        anchors.right: parent.right
        anchors.rightMargin: root.themeNumber("alias.button.paddingX")
        anchors.verticalCenter: parent.verticalCenter
        text: root.shortcutText
        colorToken: root.primary ? "color.background" : "color.textMuted"
        sizeToken: "metric.font.xs"
    }
}
