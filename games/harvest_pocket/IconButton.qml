import QtQuick

UiPanel {
    id: root
    property url iconSource
    property string text: ""
    property string subText: ""
    property bool primary: false
    property bool compact: false
    signal activated()

    function pulseHaptic() {
        try {
            if (typeof Haptics !== "undefined" && typeof Haptics.light === "function") Haptics.light()
        } catch (e) {}
    }

    readonly property real iconSize: compact ? 24 : 31
    readonly property real textColumnWidth: Math.max(64, root.width - root.iconSize - 8 - 16)
    surfaceToken: "surface.control"
    color: primary ? GameTheme.color("color.primary") : GameTheme.color("color.surfaceInteractive")
    border.color: hover.hovered ? GameTheme.color("color.primaryHover") : GameTheme.color("color.border")
    implicitWidth: (compact ? 190 : 226)
    implicitHeight: Math.max(compact ? 44 : 62, content.implicitHeight + 14)
    opacity: enabled ? 1 : 0.42
    scale: tap.pressed ? 0.97 : (hover.hovered ? 1.015 : 1)
    Behavior on scale { NumberAnimation { duration: 90 } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8
        Image {
            width: root.iconSize
            height: width
            source: root.iconSource
            fillMode: Image.PreserveAspectFit
            cache: true
        }
        Column {
            width: root.textColumnWidth
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            UiText {
                width: parent.width
                text: root.text
                font.bold: true
                colorToken: root.primary ? "color.background" : "color.text"
                sizeToken: root.compact ? "metric.font.xs" : "metric.font.sm"
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            UiText {
                width: parent.width
                visible: root.subText.length > 0
                text: root.subText
                colorToken: root.primary ? "color.background" : "color.textMuted"
                sizeToken: "metric.font.xs"
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }
    HoverHandler { id:hover; enabled:root.enabled }
    TapHandler { id:tap; enabled:root.enabled; onTapped:{root.forceActiveFocus(); root.pulseHaptic(); root.activated()} }
    Keys.onPressed:function(event){ if(root.enabled && (event.key===Qt.Key_Return||event.key===Qt.Key_Enter||event.key===Qt.Key_Space)){ root.pulseHaptic(); root.activated(); event.accepted=true } }
}
