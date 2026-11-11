import QtQuick

Item {
    id: root

    property string mode: "bottom" // bottom | top | side
    property bool dense: false
    property int currentIndex: 0
    property string farmText: ""
    property string animalsText: ""
    property string marketText: ""
    property string workshopText: ""
    property string journalText: ""
    signal selected(int index)

    readonly property bool sideMode: mode === "side"
    readonly property var entries: [
        { index: 0, text: farmText, icon: "assets/ui/farm.svg" },
        { index: 1, text: animalsText, icon: "assets/ui/animals.svg" },
        { index: 2, text: marketText, icon: "assets/ui/market.svg" },
        { index: 3, text: workshopText, icon: "assets/ui/workshop.svg" },
        { index: 4, text: journalText, icon: "assets/ui/journal.svg" }
    ]

    implicitWidth: sideMode ? (dense ? 138 : 156) : 360
    implicitHeight: sideMode ? 282 : (dense ? 52 : 60)

    UiPanel { anchors.fill: parent; surfaceToken: "surface.control" }

    Row {
        id: horizontalNav
        visible: !root.sideMode
        anchors.fill: parent
        anchors.margins: root.dense ? 4 : 6
        spacing: root.dense ? 3 : 4

        Repeater {
            model: root.entries
            delegate: Item {
                required property var modelData
                width: Math.max(48, (horizontalNav.width - horizontalNav.spacing * 4) / 5)
                height: horizontalNav.height

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: root.currentIndex === modelData.index ? GameTheme.color("color.primary") : "transparent"
                    border.width: hover.hovered ? 1 : 0
                    border.color: GameTheme.color("color.primaryHover")
                    opacity: tap.pressed ? 0.82 : 1.0
                }

                Row {
                    visible: root.dense
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 8, denseRow.implicitWidth)
                    spacing: 6
                    id: denseRow
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 19; height: 19
                        source: Qt.resolvedUrl(modelData.icon)
                        fillMode: Image.PreserveAspectFit
                        cache: true
                    }
                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(38, parent.width - 25)
                        text: modelData.text
                        colorToken: root.currentIndex === modelData.index ? "color.background" : "color.text"
                        sizeToken: "metric.font.xs"
                        font.bold: true
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }
                }

                Column {
                    visible: !root.dense
                    anchors.centerIn: parent
                    width: parent.width - 6
                    spacing: 1
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 22; height: 22
                        source: Qt.resolvedUrl(modelData.icon)
                        fillMode: Image.PreserveAspectFit
                        cache: true
                    }
                    UiText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.text
                        colorToken: root.currentIndex === modelData.index ? "color.background" : "color.text"
                        sizeToken: "metric.font.xs"
                        font.bold: true
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }
                }

                HoverHandler { id: hover }
                TapHandler { id: tap; onTapped: root.selected(modelData.index) }
            }
        }
    }

    Column {
        id: sideNav
        visible: root.sideMode
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4

        Repeater {
            model: root.entries
            delegate: Item {
                required property var modelData
                width: sideNav.width
                height: root.dense ? 46 : 50

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: root.currentIndex === modelData.index ? GameTheme.color("color.primary") : "transparent"
                    border.width: hoverSide.hovered ? 1 : 0
                    border.color: GameTheme.color("color.primaryHover")
                    opacity: tapSide.pressed ? 0.82 : 1.0
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 7
                    spacing: 7
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22
                        source: Qt.resolvedUrl(modelData.icon)
                        fillMode: Image.PreserveAspectFit
                        cache: true
                    }
                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(45, parent.width - 36)
                        text: modelData.text
                        colorToken: root.currentIndex === modelData.index ? "color.background" : "color.text"
                        sizeToken: "metric.font.xs"
                        font.bold: true
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }
                }

                HoverHandler { id: hoverSide }
                TapHandler { id: tapSide; onTapped: root.selected(modelData.index) }
            }
        }
    }
}
