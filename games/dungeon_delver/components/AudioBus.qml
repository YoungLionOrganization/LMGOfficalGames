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
    readonly property bool preferLocalBackend: Qt.platform.os === "android" || Qt.platform.os === "ios"

    readonly property var paths: ({
        "start":"../sfx/start.wav",
        "step":"../sfx/step.wav",
        "wall":"../sfx/wall.wav",
        "swing":"../sfx/swing.wav",
        "hit":"../sfx/hit.wav",
        "hurt":"../sfx/hurt.wav",
        "enemy_die":"../sfx/enemy_die.wav",
        "coin":"../sfx/coin.wav",
        "potion":"../sfx/potion.wav",
        "chest":"../sfx/chest.wav",
        "key":"../sfx/key.wav",
        "shrine":"../sfx/shrine.wav",
        "trap":"../sfx/trap.wav",
        "stairs":"../sfx/stairs.wav",
        "level":"../sfx/level.wav",
        "bomb":"../sfx/bomb.wav",
        "boss_roar":"../sfx/boss_roar.wav",
        "boss_die":"../sfx/boss_die.wav",
        "shop":"../sfx/shop.wav",
        "buy":"../sfx/buy.wav",
        "upgrade":"../sfx/upgrade.wav",
        "relic":"../sfx/relic.wav",
        "shard":"../sfx/shard.wav",
        "skill_guard":"../sfx/skill_guard.wav",
        "skill_rogue":"../sfx/skill_rogue.wav",
        "skill_arcane":"../sfx/skill_arcane.wav",
        "fail":"../sfx/fail.wav",
        "button":"../sfx/button.wav"
    })

    function urlFor(name) {
        var rel = paths[name]
        return rel ? Qt.resolvedUrl(rel) : ""
    }

    function probeHost() {
        try {
            hostAvailable = typeof GameAudio !== "undefined" && typeof GameAudio.playEffect === "function"
        } catch (e) { hostAvailable = false }
        return hostAvailable
    }

    function preloadHost() {
        if (!probeHost()) return
        try { if (typeof GameAudio.preload !== "function") return } catch (e0) { return }
        var any = false
        for (var name in paths) {
            if (!Object.prototype.hasOwnProperty.call(paths, name)) continue
            var url = urlFor(name)
            try {
                if (url && String(url).length > 0) { GameAudio.preload(url); any = true }
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
        if (preferLocalBackend && playLocal(name)) return
        if (playHost(name)) return
        playLocal(name)
    }

    function pauseAll() {
        try { if (hostAvailable && typeof GameAudio.pauseAll === "function") GameAudio.pauseAll() } catch (e) {}
        if (localLoader.status === Loader.Ready && localLoader.item) localLoader.item.pauseAll()
    }

    Loader {
        id: localLoader
        active: bus.preferLocalBackend || !bus.hostAvailable
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
        // Do not decode every RCC WAV twice at startup. Host playback is
        // URL-based and on-demand; mobile keeps the proven local MediaPlayer path.
        localLoader.active = preferLocalBackend || !hostAvailable
    }
}
