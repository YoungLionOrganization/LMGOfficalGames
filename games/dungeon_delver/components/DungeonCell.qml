import QtQuick
import ".."

Item {
    id: cell
    property int cellIndex: -1
    property real cellSize: 32
    property bool visibleCell: false
    property bool explored: false
    property string tile: "#"
    property string actorType: ""
    property real actorHpRatio: 0
    property bool playerHere: false
    property int artStyle: 0
    property int heroClass: 0
    property int themeRevision: 0
    property real impactProgress: 0
    property int impactCell: -1
    property color floorColor: "#211d1a"
    property color wallColor: "#65513d"
    property color wallEdge: "#b7863b"
    property color accentColor: "#c89a50"
    property color dangerColor: "#d45252"
    property color successColor: "#62b36b"
    property color infoColor: "#669de8"

    width: cellSize
    height: cellSize
    opacity: visibleCell ? 1 : (explored ? 0.38 : 0.10)

    Rectangle {
        anchors.fill: parent
        color: cell.visibleCell || cell.explored ? cell.floorColor : Qt.darker(cell.floorColor, 1.65)
        border.width: 0.5
        border.color: Qt.rgba(cell.wallEdge.r, cell.wallEdge.g, cell.wallEdge.b, 0.14)
        radius: Math.max(1, cell.cellSize * 0.045)
    }

    Image {
        anchors.fill: parent
        anchors.margins: 1
        visible: cell.tile === "#"
        source: cell.artStyle === 0 ? Qt.resolvedUrl("../assets/environment/wall_keep.svg")
              : (cell.artStyle === 1 ? Qt.resolvedUrl("../assets/environment/wall_crypt.svg")
                                     : Qt.resolvedUrl("../assets/environment/wall_arcane.svg"))
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    function tileIcon() {
        if (tile === ">") return "../assets/items/stairs.svg"
        if (tile === "!") return "../assets/items/potion.svg"
        if (tile === "$") return "../assets/items/coin.svg"
        if (tile === "C") return "../assets/items/chest.svg"
        if (tile === "K") return "../assets/items/key.svg"
        if (tile === "S") return "../assets/items/shrine.svg"
        if (tile === "^") return "../assets/items/trap.svg"
        if (tile === "*") return "../assets/items/shard.svg"
        if (tile === "R") return "../assets/items/relic.svg"
        if (tile === "B") return "../assets/items/bomb.svg"
        return ""
    }
    Image {
        anchors.centerIn: parent
        width: parent.width * 0.68
        height: width
        visible: cell.visibleCell && cell.tile !== "#" && cell.tile !== "." && !cell.playerHere && cell.actorType.length === 0
        source: Qt.resolvedUrl(cell.tileIcon())
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    function enemyIcon() {
        if(actorType === "slime") return "../assets/enemies/slime.svg"
        if(actorType === "goblin") return "../assets/enemies/goblin.svg"
        if(actorType === "skeleton") return "../assets/enemies/skeleton.svg"
        if(actorType === "bat") return "../assets/enemies/bat.svg"
        if(actorType === "cultist") return "../assets/enemies/cultist.svg"
        if(actorType === "ogre") return "../assets/enemies/ogre.svg"
        if(actorType === "wraith") return "../assets/enemies/wraith.svg"
        if(actorType === "guardian") return "../assets/enemies/guardian.svg"
        return "../assets/enemies/goblin.svg"
    }

    Rectangle {
        visible: cell.visibleCell && cell.actorType === "guardian"
        anchors.centerIn: parent
        width: parent.width * 0.94
        height: width
        radius: width / 2
        color: "transparent"
        border.width: Math.max(1, parent.width * 0.05)
        border.color: cell.dangerColor
        opacity: 0.62
        SequentialAnimation on scale {
            running: cell.visible && cell.actorType === "guardian"
            loops: Animation.Infinite
            NumberAnimation { from: 0.94; to: 1.04; duration: 520; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.04; to: 0.94; duration: 520; easing.type: Easing.InOutSine }
        }
    }
    Image {
        anchors.centerIn: parent
        width: parent.width * (cell.actorType === "guardian" ? 0.92 : 0.80)
        height: width
        visible: cell.visibleCell && cell.actorType.length > 0
        source: Qt.resolvedUrl(cell.enemyIcon())
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    Rectangle {
        visible: cell.visibleCell && cell.actorType.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.max(1, parent.height * 0.035)
        width: parent.width * 0.72
        height: Math.max(2, parent.height * 0.055)
        radius: height / 2
        color: Qt.darker(cell.dangerColor, 1.6)
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, cell.actorHpRatio))
            height: parent.height
            radius: parent.radius
            color: cell.successColor
        }
    }

    Rectangle {
        visible: cell.playerHere
        anchors.centerIn: parent
        width: parent.width * 0.92
        height: width
        radius: width / 2
        color: Qt.rgba(cell.accentColor.r, cell.accentColor.g, cell.accentColor.b, 0.12)
        border.width: 1
        border.color: Qt.rgba(cell.accentColor.r, cell.accentColor.g, cell.accentColor.b, 0.48)
    }
    Image {
        anchors.centerIn: parent
        width: parent.width * 0.84
        height: width
        visible: cell.playerHere
        source: cell.heroClass === 0 ? Qt.resolvedUrl("../assets/characters/hero_knight.svg")
              : (cell.heroClass === 1 ? Qt.resolvedUrl("../assets/characters/hero_rogue.svg")
                                      : Qt.resolvedUrl("../assets/characters/hero_arcanist.svg"))
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    Rectangle {
        visible: cell.impactCell === cell.cellIndex && cell.impactProgress > 0
        anchors.centerIn: parent
        width: parent.width * (0.5 + 0.8 * cell.impactProgress)
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: cell.accentColor
        opacity: 1 - cell.impactProgress
    }
}
