import QtQuick

Item {
    id: root
    property bool reducedMotion: false
    property int cursor: 0

    function show(message, iconSource, valueColorToken) {
        if (!message || String(message).length === 0) return
        var item = pool.itemAt(cursor)
        if (!item) return
        cursor = (cursor + 1) % 3
        item.play(String(message), iconSource, valueColorToken || "color.accent")
    }

    Repeater {
        id: pool
        model: 3
        delegate: Item {
            id: toast
            required property int index
            property string message: ""
            property url iconSource
            property string valueColorToken: "color.accent"
            width: Math.min(260, Math.max(170, root.width - 28))
            height: 48
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height * 0.48 + index * 6
            opacity: 0
            visible: opacity > 0.001
            z: 30 + index

            function play(nextMessage, nextIcon, nextToken) {
                message = nextMessage
                iconSource = nextIcon
                valueColorToken = nextToken
                animation.stop()
                opacity = 0
                y = root.height * 0.48 + index * 6
                if (root.reducedMotion) {
                    opacity = 1
                    animationReduced.restart()
                } else {
                    animation.restart()
                }
            }

            UiPanel {
                anchors.fill: parent
                surfaceToken: "surface.control"
                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 7
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        source: toast.iconSource
                        fillMode: Image.PreserveAspectFit
                        cache: true
                    }
                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(90, parent.width - 35)
                        text: toast.message
                        font.bold: true
                        colorToken: toast.valueColorToken
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }
                }
            }

            SequentialAnimation {
                id: animation
                ParallelAnimation {
                    NumberAnimation { target: toast; property: "opacity"; from: 0; to: 1; duration: 110 }
                    NumberAnimation { target: toast; property: "y"; from: root.height * 0.48 + toast.index * 6; to: root.height * 0.42 + toast.index * 6; duration: 520; easing.type: Easing.OutCubic }
                }
                PauseAnimation { duration: 480 }
                NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 180 }
            }

            SequentialAnimation {
                id: animationReduced
                PauseAnimation { duration: 650 }
                NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 80 }
            }
        }
    }
}
