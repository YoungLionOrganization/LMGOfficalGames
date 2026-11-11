import QtQuick
Text {
    id: root
    property string colorToken: "color.text"
    property string sizeToken: "metric.font.md"
    property int themeRevision: 0
    function themeColor(token) {
        var touch = themeRevision
        var fallback = token === "color.textMuted" ? "#9ba8ba" : (token === "color.background" ? "#10141c" : "#f2f5f8")
        try {
            if (typeof GameTheme !== "undefined") {
                var v = GameTheme.color(token)
                if (v !== undefined && v !== null && String(v).length > 0) return v
            }
        } catch (e) {}
        return fallback
    }
    function themeNumber(token) {
        var touch = themeRevision
        var map = {"metric.font.xs":12,"metric.font.sm":14,"metric.font.md":16,"metric.font.lg":22}
        var fallback = map[token] !== undefined ? map[token] : 14
        try {
            if (typeof GameTheme !== "undefined") {
                var n = Number(GameTheme.number(token))
                if (isFinite(n) && n > 0) return n
            }
        } catch (e) {}
        return fallback
    }
    color: themeColor(colorToken)
    font.pixelSize: Math.max(8, themeNumber(sizeToken))
    wrapMode: Text.WordWrap
}
