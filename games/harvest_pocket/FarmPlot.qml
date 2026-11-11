import QtQuick

Item {
    id: root
    property int plotIndex: 0
    property var plotData: ({crop:"",age:0,watered:false,fertilized:false,qualityHint:0})
    property url soilSource
    property url cropSource
    property bool selected: false
    property bool unlocked: true
    property bool sprinklerCovered: false
    property string waterSource: ""
    property string fieldState: "empty"
    property int zoneIndex: 0
    property int zoneCoverage: 0
    property bool selectedZone: false
    property bool greenhouseCovered: false
    property bool ready: false
    property bool reducedMotion: false
    property int animationPulse: 0
    property real swayAmount: 0.8
    property string statusText: ""
    property int actionSerial: 0
    property string actionKind: ""
    property bool actionActive: false
    property url wateringToolSource: Qt.resolvedUrl("assets/tools/watering_basic.svg")
    signal activated(int index)

    implicitWidth: 82
    implicitHeight: 82
    opacity: unlocked ? 1.0 : 0.34

    Image {
        anchors.fill: parent
        source: root.soilSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: false
        cache: true
    }

    Image {
        anchors.fill: parent
        anchors.margins: 3
        source: Qt.resolvedUrl("assets/field/greenhouse_overlay.svg")
        fillMode: Image.PreserveAspectFit
        visible: root.greenhouseCovered
        opacity: 0.45
        cache: true
    }

    Item {
        id: cropHolder
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 7
        width: parent.width * 0.70
        height: parent.height * 0.70
        transformOrigin: Item.Bottom
        // Only one sixth of plots starts an idle sway on each shared pulse.
        // The previously active bucket settles back to zero, keeping the farm
        // alive without running near-continuous animations on all 40 plots.
        readonly property int swayBucket: (root.plotIndex * 5) % 6
        readonly property bool swayActive: (root.animationPulse % 6) === swayBucket
        rotation: root.reducedMotion || !root.plotData || root.plotData.crop==="" ? 0 : (swayActive ? (((root.plotIndex % 2)===0 ? -1 : 1) * root.swayAmount) : 0)
        scale: root.ready && !root.reducedMotion && swayActive ? 1.025 : 1.0
        Behavior on rotation { NumberAnimation { duration: root.reducedMotion ? 0 : 760; easing.type: Easing.InOutSine } }
        Behavior on scale { NumberAnimation { duration: root.reducedMotion ? 0 : 650; easing.type: Easing.InOutSine } }
        Image {
            id: cropArt
            anchors.fill: parent
            source: root.cropSource
            fillMode: Image.PreserveAspectFit
            smooth: true
            cache: true
            opacity: root.plotData && root.plotData.crop!=="" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.reducedMotion ? 0 : 170 } }
            onSourceChanged: if (!root.reducedMotion && source.toString().length > 0) growthAnim.restart()
            NumberAnimation { id:growthAnim; target:cropArt; property:"scale"; from:0.82; to:1.0; duration:260; easing.type:Easing.OutBack }
        }
    }

    Image {
        id: toolArt
        width: parent.width * 0.48
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        y: 5
        z: 9
        opacity: 0
        fillMode: Image.PreserveAspectFit
        cache: true
        source: root.actionKind === "water" ? root.wateringToolSource : (root.actionKind === "fertilize" ? Qt.resolvedUrl("assets/tools/fertilizer_bag.svg") : (root.actionKind === "harvest" ? Qt.resolvedUrl("assets/tools/basket.svg") : Qt.resolvedUrl("assets/tools/hoe.svg")))
        onVisibleChanged: if (visible && root.actionActive && !root.reducedMotion) toolAnim.restart()
    }
    ParallelAnimation {
        id: toolAnim
        NumberAnimation { target:toolArt; property:"opacity"; from:0; to:1; duration:90 }
        SequentialAnimation {
            NumberAnimation { target:toolArt; property:"rotation"; from:-9; to:10; duration:130; easing.type:Easing.OutQuad }
            NumberAnimation { target:toolArt; property:"rotation"; to:0; duration:150; easing.type:Easing.InOutQuad }
        }
        SequentialAnimation {
            NumberAnimation { target:toolArt; property:"y"; from:2; to:12; duration:130 }
            NumberAnimation { target:toolArt; property:"y"; to:5; duration:150 }
        }
        onFinished: toolArt.opacity = 0
    }
    onActionSerialChanged: {
        if (root.actionActive && !root.reducedMotion) toolAnim.restart()
    }

    Image {
        width: 22; height: 22
        anchors.left: parent.left; anchors.bottom: parent.bottom
        anchors.margins: 4
        source: Qt.resolvedUrl("assets/field/sprinkler_overlay.svg")
        fillMode: Image.PreserveAspectFit
        visible: root.sprinklerCovered
        opacity: 0.75
        cache: true
    }
    Image {
        width: 18; height: 18
        anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 4
        source: root.waterSource === "sprinkler" ? Qt.resolvedUrl("assets/tools/sprinkler.svg")
              : (root.waterSource === "rain" ? Qt.resolvedUrl("assets/weather/rain.svg")
              : (root.waterSource === "storm" ? Qt.resolvedUrl("assets/weather/storm.svg")
              : Qt.resolvedUrl("assets/ui/water.svg")))
        fillMode: Image.PreserveAspectFit
        visible: !!root.plotData && root.plotData.crop !== "" && root.waterSource.length > 0
        cache: true
    }
    Image {
        width: 19; height: 19
        anchors.left: parent.left; anchors.top: parent.top
        anchors.margins: 4
        source: Qt.resolvedUrl("assets/tools/basket.svg")
        fillMode: Image.PreserveAspectFit
        visible: root.ready
        opacity: root.ready && !root.reducedMotion ? ((root.animationPulse % 2) === 0 ? 0.72 : 1.0) : 1.0
        cache: true
        Behavior on opacity { NumberAnimation { duration: root.reducedMotion ? 0 : 260 } }
    }
    Image {
        width: 18; height: 18
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 4
        source: Qt.resolvedUrl("assets/ui/fertilizer.svg")
        fillMode: Image.PreserveAspectFit
        visible: !!root.plotData && root.plotData.crop !== "" && !!root.plotData.fertilized
        cache: true
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 8
        visible: root.selectedZone && root.unlocked
        color: "transparent"
        border.width: 1
        border.color: GameTheme.color("color.primary")
        opacity: 0.22
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 3
        radius: 1
        visible: root.unlocked && root.sprinklerCovered
        color: GameTheme.color("color.primary")
        opacity: root.zoneCoverage >= 8 ? 0.52 : 0.28
    }

    Rectangle {
        anchors.fill: parent
        radius: 9
        color: "transparent"
        border.width: root.ready ? 3 : (root.selected ? 3 : 1)
        border.color: root.ready ? GameTheme.color("color.accent") : (root.selected ? GameTheme.color("color.primary") : GameTheme.color("color.border"))
        opacity: root.ready && !root.reducedMotion ? ((root.animationPulse % 2) === 0 ? 0.78 : 1.0) : 1.0
        Behavior on opacity { NumberAnimation { duration: root.reducedMotion ? 0 : 260 } }
    }

    Rectangle {
        anchors.fill: parent
        radius: 9
        visible: !root.unlocked
        color: GameTheme.color("color.surfaceRaised")
        opacity: 0.58
        Image { anchors.centerIn: parent; width: 26; height: 26; source: Qt.resolvedUrl("assets/ui/locked.svg"); fillMode: Image.PreserveAspectFit }
    }

    TapHandler { enabled: root.unlocked; onTapped: root.activated(root.plotIndex) }
    HoverHandler { id: hover; enabled: root.unlocked }
    scale: hover.hovered && !root.reducedMotion ? 1.025 : 1.0
    Behavior on scale { NumberAnimation { duration: root.reducedMotion ? 0 : 100 } }
}
