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
        "start":"../sfx/start.wav","step":"../sfx/step.wav","wall":"../sfx/wall.wav","swing":"../sfx/swing.wav",
        "hit":"../sfx/hit.wav","hurt":"../sfx/hurt.wav","enemy_die":"../sfx/enemy_die.wav","coin":"../sfx/coin.wav",
        "potion":"../sfx/potion.wav","chest":"../sfx/chest.wav","key":"../sfx/key.wav","shrine":"../sfx/shrine.wav",
        "trap":"../sfx/trap.wav","stairs":"../sfx/stairs.wav","level":"../sfx/level.wav","bomb":"../sfx/bomb.wav",
        "boss_roar":"../sfx/boss_roar.wav","boss_die":"../sfx/boss_die.wav","shop":"../sfx/shop.wav","buy":"../sfx/buy.wav",
        "upgrade":"../sfx/upgrade.wav","relic":"../sfx/relic.wav","shard":"../sfx/shard.wav","skill_guard":"../sfx/skill_guard.wav",
        "skill_rogue":"../sfx/skill_rogue.wav","skill_arcane":"../sfx/skill_arcane.wav","fail":"../sfx/fail.wav","button":"../sfx/button.wav"
    })

    function playerAt(i) {
        if (i === 0) return player0
        if (i === 1) return player1
        if (i === 2) return player2
        if (i === 3) return player3
        if (i === 4) return player4
        return player5
    }

    function play(name) {
        if (!enabled) return
        var rel = paths[name]
        if (!rel) return
        var p = playerAt(cursor % 6)
        cursor = (cursor + 1) % 6
        try {
            p.stop()
            p.source = Qt.resolvedUrl(rel)
            p.play()
        } catch (e) {}
    }

    function pauseAll() {
        try { player0.pause(); player1.pause(); player2.pause(); player3.pause(); player4.pause(); player5.pause() } catch (e) {}
    }

    MediaPlayer { id: player0; audioOutput: AudioOutput { volume: root.volume } }
    MediaPlayer { id: player1; audioOutput: AudioOutput { volume: root.volume } }
    MediaPlayer { id: player2; audioOutput: AudioOutput { volume: root.volume } }
    MediaPlayer { id: player3; audioOutput: AudioOutput { volume: root.volume } }
    MediaPlayer { id: player4; audioOutput: AudioOutput { volume: root.volume } }
    MediaPlayer { id: player5; audioOutput: AudioOutput { volume: root.volume } }
}
