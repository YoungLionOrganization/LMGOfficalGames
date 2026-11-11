import QtQuick
UiPanel {
    id: root
    property string label: ""
    property string value: ""
    property string valueColorToken: "color.accent"
    implicitWidth: Math.max(themeNumber("metric.control.lg"), row.implicitWidth + themeNumber("alias.card.padding") * 2)
    implicitHeight: themeNumber("metric.control.sm")
    surfaceToken: "surface.panel"
    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.themeNumber("alias.card.gap")
        UiText { themeRevision: root.themeRevision; text: root.label; colorToken: "color.textMuted"; sizeToken: "metric.font.xs" }
        UiText { themeRevision: root.themeRevision; text: root.value; colorToken: root.valueColorToken; sizeToken: "metric.font.sm"; font.bold: true }
    }
}
