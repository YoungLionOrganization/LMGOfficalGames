import QtQuick

Text {
    property bool heading: false
    property bool muted: false
    color: GameTheme.color(muted ? "color.textMuted" : "color.text")
    font.pixelSize: Math.max(12, GameTheme.number(heading ? "metric.font.lg" : "metric.font.sm"))
    font.bold: heading
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
}
