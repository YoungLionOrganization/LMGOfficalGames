import QtQuick

Item {
    id: bus
    visible: false
    width: 0
    height: 0

    property real volume: 0.72
    property bool hostAvailable: false
    property bool hostPreloaded: false
    property string lastBackend: "none"
    readonly property bool preferLocalBackend: true

    readonly property var paths: ({
        "button":"../assets/sfx/button.wav",
        "select":"../assets/sfx/select.wav",
        "swap":"../assets/sfx/swap.wav",
        "invalid":"../assets/sfx/invalid.wav",
        "match":"../assets/sfx/match.wav",
        "cascade2":"../assets/sfx/cascade2.wav",
        "cascade3":"../assets/sfx/cascade3.wav",
        "line":"../assets/sfx/line.wav",
        "bomb":"../assets/sfx/bomb.wav",
        "prism":"../assets/sfx/prism.wav",
        "nova":"../assets/sfx/nova.wav",
        "combo":"../assets/sfx/combo.wav",
        "booster":"../assets/sfx/booster.wav",
        "shuffle":"../assets/sfx/shuffle.wav",
        "win":"../assets/sfx/win.wav",
        "fail":"../assets/sfx/fail.wav",
        "star":"../assets/sfx/star.wav"
    })

    function urlFor(name) {
        var rel = paths[name]
        return rel ? Qt.resolvedUrl(rel) : ""
    }

    function probeHost() {
        try {
            hostAvailable = typeof GameAudio !== "undefined" &&
                    typeof GameAudio.playEffect === "function"
        } catch (e) { hostAvailable = false }
        return hostAvailable
    }

    function preloadHost() {
        if (!probeHost()) return
        try {
            if (typeof GameAudio.preload !== "function") return
        } catch (e0) { return }
        var any = false
        for (var name in paths) {
            if (!Object.prototype.hasOwnProperty.call(paths, name)) continue
            var url = urlFor(name)
            try {
                // Host contract observed in LeoMiniGames accepts a single
                // resource URL. Never send keyed/multi-argument variants.
                if (url && String(url).length > 0) {
                    GameAudio.preload(url)
                    any = true
                }
            } catch (e1) {}
        }
        hostPreloaded = any
    }

    function playHost(name) {
        if (!probeHost()) return false
        var url = urlFor(name)
        if (!url || String(url).length === 0) return false
        try {
            GameAudio.playEffect(url)
            lastBackend = "GameAudio"
            return true
        } catch (e1) {}
        return false
    }

    function playLocal(name) {
        if (localLoader.status !== Loader.Ready || !localLoader.item) return false
        localLoader.item.enabled = enabled
        localLoader.item.volume = volume
        localLoader.item.play(name)
        lastBackend = "QtMultimedia-MediaPlayer"
        return true
    }

    function play(name) {
        if (!enabled) return
        // External RCC audio on Android/iOS is deliberately played through the
        // same QtMultimedia MediaPlayer path that is known to work for current
        // LeoMiniGames market RCCs. Desktop prefers the host mixer so the main
        // application's audio group/volume policy remains authoritative.
        if (playLocal(name)) return
        if (playHost(name)) return
    }

    function pauseAll() {
        try { if (hostAvailable && typeof GameAudio.pauseAll === "function") GameAudio.pauseAll() } catch (e) {}
        if (localLoader.status === Loader.Ready && localLoader.item) localLoader.item.pauseAll()
    }

    function resumeAll() {
        try { if (hostAvailable && typeof GameAudio.resumeAll === "function") GameAudio.resumeAll() } catch (e) {}
        if (localLoader.status === Loader.Ready && localLoader.item) localLoader.item.resumeAll()
    }

    Loader {
        id: localLoader
        active: true
        asynchronous: true
        source: "LocalAudioFallback.qml"
        onLoaded: {
            if (item) {
                item.enabled = bus.enabled
                item.volume = bus.volume
            }
        }
    }

    Component.onCompleted: {
        probeHost()
        // Local MediaPlayer is the primary backend on every platform. Avoid
        // eagerly preloading the same RCC WAVs through the host as well; that
        // produced duplicate FFmpeg/temp-file work and noisy runtime logs.
        localLoader.active = true
    }
}
