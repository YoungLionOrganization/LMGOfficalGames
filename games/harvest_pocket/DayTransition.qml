import QtQuick

Item {
    id: root
    property bool reducedMotion: false
    property string label: ""
    property bool active: false
    signal blackoutReached()
    signal finished()

    anchors.fill: parent
    visible: active || shade.opacity > 0.001
    enabled: active

    function begin() {
        if (active) return
        active = true
        shade.opacity = 0
        fadeToBlack.restart()
    }

    function reveal() {
        if (!active) return
        revealScene.restart()
    }

    function forceFinish() {
        fadeToBlack.stop()
        revealScene.stop()
        shade.opacity = 0
        var wasActive = active
        active = false
        if (wasActive) finished()
    }

    Rectangle {
        id: shade
        anchors.fill: parent
        color: "#000000"
        opacity: 0
    }

    UiPanel {
        id: card
        anchors.centerIn: parent
        width: Math.min(Math.max(240, parent.width * 0.42), 390)
        implicitHeight: transitionRow.implicitHeight + 28
        opacity: Math.max(0, Math.min(1, (shade.opacity - 0.48) / 0.34))
        surfaceToken: "surface.raised"

        Row {
            id: transitionRow
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 38
                source: Qt.resolvedUrl("assets/ui/next_day.svg")
                fillMode: Image.PreserveAspectFit
                cache: true
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(120, transitionRow.width - 50)
                spacing: 4
                UiText {
                    width: parent.width
                    text: root.label
                    horizontalAlignment: Text.AlignLeft
                    font.bold: true
                    sizeToken: "metric.font.lg"
                }
                Rectangle {
                    width: Math.min(parent.width, 150)
                    height: 2
                    radius: 1
                    color: GameTheme.color("color.accent")
                    opacity: 0.72
                }
            }
        }
    }

    TapHandler { enabled: root.active }

    SequentialAnimation {
        id: fadeToBlack
        NumberAnimation {
            target: shade
            property: "opacity"
            from: 0
            to: 1
            duration: root.reducedMotion ? 90 : 330
            easing.type: Easing.InOutQuad
        }
        PauseAnimation { duration: root.reducedMotion ? 30 : 90 }
        ScriptAction { script: root.blackoutReached() }
    }

    SequentialAnimation {
        id: revealScene
        PauseAnimation { duration: root.reducedMotion ? 20 : 70 }
        NumberAnimation {
            target: shade
            property: "opacity"
            to: 0
            duration: root.reducedMotion ? 120 : 390
            easing.type: Easing.InOutQuad
        }
        ScriptAction {
            script: {
                root.active = false
                root.finished()
            }
        }
    }
}
