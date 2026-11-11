import QtQuick
import QtQuick.Controls

Item {
    id: root
    anchors.fill: parent
    focus: true
    property bool lifecyclePaused: false

    property color bg: GameTheme.color("color.background")
    property color panel: GameTheme.color("color.surfaceRaised")
    property color gold: GameTheme.color("color.primary")
    property color cream: GameTheme.color("color.text")
    property color bronze: GameTheme.color("color.borderStrong")
    property color red: GameTheme.color("color.danger")
    property color green: GameTheme.color("color.success")
    property color blue: GameTheme.color("color.info")

    property int lanes: 5
    property int columns: 7
    property var towers: []
    property var enemies: []
    property var shots: []
    property int money: 220
    property int lives: 15
    property int wave: 1
    property int spawnLeft: 0
    property int spawnTick: 0
    property int waveDelay: 0
    property string towerType: "BASIC"
    property bool over: false
    property bool paused: false
    property string status: tr("status_initial", "Tap a grid cell to build")
    property int bestWave: 1
    property int cursorLane: 2
    property int cursorCol: 2

    function snd(name) { GameAudio.playEffect(Qt.resolvedUrl("sfx/" + name + ".wav")) }

    function towerCost(type) {
        if (type === "BASIC") return 55
        if (type === "CANNON") return 95
        return 80
    }

    function towerAt(lane, col) {
        for (var i = 0; i < towers.length; ++i) {
            if (towers[i].lane === lane && towers[i].col === col)
                return i
        }
        return -1
    }

    function restart() {
        towers = []
        enemies = []
        shots = []
        money = 220
        lives = 15
        wave = 1
        over = false
        paused = false
        towerType = "BASIC"
        status = "Wave 1 incoming"
        startWave()
        snd("start")
        field.requestPaint()
    }

    function startWave() {
        spawnLeft = 5 + wave * 2
        spawnTick = 18
        waveDelay = 0
        status = "Wave " + wave + " — " + spawnLeft + " enemies"
        if (wave >= 10) Achievements.unlock("wave_10")
        snd("wave")
    }

    function placeOrUpgrade(lane, col) {
        if (over || paused)
            return
        if (col < 0 || col >= columns || lane < 0 || lane >= lanes)
            return
        var existing = towerAt(lane, col)
        if (existing >= 0) {
            var tower = towers[existing]
            var upgradeCost = 45 + tower.level * 35
            if (tower.level >= 4) {
                status = "Tower already max level"
                return
            }
            if (money < upgradeCost) {
                status = "Need " + upgradeCost + " gold to upgrade"
                snd("bad")
                return
            }
            money -= upgradeCost
            tower.level++
            tower.damage += tower.type === "CANNON" ? 2 : 1
            tower.cooldownMax = Math.max(8, tower.cooldownMax - 2)
            status = "Tower upgraded to L" + tower.level
            snd("build")
            field.requestPaint()
            return
        }

        var cost = towerCost(towerType)
        if (money < cost) {
            status = "Need " + cost + " gold"
            snd("bad")
            return
        }
        money -= cost
        var damage = towerType === "CANNON" ? 3 : 1
        var cooldown = towerType === "CANNON" ? 52 : (towerType === "FROST" ? 34 : 24)
        towers.push({lane: lane, col: col, type: towerType, level: 1, damage: damage, cooldown: 0, cooldownMax: cooldown})
        Achievements.unlock("first_tower")
        status = towerType + " tower built"
        snd("build")
        field.requestPaint()
    }

    function spawnEnemy() {
        var lane = Math.floor(GameRandom.nextReal() * lanes)
        var kindRoll = GameRandom.nextReal()
        var kind = "NORMAL"
        if (wave >= 3 && kindRoll > 0.74)
            kind = "FAST"
        if (wave >= 4 && kindRoll > 0.90)
            kind = "ARMORED"
        var hp = kind === "ARMORED" ? 8 + wave * 2 : (kind === "FAST" ? 3 + wave : 5 + wave)
        enemies.push({
            x: field.width + 24,
            lane: lane,
            hp: hp,
            maxHp: hp,
            speed: kind === "FAST" ? 1.35 + wave * 0.035 : (kind === "ARMORED" ? 0.52 + wave * 0.018 : 0.78 + wave * 0.024),
            slowTicks: 0,
            kind: kind,
            alive: true
        })
    }

    function towerX(col) {
        var usable = Math.max(1, field.width - 90)
        return 34 + (col + 0.5) * usable / columns
    }

    function laneY(lane) {
        return (lane + 0.5) * field.height / lanes
    }

    function chooseTarget(tower) {
        var tx = towerX(tower.col)
        var best = null
        var bestX = 999999
        for (var i = 0; i < enemies.length; ++i) {
            var e = enemies[i]
            if (!e.alive || e.lane !== tower.lane)
                continue
            if (e.x < tx - 20)
                continue
            if (e.x < bestX) {
                best = e
                bestX = e.x
            }
        }
        return best
    }

    function fireTower(tower, target) {
        shots.push({
            x: towerX(tower.col),
            y: laneY(tower.lane),
            target: target,
            type: tower.type,
            damage: tower.damage,
            speed: tower.type === "CANNON" ? 4.2 : 6.2,
            alive: true
        })
        snd("shoot")
    }

    function enemyKilled(enemy) {
        enemy.alive = false
        money += enemy.kind === "ARMORED" ? 26 + wave : (enemy.kind === "FAST" ? 16 + wave : 20 + wave)
        snd("hit")
    }

    function tick() {
        if (field.width < 100 || field.height < 120)
            return
        if (over || paused) {
            field.requestPaint()
            return
        }

        if (spawnLeft > 0) {
            spawnTick--
            if (spawnTick <= 0) {
                spawnEnemy()
                spawnLeft--
                spawnTick = Math.max(18, 38 - wave)
            }
        }

        for (var i = 0; i < towers.length; ++i) {
            var tower = towers[i]
            if (tower.cooldown > 0)
                tower.cooldown--
            if (tower.cooldown <= 0) {
                var target = chooseTarget(tower)
                if (target) {
                    fireTower(tower, target)
                    tower.cooldown = tower.cooldownMax
                }
            }
        }

        for (var e = 0; e < enemies.length; ++e) {
            var enemy = enemies[e]
            if (!enemy.alive)
                continue
            if (enemy.slowTicks > 0)
                enemy.slowTicks--
            enemy.x -= enemy.speed * (enemy.slowTicks > 0 ? 0.55 : 1.0)
            if (enemy.x < 8) {
                enemy.alive = false
                lives--
                snd("hurt")
                status = "Base hit — " + lives + " lives left"
                if (lives <= 0) {
                    lives = 0
                    over = true
                    status = "Fortress lost"
                    snd("fail")
                }
            }
        }

        for (var s = 0; s < shots.length; ++s) {
            var shot = shots[s]
            if (!shot.alive || !shot.target || !shot.target.alive) {
                shot.alive = false
                continue
            }
            var dx = shot.target.x - shot.x
            var dy = laneY(shot.target.lane) - shot.y
            var dist = Math.max(0.001, Math.sqrt(dx * dx + dy * dy))
            shot.x += dx / dist * shot.speed
            shot.y += dy / dist * shot.speed
            if (dist <= shot.speed + 4) {
                shot.alive = false
                var damage = shot.damage
                if (shot.type === "CANNON") {
                    for (var a = 0; a < enemies.length; ++a) {
                        var splash = enemies[a]
                        if (splash.alive && splash.lane === shot.target.lane && Math.abs(splash.x - shot.target.x) < 42) {
                            splash.hp -= Math.max(1, Math.floor(damage * 0.65))
                            if (splash.hp <= 0)
                                enemyKilled(splash)
                        }
                    }
                } else {
                    shot.target.hp -= damage
                    if (shot.type === "FROST")
                        shot.target.slowTicks = Math.max(shot.target.slowTicks, 70)
                    if (shot.target.hp <= 0)
                        enemyKilled(shot.target)
                }
            }
        }

        var alive = false
        for (var n = 0; n < enemies.length; ++n) {
            if (enemies[n].alive) { alive = true; break }
        }
        if (spawnLeft === 0 && !alive) {
            waveDelay++
            if (waveDelay > 70) {
                wave++
                money += 35 + wave * 6
                startWave()
            }
        }

        if (enemies.length > 120)
            enemies = enemies.filter(function(v) { return v.alive })
        if (shots.length > 180)
            shots = shots.filter(function(v) { return v.alive })
        field.requestPaint()
    }


    // v0.6.2 public runtime integration. The classic UI/game loop stays intact.
    function tr(key, fallback) { return GameI18n.text(key, fallback) }
    function persistState() {
        GameSave.set("bestWave", bestWave)
        GameSave.set("money", money)
        GameSave.set("lives", lives)
        GameSave.set("wave", wave)
        GameSave.set("towers", towers)
        GameSave.save("autosave")
    }
    function restoreState() {
        if (GameSave.load("autosave")) {
            bestWave = GameSave.get("bestWave", bestWave)
            money = GameSave.get("money", money)
            lives = GameSave.get("lives", lives)
            wave = GameSave.get("wave", wave)
            towers = GameSave.get("towers", towers)
        }
    }


    function moveCursor(dx, dy) { cursorCol = Math.max(0, Math.min(columns - 1, cursorCol + dx)); cursorLane = Math.max(0, Math.min(lanes - 1, cursorLane + dy)); field.requestPaint() }
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_A) { moveCursor(-1,0); event.accepted=true }
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) { moveCursor(1,0); event.accepted=true }
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_W) { moveCursor(0,-1); event.accepted=true }
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_S) { moveCursor(0,1); event.accepted=true }
        else if (event.key === Qt.Key_1) { towerType="BASIC"; event.accepted=true }
        else if (event.key === Qt.Key_2) { towerType="CANNON"; event.accepted=true }
        else if (event.key === Qt.Key_3) { towerType="FROST"; event.accepted=true }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { placeOrUpgrade(cursorLane,cursorCol); event.accepted=true }
        else if (event.key === Qt.Key_Space) { if (spawnLeft<=0 && enemies.length===0) startWave(); else paused=!paused; event.accepted=true }
        else if (event.key === Qt.Key_P) { paused=!paused; event.accepted=true }
    }


    Connections {
        target: Lifecycle
        function onSaveRequested() { root.persistState() }
        function onBackgrounded() { root.lifecyclePaused = !root.paused; root.paused = true; root.persistState() }
        function onForegrounded() { if (root.lifecyclePaused) root.paused = false; root.lifecyclePaused = false }
    }
    Connections {
        target: GameInput
        function onActionPressed(action, value) { if(action==="move_left") moveCursor(-1,0); else if(action==="move_right") moveCursor(1,0); else if(action==="up") moveCursor(0,-1); else if(action==="down") moveCursor(0,1); else if(action==="fire") placeOrUpgrade(cursorLane,cursorCol); else if(action==="pause") paused=!paused; }
    }

    Component.onCompleted: {
        GameRandom.seed("tower_grid")
        GameStats.increment("sessions")
        var names = ["start", "build", "bad", "shoot", "hit", "hurt", "wave", "fail"]
        for (var i = 0; i < names.length; ++i)
            GameAudio.preload(Qt.resolvedUrl("sfx/" + names[i] + ".wav"))
        restoreState(); initTimer.start()
    }

    Component.onDestruction: persistState()

    Rectangle { anchors.fill: parent; color: bg }

    Rectangle {
        id: hud
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 64
        color: panel
        border.color: bronze
        Column {
            anchors.centerIn: parent
            spacing: 3
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                Text { text: tr("gold","GOLD") + " " + money; color: gold; font.pixelSize: 13; font.bold: true }
                Text { text: tr("lives","LIVES") + " " + lives; color: lives <= 4 ? red : cream; font.pixelSize: 12 }
                Text { text: tr("wave","WAVE") + " " + wave; color: cream; font.pixelSize: 12 }
                Text { text: tr("left","LEFT") + " " + spawnLeft; color: green; font.pixelSize: 12 }
            }
            Text { text: status; color: cream; font.pixelSize: 10; width: Math.max(0, Math.min(root.width - 20, 560)); horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
        }
    }

    Canvas {
        id: field
        anchors.top: hud.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.margins: 6

        onPaint: {
            if (width < 40 || height < 80)
                return
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = root.panel
            ctx.fillRect(0, 0, width, height)
            var laneH = height / root.lanes
            var usable = Math.max(1, width - 90)
            var colW = usable / root.columns

            ctx.strokeStyle = Qt.darker(root.bronze, 1.15)
            ctx.lineWidth = 1
            for (var l = 0; l <= root.lanes; ++l) {
                ctx.beginPath(); ctx.moveTo(0, l * laneH); ctx.lineTo(width, l * laneH); ctx.stroke()
            }
            for (var c = 0; c <= root.columns; ++c) {
                var gx = 34 + c * colW
                ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, height); ctx.stroke()
            }

            ctx.fillStyle = root.red
            ctx.fillRect(0, 0, 8, height)

            var cursorX = root.towerX(root.cursorCol), cursorY = root.laneY(root.cursorLane)
            ctx.strokeStyle = root.gold; ctx.lineWidth = 2; ctx.strokeRect(cursorX-17, cursorY-laneH*0.42, 34, laneH*0.84)

            for (var t = 0; t < root.towers.length; ++t) {
                var tower = root.towers[t]
                var tx = root.towerX(tower.col)
                var ty = root.laneY(tower.lane)
                ctx.fillStyle = tower.type === "CANNON" ? root.gold : (tower.type === "FROST" ? root.blue : root.green)
                ctx.fillRect(tx - 13, ty - 13, 26, 26)
                ctx.fillStyle = root.cream
                ctx.font = "bold 9px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText("L" + tower.level, tx, ty)
            }

            for (var e = 0; e < root.enemies.length; ++e) {
                var enemy = root.enemies[e]
                if (!enemy.alive)
                    continue
                var ey = root.laneY(enemy.lane)
                ctx.fillStyle = enemy.kind === "ARMORED" ? root.muted : (enemy.kind === "FAST" ? root.blue : root.red)
                ctx.fillRect(enemy.x - 11, ey - 11, 22, 22)
                var ratio = Math.max(0, enemy.hp / Math.max(1, enemy.maxHp))
                ctx.fillStyle = Qt.darker(root.red, 1.45)
                ctx.fillRect(enemy.x - 12, ey - 17, 24, 3)
                ctx.fillStyle = root.green
                ctx.fillRect(enemy.x - 12, ey - 17, 24 * ratio, 3)
            }

            for (var s = 0; s < root.shots.length; ++s) {
                var shot = root.shots[s]
                if (!shot.alive)
                    continue
                ctx.fillStyle = shot.type === "FROST" ? root.blue : root.gold
                ctx.beginPath(); ctx.arc(shot.x, shot.y, 3, 0, Math.PI * 2); ctx.fill()
            }

            if (root.paused || root.over) {
                ctx.fillStyle = Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.78)
                ctx.fillRect(0, 0, width, height)
                ctx.fillStyle = root.gold
                ctx.font = "bold 24px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText(root.over ? "FORTRESS LOST" : "PAUSED", width / 2, height / 2)
            }
        }

        TapHandler {
            onTapped: function(point) {
                if (root.over) { root.restart(); return }
                var lane = Math.max(0, Math.min(root.lanes - 1, Math.floor(point.position.y / Math.max(1, field.height / root.lanes))))
                var usable = Math.max(1, field.width - 90)
                var colW = usable / root.columns
                var col = Math.floor((point.position.x - 34) / Math.max(1, colW))
                root.placeOrUpgrade(lane, col)
            }
        }
    }

    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 76
        color: panel
        border.color: bronze
        Row {
            anchors.centerIn: parent
            spacing: 5
            GameButton { width: 92; text: "BASIC 55"; borderColor: root.towerType === "BASIC" ? root.gold : root.bronze; onClicked: root.towerType = "BASIC" }
            GameButton { width: 104; text: "CANNON 95"; borderColor: root.towerType === "CANNON" ? root.gold : root.bronze; onClicked: root.towerType = "CANNON" }
            GameButton { width: 92; text: "FROST 80"; borderColor: root.towerType === "FROST" ? root.gold : root.bronze; onClicked: root.towerType = "FROST" }
            GameButton { width: 78; text: root.paused ? tr("play","PLAY") : tr("pause","PAUSE"); onClicked: root.paused = !root.paused }
        }
    }

    Timer { interval: 16; repeat: true; running: true; onTriggered: root.tick() }
    Timer { id: initTimer; interval: 1; repeat: false; onTriggered: root.restart() }
}
