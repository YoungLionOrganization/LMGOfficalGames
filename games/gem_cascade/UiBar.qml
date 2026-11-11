import QtQuick
Rectangle {
    id: root
    property real value: 0
    property real from: 0
    property real maximum: 100
    property real to: maximum
    property string colorToken: "color.primary"
    property string fillToken: colorToken
    property int themeRevision: 0
    function themeColor(token) {
        var touch = themeRevision
        var map = {"color.surfaceInteractive":"#252e3e","color.primary":"#6c8cff","color.accent":"#9d7cff","color.info":"#58a6ff"}
        try {
            if (typeof GameTheme !== "undefined") {
                var v = GameTheme.color(token)
                if (v !== undefined && v !== null && String(v).length > 0) return v
            }
        } catch (e) {}
        return map[token] !== undefined ? map[token] : "#6c8cff"
    }
    color: themeColor("color.surfaceInteractive")
    radius: height / 2
    clip: true
    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, (root.value - root.from) / Math.max(0.0001, root.to - root.from)))
        height: parent.height
        radius: parent.radius
        color: root.themeColor(root.fillToken)
        Behavior on width { NumberAnimation { duration: 120 } }
    }
}
