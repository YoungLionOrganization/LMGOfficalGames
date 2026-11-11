import QtQuick

Item {
    id: root
    property bool reducedMotion: false
    property string weatherKey: "sunny"
    property string label: ""
    property real progress: 0
    property bool active: false
    signal finished()

    anchors.fill: parent
    visible: active
    enabled: false

    function weatherSource() {
        return Qt.resolvedUrl("assets/weather/" + weatherKey + ".svg")
    }

    function effectSource() {
        if (weatherKey === "rain" || weatherKey === "storm") return Qt.resolvedUrl("assets/effects/rain_streak.svg")
        if (weatherKey === "wind") return Qt.resolvedUrl("assets/effects/wind_streak.svg")
        if (weatherKey === "heatwave") return Qt.resolvedUrl("assets/effects/heat_line.svg")
        if (weatherKey === "frost") return Qt.resolvedUrl("assets/effects/frost_crystal.svg")
        if (weatherKey === "cloudy") return Qt.resolvedUrl("assets/effects/cloud.svg")
        return Qt.resolvedUrl("assets/effects/sun_ray.svg")
    }

    function cancel() {
        seq.stop()
        progress = 0
        active = false
    }

    function play(keyValue, labelValue) {
        weatherKey = String(keyValue || "sunny")
        label = String(labelValue || "")
        progress = 0
        active = true
        seq.restart()
    }

    Rectangle {
        anchors.fill: parent
        color: GameTheme.color("color.background")
        opacity: 0.05
    }

    Repeater {
        model: root.reducedMotion ? 2 : 5
        Image {
            required property int index
            width: root.weatherKey === "cloudy" ? 58 : (root.weatherKey === "sunny" ? 34 : 17)
            height: root.weatherKey === "cloudy" ? 32 : (root.weatherKey === "sunny" ? 34 : 30)
            source: root.effectSource()
            fillMode: Image.PreserveAspectFit
            cache: true
            opacity: root.reducedMotion ? 0.18 : 0.36 * Math.min(1, root.progress * 5) * Math.min(1, (1-root.progress) * 5)
            x: root.weatherKey === "wind" || root.weatherKey === "cloudy"
               ? -width + ((root.width + width * 2) * ((root.progress + index * 0.213) % 1.0))
               : ((index * 149 + 23) % Math.max(1, root.width - width))
            y: root.weatherKey === "rain" || root.weatherKey === "storm"
               ? -height + ((root.height + height * 2) * ((root.progress + index * 0.181) % 1.0))
               : ((index * 103 + 41) % Math.max(1, root.height - height))
            rotation: root.weatherKey === "rain" || root.weatherKey === "storm" ? 9 : 0
        }
    }

    UiPanel {
        anchors.centerIn: parent
        width: Math.min(Math.max(250, parent.width * 0.44), 410)
        implicitHeight: weatherRow.implicitHeight + 28
        opacity: Math.min(1, root.progress * 5) * Math.min(1, (1-root.progress) * 5)
        surfaceToken: "surface.raised"

        Row {
            id: weatherRow
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 48
                source: root.weatherSource()
                fillMode: Image.PreserveAspectFit
                cache: true
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(130, weatherRow.width - 62)
                text: root.label
                font.bold: true
                sizeToken: "metric.font.lg"
                maximumLineCount: 1
                elide: Text.ElideRight
            }
        }
    }

    Image {
        anchors.centerIn: parent
        width: 92
        height: 92
        source: Qt.resolvedUrl("assets/effects/lightning.svg")
        fillMode: Image.PreserveAspectFit
        visible: root.weatherKey === "storm" && !root.reducedMotion && root.progress > 0.44 && root.progress < 0.48
        opacity: 0.25
        cache: true
    }

    SequentialAnimation {
        id: seq
        NumberAnimation { target: root; property: "progress"; from: 0; to: 1; duration: root.reducedMotion ? 240 : 600; easing.type: Easing.InOutQuad }
        PauseAnimation { duration: root.reducedMotion ? 20 : 45 }
        ScriptAction { script: { root.active = false; root.finished() } }
    }
}
