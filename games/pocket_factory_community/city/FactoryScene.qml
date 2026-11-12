import QtQuick
import "CityData.js" as Data

FocusScope {
    id: root
    objectName: "factoryScene"
    required property var city
    required property var lines
    required property var buildingLevels
    required property int researchLevel
    required property var prefs
    required property var translate
    property int selectedZone: -1
    property bool paused: false
    signal zoneSelected(int zone)
    readonly property var connections: [[0, 1], [1, 3], [1, 2], [3, 4], [0, 5], [4, 6], [2, 6]]
    readonly property int maxDetails: prefs.mode === 1 ? 24 : 48
    property real zoom: 1
    property real settledZoom: 1
    readonly property real fit: Math.min(width / 960, height / 540)
    readonly property real scaleFactor: Math.max(0.01, fit * zoom)
    readonly property int sourcePixels: prefs.mode === 1 ? (settledZoom < 1.6 ? 144 : 192) :
                                        (settledZoom < 1.6 ? 192 : settledZoom < 2.4 ? 256 : 384)
    readonly property bool animate: visible && !paused && prefs.mode === 2 && prefs.showFlow && !prefs.reducedMotion
    property real flowPhase: 0
    readonly property real mapX: Math.max(0, (viewport.width - 960 * scaleFactor) / 2)
    readonly property real mapY: Math.max(0, (viewport.height - 540 * scaleFactor) / 2)

    function opened(zone) {
        return Data.layout[zone][2] <= city.district || city.state.projects[Data.projectZones.indexOf(zone)] > 0
    }
    function lineFor(zone) {
        var index = Math.min(lines.length - 1, [0, 1, 2, 2, lines.length - 1, 0, 0][zone])
        return lines[index]
    }
    function variant(zone) {
        var index = [0, 1, 2, 2, buildingLevels.length - 1, 0, 0][zone]
        var level = buildingLevels[Math.min(buildingLevels.length - 1, index)] || 0
        var project = city.state.projects[Data.projectZones.indexOf(zone)] || 0
        if (zone === 6 && city.district === 4) return 2
        if (zone === 2 && researchLevel > 0) project = Math.max(project, 2)
        return Math.min(2, Math.max(Math.floor(project * 2 / 3), level >= 8 ? 2 : level >= 2 ? 1 : 0))
    }
    function inView(x, y) {
        var xx = mapX + x * scaleFactor
        var yy = mapY + y * scaleFactor
        return xx >= viewport.contentX - 100 && xx <= viewport.contentX + viewport.width + 100 &&
                yy >= viewport.contentY - 80 && yy <= viewport.contentY + viewport.height + 80
    }
    function changeZoom(amount) {
        var x = (viewport.contentX + width / 2 - mapX) / scaleFactor
        var y = (viewport.contentY + height / 2 - mapY) / scaleFactor
        zoom = Math.max(1, Math.min(3, amount))
        viewport.contentX = Math.max(0, Math.min(viewport.contentWidth - width, mapX + x * scaleFactor - width / 2))
        viewport.contentY = Math.max(0, Math.min(viewport.contentHeight - height, mapY + y * scaleFactor - height / 2))
    }
    function stepZoom(factor) {
        changeZoom(zoom * factor)
        settledZoom = zoom
    }
    readonly property var details: {
        var result = []
        for (var i = 0; i < Data.layout.length; ++i) {
            var tile = Data.layout[i]
            if (!opened(i)) continue
            var family = tile[3]
            var count = city.state.patents[family]
            if (settledZoom < 1.45) count = Math.min(count, 1)
            for (var j = 0; j < count; ++j)
                result.push({ x: tile[0] - 42 + j * 38, y: tile[1] + 38,
                              source: "assets/patent_" + (family * 3 + j) + ".svg" })
            var project = Data.projectZones.indexOf(i)
            var phase = project < 0 ? 0 : city.state.projects[project]
            if (phase > 0) {
                for (var stage = 0; stage < (settledZoom < 1.45 ? 1 : phase); ++stage)
                    result.push({ x: tile[0] + 53 + stage * 19, y: tile[1] - 24 + stage * 9,
                                  source: "assets/tile_" + i + "_" + (settledZoom < 1.45 ? phase - 1 : stage) + ".svg" })
            }
            if (i === 1 && researchLevel > 0)
                result.push({ x: tile[0] + 62, y: tile[1] - 23, source: "assets/tile_2_0.svg" })
        }
        var hall = Data.layout[1]
        if (opened(1)) {
            for (var line = 0; line < buildingLevels.length; ++line) {
                var size = buildingLevels[line] >= 8 ? 2 : buildingLevels[line] >= 2 ? 1 : 0
                if (size > 0)
                    result.push({ x: hall[0] - 62 + line * 23, y: hall[1] - 35 - (line % 2) * 14,
                                  source: "assets/tile_" + (line % 6) + "_" + size + ".svg" })
            }
        }
        return result.slice(0, maxDetails - Data.layout.length)
    }

    NumberAnimation on flowPhase {
        running: root.animate
        from: 0
        to: 1
        loops: Animation.Infinite
        duration: 2800
    }
    Rectangle { anchors.fill: parent; radius: 10; color: "#142e34"; border.color: "#517d75" }
    Flickable {
        id: viewport
        objectName: "factoryViewport"
        anchors.fill: parent
        clip: true
        interactive: root.zoom > 1 && !pinch.active
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: Math.max(width, 960 * root.scaleFactor)
        contentHeight: Math.max(height, 540 * root.scaleFactor)

        Item {
            x: root.mapX
            y: root.mapY
            width: 960 * root.scaleFactor
            height: 540 * root.scaleFactor

            Image {
                anchors.fill: parent
                source: root.city.district === 4 ? "assets/terrain_city.svg" : "assets/terrain.svg"
                sourceSize.width: root.sourcePixels * 3
                asynchronous: true
            }
            Repeater {
                model: root.connections
                delegate: Rectangle {
                    required property var modelData
                    readonly property var a: Data.layout[modelData[0]]
                    readonly property var b: Data.layout[modelData[1]]
                    readonly property var line: root.lineFor(modelData[0])
                    visible: root.opened(modelData[0]) && root.opened(modelData[1])
                    x: a[0] * root.scaleFactor
                    y: a[1] * root.scaleFactor
                    width: Math.hypot(b[0] - a[0], b[1] - a[1]) * root.scaleFactor
                    height: Math.max(2, 7 * root.scaleFactor)
                    transformOrigin: Item.TopLeft
                    rotation: Math.atan2(b[1] - a[1], b[0] - a[0]) * 180 / Math.PI
                    color: root.prefs.showFlow && line && line.status === 0 ? "#9abda1" : "#546a64"
                    Rectangle {
                        visible: root.animate && parent.line && parent.line.status === 0
                        x: Math.max(0, (parent.width - width) * root.flowPhase)
                        width: Math.min(14, parent.width)
                        height: parent.height
                        color: "#ffe2a0"
                        radius: 2
                    }
                }
            }
            Repeater {
                model: Data.layout
                delegate: Item {
                    id: tile
                    required property int index
                    required property var modelData
                    readonly property bool inView: root.opened(index) && root.inView(modelData[0], modelData[1])
                    readonly property var line: root.lineFor(index)
                    readonly property int status: line ? line.status : 0
                    width: 166 * root.scaleFactor
                    height: 108 * root.scaleFactor
                    x: modelData[0] * root.scaleFactor - width / 2
                    y: modelData[1] * root.scaleFactor - height / 2
                    visible: inView
                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        source: tile.inView ? "assets/tile_" + tile.index + "_" + root.variant(tile.index) + ".svg" : ""
                        sourceSize.width: root.sourcePixels
                        asynchronous: true
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: root.selectedZone === tile.index
                        radius: 7
                        color: "transparent"
                        border.color: "#ffe2a0"
                        border.width: 2
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        visible: root.prefs.showFlow && tile.status !== 0
                        spacing: 2
                        Repeater {
                            model: tile.status === 2 ? 5 : 1
                            Rectangle { width: 3; height: 10; radius: 1; rotation: 34; color: "#ffe099" }
                        }
                    }
                    TapHandler {
                        enabled: tile.inView
                        onTapped: { root.forceActiveFocus(); root.zoneSelected(tile.index) }
                    }
                }
            }
            Repeater {
                model: root.details
                delegate: Loader {
                    id: detail
                    required property var modelData
                    x: (modelData.x - 20) * root.scaleFactor
                    y: (modelData.y - 18) * root.scaleFactor
                    width: 40 * root.scaleFactor
                    height: 29 * root.scaleFactor
                    active: root.inView(modelData.x, modelData.y)
                    asynchronous: true
                    sourceComponent: Image {
                        source: detail.modelData.source
                        sourceSize.width: root.prefs.mode === 1 ? 64 : 96
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                }
            }
        }
        PinchHandler {
            id: pinch
            target: null
            property real startZoom: 1
            onActiveChanged: {
                if (active) startZoom = root.zoom
                else root.settledZoom = root.zoom
            }
            onActiveScaleChanged: if (active) root.changeZoom(startZoom * activeScale)
        }
    }
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        spacing: 5
        CityButton {
            text: "−"; width: 46
            Accessible.name: root.translate("city.zoom_out", "Zoom out")
            enabled: root.zoom > 1
            onActivated: root.stepZoom(1 / 1.4)
        }
        CityButton {
            text: "+"; width: 46
            Accessible.name: root.translate("city.zoom_in", "Zoom in")
            enabled: root.zoom < 3
            onActivated: root.stepZoom(1.4)
        }
    }
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Plus || event.key === Qt.Key_Minus) {
            stepZoom(event.key === Qt.Key_Plus ? 1.4 : 1 / 1.4)
            event.accepted = true
        }
    }
}
