import QtQuick

Item {
    id: root
    property bool reducedMotion: false
    property int seasonIndex: 0
    property string label: ""
    property real progress: 0
    property bool active: false
    signal finished()

    anchors.fill: parent
    visible: active
    enabled: false

    function effectSource() {
        if (seasonIndex === 0) return Qt.resolvedUrl("assets/effects/petal.svg")
        if (seasonIndex === 1) return Qt.resolvedUrl("assets/effects/pollen.svg")
        if (seasonIndex === 2) return Qt.resolvedUrl("assets/effects/autumn_leaf.svg")
        return Qt.resolvedUrl("assets/effects/snowflake.svg")
    }

    function seasonSource() {
        return Qt.resolvedUrl("assets/seasons/" + ["spring","summer","autumn","winter"][Math.max(0, Math.min(3, seasonIndex))] + ".svg")
    }

    function cancel() {
        seq.stop()
        progress = 0
        active = false
    }

    function play(indexValue, labelValue) {
        seasonIndex = Math.max(0, Math.min(3, Number(indexValue || 0)))
        label = String(labelValue || "")
        progress = 0
        active = true
        seq.restart()
    }

    Rectangle {
        anchors.fill: parent
        color: GameTheme.color("color.background")
        opacity: 0.06
    }

    Repeater {
        model: root.reducedMotion ? 3 : 6
        Image {
            required property int index
            width: root.seasonIndex === 3 ? 17 : 15
            height: width
            source: root.effectSource()
            fillMode: Image.PreserveAspectFit
            cache: true
            opacity: root.reducedMotion ? 0.20 : 0.42 * Math.min(1, root.progress * 5) * Math.min(1, (1-root.progress) * 5)
            x: ((index * 137 + 34) % Math.max(1, root.width - width)) + (root.seasonIndex === 2 && !root.reducedMotion ? Math.sin((root.progress + index) * 3.4) * 14 : 0)
            y: root.reducedMotion
               ? ((index * 101 + 28) % Math.max(1, root.height - height))
               : -height + ((root.height + height * 2) * ((root.progress + index * 0.169) % 1.0))
            rotation: root.reducedMotion ? 0 : (index * 31 + root.progress * (root.seasonIndex === 2 ? 190 : 90))
        }
    }

    UiPanel {
        anchors.centerIn: parent
        width: Math.min(Math.max(250, parent.width * 0.44), 410)
        implicitHeight: seasonRow.implicitHeight + 28
        opacity: Math.min(1, root.progress * 5) * Math.min(1, (1-root.progress) * 5)
        surfaceToken: "surface.raised"

        Row {
            id: seasonRow
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 48
                source: root.seasonSource()
                fillMode: Image.PreserveAspectFit
                cache: true
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(130, seasonRow.width - 62)
                text: root.label
                font.bold: true
                sizeToken: "metric.font.xl"
                maximumLineCount: 1
                elide: Text.ElideRight
            }
        }
    }

    SequentialAnimation {
        id: seq
        NumberAnimation { target: root; property: "progress"; from: 0; to: 1; duration: root.reducedMotion ? 260 : 660; easing.type: Easing.InOutQuad }
        PauseAnimation { duration: root.reducedMotion ? 20 : 55 }
        ScriptAction { script: { root.active = false; root.finished() } }
    }
}
