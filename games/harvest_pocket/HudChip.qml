import QtQuick
UiPanel {
    id: root
    property string label: ""
    property string value: ""
    property string valueColorToken: "color.accent"
    implicitWidth: Math.max(GameTheme.number("metric.control.lg"), row.implicitWidth + GameTheme.number("alias.card.padding") * 2)
    implicitHeight: GameTheme.number("metric.control.sm")
    surfaceToken: "surface.panel"
    Row {
        id: row
        anchors.centerIn: parent
        spacing: GameTheme.number("alias.card.gap")
        UiText { text: root.label; colorToken: "color.textMuted"; sizeToken: "metric.font.xs" }
        UiText { text: root.value; colorToken: root.valueColorToken; sizeToken: "metric.font.sm"; font.bold: true }
    }
}
