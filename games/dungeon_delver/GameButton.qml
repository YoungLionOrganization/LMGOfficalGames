import QtQuick

Rectangle {
    id: root
    property string text: ""
    property url iconSource: ""
    property bool primary: false
    property bool compact: false
    property int themeRevision: 0
    signal clicked()

    function tc(token, fallback) {
        var t = themeRevision
        try {
            if (typeof GameTheme !== "undefined") {
                var v = GameTheme.color(token)
                if (v !== undefined && v !== null) return v
            }
        } catch(e) {}
        return fallback
    }
    function tn(token, fallback) {
        var t = themeRevision
        try {
            if (typeof GameTheme !== "undefined") {
                var v = Number(GameTheme.number(token))
                if (isFinite(v) && v > 0) return v
            }
        } catch(e) {}
        return fallback
    }

    color: primary ? tc("color.primary", "#b7863b") : tc("color.surfaceInteractive", "#28231f")
    border.color: hover.hovered ? tc("color.primaryHover", "#d4a85f") : tc("color.borderStrong", "#6e5a42")
    border.width: activeFocus ? 2 : 1
    radius: tn("alias.button.radius", 10)
    implicitHeight: compact ? 40 : Math.max(46, tn("alias.button.height", 44))
    implicitWidth: Math.max(48, content.implicitWidth + 26)
    opacity: enabled ? 1.0 : 0.42
    scale: tap.pressed ? 0.96 : (hover.hovered ? 1.02 : 1.0)
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

    HoverHandler { id: hover; enabled: root.enabled }
    TapHandler {
        id: tap
        enabled: root.enabled
        onTapped: { root.forceActiveFocus(); root.clicked() }
    }
    Keys.onPressed: function(event) {
        if (root.enabled && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
            root.clicked(); event.accepted = true
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 7
        Image {
            visible: String(root.iconSource).length > 0
            source: root.iconSource
            width: 20
            height: 20
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }
        Text {
            text: root.text
            color: root.primary ? root.tc("color.background", "#111") : root.tc("color.text", "#f4efe6")
            font.pixelSize: root.tn("alias.button.fontSize", 14)
            font.bold: true
            verticalAlignment: Text.AlignVCenter
        }
    }
}
