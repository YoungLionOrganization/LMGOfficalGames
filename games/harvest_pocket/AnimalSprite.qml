import QtQuick

Item {
    id: root
    property string animalId: "chicken"
    property int spriteIndex: 0
    property int animationPulse: 0
    property bool reducedMotion: false
    property real happiness: 50
    property bool visibleScene: true
    readonly property int activityBucket: (spriteIndex * 3 + animalId.length) % 4
    readonly property bool activeMove: (animationPulse % 4) === activityBucket
    readonly property string visualState: happiness >= 80 ? "happy" : (((animationPulse + spriteIndex*3) % 11) === 0 ? "sleep" : "idle")
    implicitWidth: 72
    implicitHeight: 64
    visible: visibleScene

    Image {
        id: art
        anchors.centerIn: parent
        width: parent.width * 0.92
        height: parent.height * 0.92
        source: Qt.resolvedUrl("assets/animals/"+root.animalId+"_"+root.visualState+".svg")
        fillMode: Image.PreserveAspectFit
        cache: true
        smooth: true
        transformOrigin: Item.Bottom
        rotation: root.reducedMotion || !root.activeMove ? 0 : ((root.spriteIndex % 2 === 0 ? -1 : 1) * (root.animalId === "bee" ? 3.0 : 1.25))
        y: root.reducedMotion || !root.activeMove ? 0 : (root.animalId === "bee" ? -3 : -2)
        Behavior on rotation { NumberAnimation { duration: root.reducedMotion ? 0 : 520; easing.type: Easing.InOutSine } }
        Behavior on y { NumberAnimation { duration: root.reducedMotion ? 0 : 420; easing.type: Easing.OutQuad } }
    }
}
