import QtQuick
Text {
    property string colorToken: "color.text"
    property string sizeToken: "metric.font.md"
    color: GameTheme.color(colorToken)
    font.pixelSize: Math.max(1, GameTheme.number(sizeToken))
    wrapMode: Text.WordWrap
}
