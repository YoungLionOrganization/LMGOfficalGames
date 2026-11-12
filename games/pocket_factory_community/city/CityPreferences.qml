import QtQuick

QtObject {
    id: root
    objectName: "factoryPreferences"
    readonly property bool mobile: Qt.platform.os === "android" || Qt.platform.os === "ios"
    property int mode: mobile ? 1 : 2
    property bool reducedMotion: false
    property bool showFlow: true

    function load() {
        var value = GameSettings.value("factoryScene", mobile ? 1 : 2)
        mode = value === 0 || value === 1 || value === 2 ? value : (mobile ? 1 : 2)
        reducedMotion = Boolean(GameSettings.value("reducedMotion", false))
        showFlow = Boolean(GameSettings.value("factoryShowFlow", true))
    }

    function set(key, value) {
        GameSettings.setValue(key, value)
        load()
    }

    property Connections settingsObserver: Connections {
        target: GameSettings
        ignoreUnknownSignals: true
        function onGameChanged() { root.load() }
        function onValueChanged(key, value) { root.load() }
    }
    Component.onCompleted: load()
}
