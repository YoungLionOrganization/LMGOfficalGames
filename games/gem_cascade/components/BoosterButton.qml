import QtQuick
import ".."

UiButton {
    id: root
    property int count: 0
    property bool active: false
    property bool interactionEnabled: true
    property string countPrefix: "x"
    property string rootText: ""
    property url iconSource: ""

    primary: active
    enabled: interactionEnabled && count > 0
    text: ""
    compact: true

    // Do not reference private ids from UiButton.qml here. The previous
    // implementation referenced UiButton's internal `shortcut` id, which is
    // outside this component's lexical scope and could collapse mobile layout.
    implicitWidth: Math.max(themeNumber("alias.button.touchTarget"),
                            contentRow.implicitWidth + themeNumber("alias.button.paddingX") * 1.45)
    implicitHeight: Math.max(themeNumber("alias.button.touchTarget"), themeNumber("metric.control.sm"))

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Math.max(4, root.themeNumber("metric.space.xs") * 0.65)

        Image {
            visible: String(root.iconSource).length > 0
            width: Math.max(17, root.themeNumber("metric.icon.md") * 0.82)
            height: width
            source: root.iconSource
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }
        UiText {
            themeRevision: root.themeRevision
            text: root.rootText
            colorToken: root.primary ? "color.background" : "color.text"
            sizeToken: "metric.font.xs"
            font.bold: true
        }
        UiText {
            themeRevision: root.themeRevision
            text: root.countPrefix + root.count
            colorToken: root.primary ? "color.background" : "color.textMuted"
            sizeToken: "metric.font.xs"
            font.bold: true
        }
    }
}
