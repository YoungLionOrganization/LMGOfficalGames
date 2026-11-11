import QtQuick

Item {
    id: root
    property bool reducedMotion: false
    property bool ambientEnabled: false
    property string weatherKey: "sunny"
    property real phase: 0

    visible: ambientEnabled
    enabled: false
    clip: true
    opacity: reducedMotion ? 0.10 : 0.22

    function effectSource() {
        if (weatherKey === "rain" || weatherKey === "storm") return Qt.resolvedUrl("assets/effects/rain_streak.svg")
        if (weatherKey === "wind") return Qt.resolvedUrl("assets/effects/wind_streak.svg")
        if (weatherKey === "heatwave") return Qt.resolvedUrl("assets/effects/heat_line.svg")
        if (weatherKey === "frost") return Qt.resolvedUrl("assets/effects/frost_crystal.svg")
        if (weatherKey === "cloudy") return Qt.resolvedUrl("assets/effects/cloud.svg")
        return Qt.resolvedUrl("assets/effects/sun_ray.svg")
    }

    function poolSize() {
        if (weatherKey === "rain" || weatherKey === "storm") return 10
        if (weatherKey === "cloudy") return 4
        if (weatherKey === "wind") return 5
        if (weatherKey === "frost") return 5
        return 3
    }

    NumberAnimation {
        target: root
        property: "phase"
        from: 0
        to: 1
        duration: root.weatherKey === "storm" ? 3100 : 6100
        loops: Animation.Infinite
        running: root.ambientEnabled && root.visible && !root.reducedMotion
    }

    Repeater {
        model: root.poolSize()
        Image {
            required property int index
            width: root.weatherKey === "cloudy" ? 62 : (root.weatherKey === "sunny" ? 30 : 15)
            height: root.weatherKey === "cloudy" ? 34 : (root.weatherKey === "sunny" ? 30 : 28)
            source: root.effectSource()
            fillMode: Image.PreserveAspectFit
            cache: true
            opacity: root.weatherKey === "storm" ? 0.70 : 0.58
            x: root.reducedMotion
               ? ((index * 97) % Math.max(1, root.width - width))
               : ((root.weatherKey === "wind" || root.weatherKey === "cloudy")
                  ? -width + ((root.width + width * 2) * ((root.phase + index * 0.157) % 1.0))
                  : ((index * 97) % Math.max(1, root.width - width)))
            y: root.reducedMotion
               ? ((index * 71) % Math.max(1, root.height - height))
               : ((root.weatherKey === "rain" || root.weatherKey === "storm")
                  ? -height + ((root.height + height * 2) * ((root.phase + index * 0.097) % 1.0))
                  : ((index * 71) % Math.max(1, root.height - height)))
            rotation: root.weatherKey === "rain" || root.weatherKey === "storm" ? 9 : 0
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: root.weatherKey === "frost" ? 3 : 0
        border.color: GameTheme.color("color.border")
        opacity: root.weatherKey === "frost" ? 0.34 : 0
    }

    Image {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 16
        width: 54
        height: 54
        source: Qt.resolvedUrl("assets/weather/sunny.svg")
        fillMode: Image.PreserveAspectFit
        visible: root.weatherKey === "sunny" || root.weatherKey === "heatwave"
        opacity: root.weatherKey === "heatwave" ? 0.52 : 0.34
        cache: true
    }

    Image {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.22
        height: width
        source: Qt.resolvedUrl("assets/effects/lightning.svg")
        fillMode: Image.PreserveAspectFit
        visible: root.weatherKey === "storm" && !root.reducedMotion && root.phase > 0.46 && root.phase < 0.485
        opacity: 0.18
        cache: true
    }
}
