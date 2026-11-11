import QtQuick
import ".."
Rectangle {
    id: root
    property bool open: false
    property int page: 0
    property int themeRevision: 0
    property var translate: function(k, f) { return f }
    signal finished()
    signal dismissed()
    function themeNumber(token) {
        var touch = themeRevision
        var map = {"alias.card.padding":12,"alias.card.gap":8,"alias.button.gap":8,"metric.font.lg":22}
        var fallback = map[token] !== undefined ? map[token] : 8
        try {
            if (typeof GameTheme !== "undefined") {
                var n = Number(GameTheme.number(token))
                if (isFinite(n) && n > 0) return n
            }
        } catch (e) {}
        return fallback
    }
    anchors.fill: parent
    visible: open
    z: 100
    color: Qt.rgba(0, 0, 0, 0.58)

    MouseArea { anchors.fill: parent }
    UiPanel {
        themeRevision: root.themeRevision
        width: Math.min(parent.width - 32, 460)
        implicitHeight: content.implicitHeight + root.themeNumber("alias.card.padding") * 2
        anchors.centerIn: parent
        surfaceToken: "surface.panel"
        Column {
            id: content
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.themeNumber("alias.card.padding")
            spacing: root.themeNumber("alias.card.gap")
            UiText { themeRevision: root.themeRevision; width: parent.width; text: root.translate("tutorial_title", "How to play"); font.bold: true; sizeToken: "metric.font.lg" }
            UiText { themeRevision: root.themeRevision;
                width: parent.width
                text: root.page === 0 ? root.translate("tutorial_swap", "Swipe or select two adjacent gems. Only swaps that create a match are accepted.")
                     : root.page === 1 ? root.translate("tutorial_special", "Match 4 for a Line gem, 5 for a Prism, 6 for a Nova, and T/L shapes for a Bomb. Combine specials for stronger effects.")
                     : root.page === 2 ? root.translate("tutorial_objective", "Complete every objective before your moves run out. Cascades increase your score multiplier.")
                     : root.translate("booster_reward_rule", "Clear a new level to earn a booster. First 3-star clears add a bonus; every 5th new level adds Cross Blast + Extra Moves.")
                colorToken: "color.textMuted"
            }
            Row {
                spacing: root.themeNumber("alias.button.gap")
                UiButton { themeRevision: root.themeRevision; text: root.translate("close", "Close"); onActivated: { root.open = false; root.dismissed() } }
                UiButton { themeRevision: root.themeRevision;
                    primary: true
                    text: root.page < 3 ? root.translate("next", "Next") : root.translate("got_it", "Got it")
                    onActivated: {
                        if (root.page < 3) root.page++
                        else { root.open = false; root.finished() }
                    }
                }
            }
        }
    }
}
