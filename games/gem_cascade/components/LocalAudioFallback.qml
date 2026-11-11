import QtQuick
import QtMultimedia

Item {
    id: root
    visible: false
    width: 0
    height: 0
    property real volume: 0.72
    property int cursor: 0

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

    function playerAt(i) {
        if (i === 0) return player0
        if (i === 1) return player1
        if (i === 2) return player2
        return player3
    }

    function play(name) {
        if (!enabled) return
        var rel = paths[name]
        if (!rel) return
        var p = playerAt(cursor % 4)
        cursor = (cursor + 1) % 4
        try {
            p.stop()
            p.source = Qt.resolvedUrl(rel)
            p.play()
        } catch (e) {}
    }

    function pauseAll() {
        try { player0.pause(); player1.pause(); player2.pause(); player3.pause() } catch (e) {}
    }
    function resumeAll() {}

    MediaPlayer { id: player0; audioOutput: AudioOutput { volume: root.volume } }
    MediaPlayer { id: player1; audioOutput: AudioOutput { volume: root.volume } }
    MediaPlayer { id: player2; audioOutput: AudioOutput { volume: root.volume } }
    MediaPlayer { id: player3; audioOutput: AudioOutput { volume: root.volume } }
}
