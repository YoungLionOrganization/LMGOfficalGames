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

    property var enemies: []
    property var shots: []
    property var enemyShots: []
    property var pickups: []
    property var stars: []
    property real shipX: 0
    property real shipY: 0
    property int hp: 6
    property int maxHp: 6
    property int shield: 0
    property int weapon: 1
    property int score: 0
    property int best: 0
    property int wave: 1
    property int killsInWave: 0
    property int waveTarget: 10
    property int spawnCooldown: 0
    property int fireCooldown: 0
    property int invulnerableTicks: 0
    property bool bossAlive: false
    property bool gameOver: false
    property bool paused: false
    property string status: tr("status_initial", "Wave 1")

    function snd(name) { GameAudio.playEffect(Qt.resolvedUrl("sfx/" + name + ".wav")) }
    function clamp(v, a, b) { return Math.max(a, Math.min(b, v)) }

    function resetStars() {
        stars = []
        for (var i = 0; i < 36; ++i)
            stars.push({x: GameRandom.nextReal(), y: GameRandom.nextReal(), s: 0.4 + GameRandom.nextReal() * 1.2})
    }

    function restart() {
        enemies = []
        shots = []
        enemyShots = []
        pickups = []
        hp = 6
        maxHp = 6
        shield = 0
        weapon = 1
        score = 0
        wave = 1
        killsInWave = 0
        waveTarget = 10
        spawnCooldown = 20
        fireCooldown = 0
        invulnerableTicks = 0
        bossAlive = false
        gameOver = false
        paused = false
        status = "Wave 1"
        shipX = field.width / 2
        shipY = Math.max(80, field.height - 58)
        resetStars()
        snd("start")
        field.requestPaint()
    }

    function spawnEnemy() {
        if (bossAlive || gameOver)
            return
        var kindRoll = GameRandom.nextReal()
        var kind = "scout"
        if (wave >= 3 && kindRoll > 0.72)
            kind = "zig"
        if (wave >= 4 && kindRoll > 0.88)
            kind = "tank"
        var hpValue = kind === "tank" ? 5 + Math.floor(wave / 2) : (kind === "zig" ? 2 + Math.floor(wave / 4) : 1 + Math.floor(wave / 5))
        enemies.push({
            x: 24 + GameRandom.nextReal() * Math.max(1, field.width - 48),
            y: -28,
            vx: kind === "zig" ? (GameRandom.nextReal() < 0.5 ? -1 : 1) * (1.1 + wave * 0.03) : 0,
            vy: kind === "tank" ? 0.52 + wave * 0.018 : 0.82 + wave * 0.025,
            hp: hpValue,
            maxHp: hpValue,
            kind: kind,
            phase: GameRandom.nextReal() * Math.PI * 2,
            shoot: 60 + Math.floor(GameRandom.nextReal() * 90),
            alive: true,
            boss: false
        })
    }

    function spawnBoss() {
        bossAlive = true
        var bossHp = 42 + wave * 6
        enemies.push({
            x: field.width / 2,
            y: 54,
            vx: 1.15 + wave * 0.025,
            vy: 0,
            hp: bossHp,
            maxHp: bossHp,
            kind: "boss",
            phase: 0,
            shoot: 40,
            alive: true,
            boss: true
        })
        status = "BOSS WAVE " + wave
        snd("boss")
    }

    function firePlayer() {
        if (fireCooldown > 0 || gameOver)
            return
        var speed = 7.2
        shots.push({x: shipX, y: shipY - 22, vx: 0, vy: -speed, damage: 1, alive: true})
        if (weapon >= 2) {
            shots.push({x: shipX - 9, y: shipY - 15, vx: -0.45, vy: -speed, damage: 1, alive: true})
            shots.push({x: shipX + 9, y: shipY - 15, vx: 0.45, vy: -speed, damage: 1, alive: true})
        }
        if (weapon >= 4) {
            shots.push({x: shipX - 15, y: shipY - 8, vx: -0.95, vy: -speed * 0.94, damage: 1, alive: true})
            shots.push({x: shipX + 15, y: shipY - 8, vx: 0.95, vy: -speed * 0.94, damage: 1, alive: true})
        }
        fireCooldown = Math.max(6, 14 - weapon)
        snd("shoot")
    }

    function fireEnemy(enemy) {
        var dx = shipX - enemy.x
        var dy = shipY - enemy.y
        var len = Math.max(1, Math.sqrt(dx * dx + dy * dy))
        var speed = enemy.boss ? 2.7 : 2.1
        enemyShots.push({x: enemy.x, y: enemy.y + 10, vx: dx / len * speed, vy: dy / len * speed, alive: true})
        if (enemy.boss) {
            enemyShots.push({x: enemy.x, y: enemy.y + 10, vx: -1.3, vy: 2.2, alive: true})
            enemyShots.push({x: enemy.x, y: enemy.y + 10, vx: 1.3, vy: 2.2, alive: true})
        }
    }

    function hitPlayer() {
        if (invulnerableTicks > 0 || gameOver)
            return
        invulnerableTicks = 55
        if (shield > 0) {
            shield--
            snd("shield")
            return
        }
        hp--
        snd("hurt")
        if (hp <= 0) {
            hp = 0
            gameOver = true
            best = Math.max(best, score); GameStats.submitHighScore(best)
            GameSave.set("best", best); GameSave.save("autosave")
            status = "Ship lost — tap to restart"
            snd("fail")
        }
    }

    function destroyEnemy(enemy) {
        enemy.alive = false
        var reward = enemy.boss ? 900 : (enemy.kind === "tank" ? 80 : (enemy.kind === "zig" ? 45 : 25))
        score += reward
        if (enemy.boss) {
            Achievements.unlock("boss_breaker")
            bossAlive = false
            killsInWave = waveTarget
        } else {
            killsInWave++
        }
        snd("boom")
        if (GameRandom.nextReal() < (enemy.boss ? 1.0 : 0.12)) {
            var types = ["SHIELD", "WEAPON", "HEAL"]
            pickups.push({x: enemy.x, y: enemy.y, type: types[Math.floor(GameRandom.nextReal() * types.length)], alive: true})
        }
    }

    function nextWave() {
        wave++
        if (wave >= 10) Achievements.unlock("wave_10")
        killsInWave = 0
        waveTarget = 8 + wave * 2
        spawnCooldown = 45
        if (wave % 5 === 0)
            spawnBoss()
        else {
            status = "Wave " + wave
            snd("power")
        }
    }

    function updateStars() {
        for (var i = 0; i < stars.length; ++i) {
            stars[i].y += stars[i].s / Math.max(120, field.height)
            if (stars[i].y > 1) {
                stars[i].y = 0
                stars[i].x = GameRandom.nextReal()
            }
        }
    }

    function tick() {
        if (field.width < 80 || field.height < 160)
            return
        updateStars()
        if (paused || gameOver) {
            field.requestPaint()
            return
        }

        shipX = clamp(shipX, 20, field.width - 20)
        shipY = clamp(shipY, field.height * 0.45, field.height - 28)
        if (invulnerableTicks > 0)
            invulnerableTicks--
        if (fireCooldown > 0)
            fireCooldown--
        firePlayer()

        if (!bossAlive) {
            spawnCooldown--
            if (spawnCooldown <= 0 && killsInWave < waveTarget) {
                spawnEnemy()
                spawnCooldown = Math.max(16, 46 - wave * 2)
            }
        }

        for (var i = 0; i < enemies.length; ++i) {
            var e = enemies[i]
            if (!e.alive)
                continue
            if (e.boss) {
                e.x += e.vx
                if (e.x < 55 || e.x > field.width - 55)
                    e.vx = -e.vx
            } else {
                e.phase += 0.04
                e.x += e.vx + (e.kind === "zig" ? Math.sin(e.phase) * 0.8 : 0)
                e.x = clamp(e.x, 18, field.width - 18)
                e.y += e.vy
            }
            e.shoot--
            if (e.shoot <= 0 && e.y < field.height * 0.72) {
                fireEnemy(e)
                e.shoot = e.boss ? 34 : (80 + Math.floor(GameRandom.nextReal() * 70))
            }
            if (!e.boss && e.y > field.height + 24) {
                e.alive = false
                hitPlayer()
            }
            if (Math.abs(e.x - shipX) < (e.boss ? 42 : 20) && Math.abs(e.y - shipY) < (e.boss ? 35 : 20)) {
                if (!e.boss)
                    e.alive = false
                hitPlayer()
            }
        }

        for (var s = 0; s < shots.length; ++s) {
            var shot = shots[s]
            if (!shot.alive)
                continue
            shot.x += shot.vx
            shot.y += shot.vy
            if (shot.y < -20 || shot.x < -20 || shot.x > field.width + 20) {
                shot.alive = false
                continue
            }
            for (var j = 0; j < enemies.length; ++j) {
                var target = enemies[j]
                if (!target.alive)
                    continue
                var rx = target.boss ? 48 : 17
                var ry = target.boss ? 28 : 17
                if (Math.abs(shot.x - target.x) <= rx && Math.abs(shot.y - target.y) <= ry) {
                    shot.alive = false
                    target.hp -= shot.damage
                    snd("hit")
                    if (target.hp <= 0)
                        destroyEnemy(target)
                    break
                }
            }
        }

        for (var es = 0; es < enemyShots.length; ++es) {
            var enemyShot = enemyShots[es]
            if (!enemyShot.alive)
                continue
            enemyShot.x += enemyShot.vx
            enemyShot.y += enemyShot.vy
            if (enemyShot.y > field.height + 16 || enemyShot.x < -16 || enemyShot.x > field.width + 16) {
                enemyShot.alive = false
                continue
            }
            if (Math.abs(enemyShot.x - shipX) < 13 && Math.abs(enemyShot.y - shipY) < 16) {
                enemyShot.alive = false
                hitPlayer()
            }
        }

        for (var p = 0; p < pickups.length; ++p) {
            var pick = pickups[p]
            if (!pick.alive)
                continue
            pick.y += 1.35
            if (pick.y > field.height + 12) {
                pick.alive = false
                continue
            }
            if (Math.abs(pick.x - shipX) < 22 && Math.abs(pick.y - shipY) < 22) {
                pick.alive = false
                if (pick.type === "SHIELD")
                    shield = Math.min(4, shield + 2)
                else if (pick.type === "WEAPON")
                    weapon = Math.min(5, weapon + 1)
                else
                    hp = Math.min(maxHp, hp + 2)
                score += 100
                snd("power")
            }
        }

        if (!bossAlive && killsInWave >= waveTarget) {
            var alive = false
            for (var a = 0; a < enemies.length; ++a) {
                if (enemies[a].alive) { alive = true; break }
            }
            if (!alive)
                nextWave()
        }

        if (shots.length > 180)
            shots = shots.filter(function(v) { return v.alive })
        if (enemyShots.length > 220)
            enemyShots = enemyShots.filter(function(v) { return v.alive })
        if (enemies.length > 100)
            enemies = enemies.filter(function(v) { return v.alive })
        if (pickups.length > 50)
            pickups = pickups.filter(function(v) { return v.alive })

        field.requestPaint()
    }

    Keys.onPressed: function(event) {
        var step = 26
        if (event.key === Qt.Key_Left || event.key === Qt.Key_A) { shipX -= step; event.accepted = true }
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) { shipX += step; event.accepted = true }
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_W) { shipY -= step; event.accepted = true }
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_S) { shipY += step; event.accepted = true }
        else if (event.key === Qt.Key_P) { paused = !paused; event.accepted = true }
    }


    // v0.6.2 public runtime integration. The classic UI/game loop stays intact.
    function tr(key, fallback) { return GameI18n.text(key, fallback) }
    function persistState() {
        GameSave.set("best", best)
        GameSave.save("autosave")
    }
    function restoreState() {
        if (GameSave.load("autosave")) {
            best = GameSave.get("best", best)
        }
    }


    Connections {
        target: Lifecycle
        function onSaveRequested() { root.persistState() }
        function onBackgrounded() { root.lifecyclePaused = !root.paused; root.paused = true; root.persistState() }
        function onForegrounded() { if (root.lifecyclePaused) root.paused = false; root.lifecyclePaused = false }
    }
    Connections {
        target: GameInput
        function onActionPressed(action, value) { if(action==="move_left") shipX-=26; else if(action==="move_right") shipX+=26; else if(action==="up") shipY-=26; else if(action==="down") shipY+=26; else if(action==="pause") paused=!paused; }
    }

    Component.onCompleted: {
        GameRandom.seed("star_defender")
        GameStats.increment("sessions")
        restoreState(); best = Number(GameSave.get("best", best))
        var names = ["start", "shoot", "hit", "boom", "hurt", "power", "shield", "boss", "fail"]
        for (var i = 0; i < names.length; ++i)
            GameAudio.preload(Qt.resolvedUrl("sfx/" + names[i] + ".wav"))
        initTimer.start()
    }

    Component.onDestruction: persistState()

    Rectangle { anchors.fill: parent; color: bg }

    Rectangle {
        id: hud
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 58
        color: panel
        border.color: bronze
        Row {
            anchors.centerIn: parent
            spacing: 12
            Text { text: "HP " + hp + "/" + maxHp; color: hp <= 2 ? red : cream; font.pixelSize: 12; font.bold: true }
            Text { text: "SH " + shield; color: shield > 0 ? blue : cream; font.pixelSize: 12 }
            Text { text: "P" + weapon; color: gold; font.pixelSize: 12; font.bold: true }
            Text { text: tr("wave","WAVE") + " " + wave; color: cream; font.pixelSize: 12 }
            Text { text: tr("score","SCORE") + " " + score; color: gold; font.pixelSize: 12 }
            Text { text: tr("best","BEST") + " " + best; color: cream; font.pixelSize: 11 }
        }
    }

    Canvas {
        id: field
        anchors.top: hud.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top

        onPaint: {
            if (width < 40 || height < 100)
                return
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = root.bg
            ctx.fillRect(0, 0, width, height)

            ctx.fillStyle = "rgba(243,220,176,0.55)"
            for (var st = 0; st < root.stars.length; ++st) {
                var star = root.stars[st]
                ctx.fillRect(star.x * width, star.y * height, Math.max(1, star.s), Math.max(1, star.s))
            }

            for (var i = 0; i < root.enemies.length; ++i) {
                var e = root.enemies[i]
                if (!e.alive)
                    continue
                if (e.boss) {
                    ctx.fillStyle = root.red
                    ctx.fillRect(e.x - 46, e.y - 20, 92, 40)
                    ctx.fillStyle = root.gold
                    ctx.fillRect(e.x - 18, e.y - 28, 36, 12)
                    var ratio = Math.max(0, e.hp / Math.max(1, e.maxHp))
                    ctx.fillStyle = Qt.darker(root.red, 1.45)
                    ctx.fillRect(e.x - 46, e.y - 34, 92, 5)
                    ctx.fillStyle = root.green
                    ctx.fillRect(e.x - 46, e.y - 34, 92 * ratio, 5)
                } else {
                    ctx.fillStyle = e.kind === "tank" ? root.gold : (e.kind === "zig" ? root.blue : root.red)
                    ctx.beginPath()
                    ctx.moveTo(e.x, e.y + 14)
                    ctx.lineTo(e.x - 14, e.y - 10)
                    ctx.lineTo(e.x + 14, e.y - 10)
                    ctx.closePath()
                    ctx.fill()
                }
            }

            ctx.fillStyle = root.gold
            for (var s = 0; s < root.shots.length; ++s) {
                var shot = root.shots[s]
                if (shot.alive)
                    ctx.fillRect(shot.x - 2, shot.y - 7, 4, 12)
            }

            ctx.fillStyle = root.red
            for (var es = 0; es < root.enemyShots.length; ++es) {
                var enemyShot = root.enemyShots[es]
                if (!enemyShot.alive)
                    continue
                ctx.beginPath()
                ctx.arc(enemyShot.x, enemyShot.y, 3, 0, Math.PI * 2)
                ctx.fill()
            }

            for (var p = 0; p < root.pickups.length; ++p) {
                var pick = root.pickups[p]
                if (!pick.alive)
                    continue
                ctx.fillStyle = pick.type === "SHIELD" ? root.blue : (pick.type === "WEAPON" ? root.gold : root.green)
                ctx.beginPath()
                ctx.arc(pick.x, pick.y, 8, 0, Math.PI * 2)
                ctx.fill()
            }

            if (root.invulnerableTicks % 8 < 4 || root.invulnerableTicks === 0) {
                ctx.save()
                ctx.translate(root.shipX, root.shipY)
                ctx.fillStyle = root.gold
                ctx.beginPath()
                ctx.moveTo(0, -20)
                ctx.lineTo(-16, 16)
                ctx.lineTo(0, 10)
                ctx.lineTo(16, 16)
                ctx.closePath()
                ctx.fill()
                ctx.fillStyle = root.cream
                ctx.fillRect(-3, -4, 6, 14)
                if (root.shield > 0) {
                    ctx.strokeStyle = root.blue
                    ctx.lineWidth = 2
                    ctx.beginPath()
                    ctx.arc(0, 0, 24, 0, Math.PI * 2)
                    ctx.stroke()
                }
                ctx.restore()
            }

            ctx.fillStyle = root.gold
            ctx.font = "bold 12px sans-serif"
            ctx.textAlign = "left"
            ctx.fillText(root.status, 10, 20)

            if (root.paused || root.gameOver) {
                ctx.fillStyle = "rgba(5,5,8,0.78)"
                ctx.fillRect(0, 0, width, height)
                ctx.fillStyle = root.gold
                ctx.font = "bold 24px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText(root.gameOver ? "SHIP LOST" : "PAUSED", width / 2, height / 2 - 12)
                ctx.fillStyle = root.cream
                ctx.font = "13px sans-serif"
                ctx.fillText(root.gameOver ? "Tap to launch a new run" : "Press PAUSE to continue", width / 2, height / 2 + 20)
            }
        }

        MouseArea {
            anchors.fill: parent
            onPressed: function(mouse) {
                if (root.gameOver) {
                    root.restart()
                    return
                }
                root.shipX = root.clamp(mouse.x, 20, field.width - 20)
                root.shipY = root.clamp(mouse.y, field.height * 0.45, field.height - 28)
            }
            onPositionChanged: function(mouse) {
                if (pressed && !root.gameOver) {
                    root.shipX = root.clamp(mouse.x, 20, field.width - 20)
                    root.shipY = root.clamp(mouse.y, field.height * 0.45, field.height - 28)
                }
            }
        }
    }

    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 58
        color: panel
        border.color: bronze
        Row {
            anchors.centerIn: parent
            spacing: 8
            GameButton { width: 110; text: root.paused ? "RESUME" : "PAUSE"; onClicked: root.paused = !root.paused }
            GameButton { width: 110; text: tr("new_run","NEW RUN"); onClicked: root.restart() }
        }
    }

    Timer { interval: 16; repeat: true; running: true; onTriggered: root.tick() }
    Timer { id: initTimer; interval: 1; repeat: false; onTriggered: root.restart() }
}
