import QtQuick

UiPanel {
    id: root
    property string label: ""
    property int deltaPercent: 0
    property url iconSource: ""
    readonly property string valueText: (deltaPercent > 0 ? "+" : "") + deltaPercent + "%"
    readonly property string valueToken: deltaPercent >= 3 ? "color.success" : (deltaPercent <= -3 ? "color.danger" : "color.textMuted")
    implicitWidth: Math.max(142, content.implicitWidth + GameTheme.number("alias.card.padding") * 2)
    implicitHeight: Math.max(44, GameTheme.number("metric.control.sm"))
    surfaceToken: "surface.panel"
    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6
        Image { width: 19; height: 19; source: root.iconSource; fillMode: Image.PreserveAspectFit; cache: true }
        Column {
            spacing: 0
            UiText { text: root.label; colorToken: "color.textMuted"; sizeToken: "metric.font.xs" }
            UiText { text: root.valueText; colorToken: root.valueToken; sizeToken: "metric.font.sm"; font.bold: true }
        }
    }
}
