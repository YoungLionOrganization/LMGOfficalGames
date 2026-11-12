import QtQuick
import "CityData.js" as Data

Rectangle {
    id: root
    required property string balance
    required property var line
    required property var translate
    implicitHeight: readout.implicitHeight + 12
    color: GameTheme.color("alias.page.background.normal")
    border.color: GameTheme.color("alias.button.border.normal")
    radius: 8
    Column {
        id: readout
        x: 10
        y: 6
        width: Math.max(1, parent.width - 20)
        spacing: 2
        CityText { width: parent.width; text: root.balance; font.bold: true }
        CityText {
            width: parent.width
            muted: true
            visible: text.length > 0
            text: root.line ? root.line.name + " · " +
                      root.translate("city.status." + root.line.status, Data.statuses[root.line.status]) : ""
        }
    }
}
