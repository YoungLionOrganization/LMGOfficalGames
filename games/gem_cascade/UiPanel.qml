import QtQuick
Rectangle {
    id: root
    default property alias contentData: layer.data
    property string surfaceToken: "surface.card"
    property int themeRevision: 0

    function fallbackColor(token) {
        var map = {"color.background":"#10141c","color.surfaceRaised":"#1b2230","color.surfaceInteractive":"#252e3e","color.border":"#3b465a","color.text":"#f2f5f8","color.textMuted":"#9ba8ba","color.primary":"#6c8cff","color.primaryHover":"#88a2ff","color.accent":"#9d7cff","color.info":"#58a6ff"}
        return map[token] !== undefined ? map[token] : "#f2f5f8"
    }
    function fallbackNumber(token) {
        var map = {"alias.page.padding":16,"alias.page.gap":10,"alias.gameTile.gap":4,"alias.card.padding":12,"alias.card.gap":8,"alias.card.radius":12,"alias.card.borderWidth":1,"alias.button.gap":8,"alias.button.height":44,"alias.button.touchTarget":44,"alias.button.paddingX":14,"alias.button.hoverScale":1.02,"alias.button.pressedScale":0.98,"metric.control.lg":96,"metric.control.sm":36,"metric.control.xs":28,"metric.icon.md":24,"metric.space.xs":8,"metric.space.xxxs":2,"metric.font.xs":12,"metric.font.sm":14,"metric.font.md":16,"metric.font.lg":22}
        return map[token] !== undefined ? map[token] : 8
    }
    function themeColor(token) {
        var touch = themeRevision
        try {
            if (typeof GameTheme !== "undefined") {
                var v = GameTheme.color(token)
                if (v !== undefined && v !== null && String(v).length > 0) return v
            }
        } catch (e) {}
        return fallbackColor(token)
    }
    function themeNumber(token) {
        var touch = themeRevision
        try {
            if (typeof GameTheme !== "undefined") {
                var n = Number(GameTheme.number(token))
                if (isFinite(n) && n > 0) return n
            }
        } catch (e) {}
        return fallbackNumber(token)
    }
    function themeSurface(token) {
        var touch = themeRevision
        try {
            if (typeof GameTheme !== "undefined") {
                var v = GameTheme.surface(token)
                if (v !== undefined && v !== null) return v
            }
        } catch (e) {}
        return null
    }

    property var spec: themeSurface(surfaceToken)
    color: spec && spec.color !== undefined ? spec.color : themeColor("color.surfaceRaised")
    radius: spec && spec.radius !== undefined && isFinite(Number(spec.radius)) && Number(spec.radius) >= 0 ? Number(spec.radius) : themeNumber("alias.card.radius")
    border.width: spec && spec.borderWidth !== undefined && isFinite(Number(spec.borderWidth)) && Number(spec.borderWidth) >= 0 ? Number(spec.borderWidth) : themeNumber("alias.card.borderWidth")
    border.color: spec && spec.border !== undefined ? spec.border : themeColor("color.border")
    gradient: spec && spec.fillType === "gradient" && spec.gradient ? themedGradient : null
    Gradient {
        id: themedGradient
        orientation: root.spec && root.spec.gradient && root.spec.gradient.orientation === "horizontal" ? Gradient.Horizontal : Gradient.Vertical
        GradientStop { position: 0.0; color: root.spec && root.spec.gradient && root.spec.gradient.start !== undefined ? root.spec.gradient.start : root.color }
        GradientStop { position: 0.5; color: root.spec && root.spec.gradient && root.spec.gradient.middle !== undefined ? root.spec.gradient.middle : root.color }
        GradientStop { position: 1.0; color: root.spec && root.spec.gradient && root.spec.gradient.end !== undefined ? root.spec.gradient.end : root.color }
    }
    Image {
        anchors.fill: parent
        visible: root.spec && root.spec.texture !== undefined && String(root.spec.texture).length > 0
        source: visible ? String(root.spec.texture) : ""
        opacity: root.spec && root.spec.textureOpacity !== undefined && isFinite(Number(root.spec.textureOpacity)) ? Math.max(0, Math.min(1, Number(root.spec.textureOpacity))) : 0
        fillMode: Image.Tile
        asynchronous: true
    }
    Item { id: layer; anchors.fill: parent }
}
