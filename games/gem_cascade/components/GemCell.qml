import QtQuick
import ".."

UiPanel {
    id: cell
    property int cellIndex: -1
    property int gem: -1
    property int special: 0
    property int iceLayer: 0
    property bool selected: false
    property bool cursor: false
    property bool clearing: false
    property real clearProgress: 0
    property bool hint: false
    property real swapX: 0
    property real swapY: 0
    property real fallY: 0
    property bool spawned: false
    property real fallProgress: 1
    property real shufflePulse: 0
    property real cellSize: 48
    property bool reducedMotion: false
    property var gemFiles: []
    property var gemColors: []
    signal tapped(int index)
    signal swiped(int index, real dx, real dy)

    width: cellSize
    height: cellSize
    surfaceToken: special === 0 ? "surface.gameTile" : "surface.control"
    border.width: selected || cursor ? 2 : (isSpecial ? 2 : 1)
    readonly property bool hovered: pointer.containsMouse
    readonly property bool isSpecial: special > 0
    readonly property color gemTint: gem >= 0 && gem < gemColors.length ? gemColors[gem] : themeColor("color.textMuted")
    readonly property color glowColor: special === 4 ? themeColor("color.accent") : (special === 5 ? themeColor("color.primary") : gemTint)
    readonly property string specialIconSource:
        special === 1 ? Qt.resolvedUrl("../assets/icons/special_row.svg") :
        special === 2 ? Qt.resolvedUrl("../assets/icons/special_column.svg") :
        special === 3 ? Qt.resolvedUrl("../assets/icons/special_bomb.svg") :
        special === 4 ? Qt.resolvedUrl("../assets/icons/special_prism.svg") :
        special === 5 ? Qt.resolvedUrl("../assets/icons/special_nova.svg") : ""
    border.color: selected ? cell.themeColor("color.accent") : (cursor ? cell.themeColor("color.primary") : (hint ? cell.themeColor("color.accent") : (cell.isSpecial ? cell.glowColor : (hovered ? cell.themeColor("color.primaryHover") : cell.themeColor("color.border")))))
    readonly property real interactionScale: clearing ? (clearProgress < 0.28 ? 1.0 + 0.10 * (clearProgress / 0.28) : 1.10 - 0.92 * ((clearProgress - 0.28) / 0.72)) : (selected ? 1.08 : (hovered ? 1.03 : 1.0))
    readonly property real spawnScale: spawned ? (0.90 + 0.10 * Math.max(0, Math.min(1, fallProgress))) : 1.0
    scale: interactionScale * spawnScale
    opacity: (clearing ? (clearProgress < 0.18 ? 1.0 : Math.max(0.05, 1.0 - 0.95 * ((clearProgress - 0.18) / 0.82))) : 1.0) * (spawned ? (0.80 + 0.20 * Math.max(0, Math.min(1, fallProgress))) : 1.0)
    readonly property real shuffleX: shufflePulse * (3.5 - (cellIndex % 8)) * cellSize * 0.10
    readonly property real shuffleY: shufflePulse * (3.5 - Math.floor(cellIndex / 8)) * cellSize * 0.10
    transform: Translate { x: cell.swapX + cell.shuffleX; y: cell.swapY + cell.fallY + cell.shuffleY }
    Behavior on scale { enabled: !cell.clearing; NumberAnimation { duration: cell.reducedMotion ? 1 : 120; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: Math.max(2, parent.radius - 2)
        color: cell.isSpecial ? Qt.rgba(cell.glowColor.r, cell.glowColor.g, cell.glowColor.b, 0.14) : "transparent"
        border.width: cell.isSpecial ? 1 : 0
        border.color: cell.isSpecial ? Qt.rgba(cell.glowColor.r, cell.glowColor.g, cell.glowColor.b, 0.54) : "transparent"
        opacity: cell.isSpecial ? 0.88 : 0
        SequentialAnimation on opacity {
            running: cell.isSpecial && !cell.reducedMotion && !cell.clearing
            loops: Animation.Infinite
            NumberAnimation { from: 0.72; to: 0.98; duration: 620; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.98; to: 0.72; duration: 620; easing.type: Easing.InOutSine }
        }
    }

    Rectangle {
        visible: cell.isSpecial
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Math.max(2, parent.height * 0.05)
        anchors.rightMargin: Math.max(2, parent.width * 0.05)
        width: Math.max(9, parent.width * 0.19)
        height: width
        radius: width / 2
        color: cell.glowColor
        opacity: 0.88
        border.width: 1
        border.color: cell.themeColor("color.text")
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * (cell.isSpecial ? 0.62 : 0.52)
        height: width
        radius: width / 2
        color: Qt.rgba(cell.gemTint.r, cell.gemTint.g, cell.gemTint.b, cell.isSpecial ? 0.18 : 0.08)
        visible: cell.gem >= 0
    }

    Image {
        anchors.centerIn: parent
        width: parent.width * 0.66
        height: width
        source: cell.gem >= 0 && cell.gem < cell.gemFiles.length ? Qt.resolvedUrl("../assets/gems/" + cell.gemFiles[cell.gem]) : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: false
    }

    Rectangle {
        visible: cell.isSpecial
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(2, parent.height * 0.06)
        width: parent.width * 0.64
        height: parent.height * 0.30
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.22)
    }
    Image {
        visible: cell.isSpecial
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(2, parent.height * 0.06)
        width: parent.width * 0.34
        height: width
        source: cell.specialIconSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    Repeater {
        model: cell.clearing && !cell.reducedMotion ? 6 : 0
        Rectangle {
            required property int index
            anchors.centerIn: parent
            width: Math.max(3, cell.width * (index < 4 ? 0.07 : 0.05))
            height: width
            radius: width / 2
            color: index < 4 ? cell.gemTint : cell.glowColor
            opacity: cell.clearing ? Math.max(0, 0.88 * (1 - cell.clearProgress)) : 0
            transform: Translate {
                x: (index === 0 ? -1 : index === 1 ? 1 : index === 4 ? -0.6 : index === 5 ? 0.6 : 0) * cell.width * 0.34 * cell.clearProgress
                y: (index === 2 ? -1 : index === 3 ? 1 : index === 4 ? 0.7 : index === 5 ? -0.7 : 0) * cell.height * 0.34 * cell.clearProgress
            }
        }
    }

    Rectangle {
        visible: cell.clearing && cell.isSpecial
        anchors.centerIn: parent
        width: parent.width * (0.75 + 0.55 * cell.clearProgress)
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: cell.glowColor
        opacity: Math.max(0, 0.95 - cell.clearProgress)
    }

    Rectangle {
        visible: cell.iceLayer > 0
        anchors.fill: parent
        anchors.margins: 1
        color: cell.themeColor("color.info")
        opacity: cell.iceLayer === 2 ? 0.28 : 0.14
        border.width: cell.iceLayer
        border.color: cell.themeColor("color.info")
        radius: cell.radius
    }

    Rectangle {
        visible: cell.hint
        anchors.fill: parent
        anchors.margins: Math.max(2, parent.width * 0.04)
        color: "transparent"
        border.width: 2
        border.color: cell.themeColor("color.accent")
        radius: cell.radius
        SequentialAnimation on opacity {
            running: cell.hint && !cell.reducedMotion
            loops: Animation.Infinite
            NumberAnimation { from: 0.35; to: 1.0; duration: 380 }
            NumberAnimation { from: 1.0; to: 0.35; duration: 380 }
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        property real pressX: 0
        property real pressY: 0
        onPressed: function(mouse) { pressX = mouse.x; pressY = mouse.y }
        onReleased: function(mouse) {
            var dx = mouse.x - pressX
            var dy = mouse.y - pressY
            var threshold = Math.max(8, cell.cellSize * 0.20)
            if (Math.max(Math.abs(dx), Math.abs(dy)) >= threshold)
                cell.swiped(cell.cellIndex, dx, dy)
            else
                cell.tapped(cell.cellIndex)
        }
    }
}
