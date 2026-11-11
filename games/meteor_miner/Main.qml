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
    property color muted: GameTheme.color("color.textMuted")

    property var rocks: []
    property var shots: []
    property var oreDrops: []
    property var sparks: []
    property real shipX: 0
    property int hull: 6
    property int maxHull: 6
    property int laser: 1
    property int ore: 0
    property int score: 0
    property int sector: 1
    property int mined: 0
    property int sectorGoal: 14
    property int spawnTick: 0
    property int fireTick: 0
    property bool over: false
    property bool paused: false
    property string status: tr("status_initial", "Mine asteroids and collect ore")
    property int bestScore: 0

    function snd(name) { GameAudio.playEffect(Qt.resolvedUrl("sfx/" + name + ".wav")) }
    function clamp(v, a, b) { return Math.max(a, Math.min(b, v)) }

    function restart() {
        rocks = []
        shots = []
        oreDrops = []
        sparks = []
        hull = 6
        maxHull = 6
        laser = 1
        ore = 0
        score = 0
        sector = 1
        mined = 0
        sectorGoal = 14
        spawnTick = 10
        fireTick = 0
        over = false
        paused = false
        status = "Sector 1 — mine " + sectorGoal + " asteroids"
        shipX = field.width / 2
        snd("start")
        field.requestPaint()
    }

    function spawnRock() {
        var sizeRoll = GameRandom.nextReal()
        var size = sizeRoll > 0.82 ? 28 : (sizeRoll > 0.42 ? 21 : 15)
        var hp = Math.max(1, Math.floor(size / 8) + Math.floor(sector / 4))
        rocks.push({
            x: 20 + GameRandom.nextReal() * Math.max(1, field.width - 40),
            y: -size,
            size: size,
            hp: hp,
            maxHp: hp,
            speed: 0.65 + sector * 0.035 + GameRandom.nextReal() * 0.4,
            drift: (GameRandom.nextReal() - 0.5) * 0.42,
            spin: GameRandom.nextReal() * Math.PI * 2,
            ore: 1 + Math.floor(size / 11),
            alive: true
        })
    }

    function fire() {
        if (fireTick > 0 || over)
            return
        var speed = 7.5
        shots.push({x: shipX, y: field.height - 60, vx: 0, vy: -speed, damage: 1, alive: true})
        if (laser >= 2) {
            shots.push({x: shipX - 8, y: field.height - 54, vx: -0.22, vy: -speed, damage: 1, alive: true})
            shots.push({x: shipX + 8, y: field.height - 54, vx: 0.22, vy: -speed, damage: 1, alive: true})
        }
        if (laser >= 4)
            shots.push({x: shipX, y: field.height - 67, vx: 0, vy: -speed * 1.08, damage: 2, alive: true})
        fireTick = Math.max(5, 14 - laser)
        snd("shoot")
    }

    function explodeRock(rock) {
        rock.alive = false
        mined++
        score += 35 + rock.ore * 18
        snd("mine")
        for (var i = 0; i < rock.ore; ++i) {
            oreDrops.push({
                x: rock.x + (GameRandom.nextReal() - 0.5) * rock.size,
                y: rock.y,
                vx: (GameRandom.nextReal() - 0.5) * 0.8,
                vy: 0.8 + GameRandom.nextReal() * 0.5,
                alive: true
            })
        }
        for (var s = 0; s < 6; ++s) {
            sparks.push({x: rock.x, y: rock.y, vx: (GameRandom.nextReal() - 0.5) * 3, vy: (GameRandom.nextReal() - 0.5) * 3, life: 20})
        }
    }

    function damageShip() {
        hull--
        snd("hurt")
        if (hull <= 0) {
            hull = 0
            over = true
            status = "Miner destroyed — tap NEW RUN"
            snd("fail")
        }
    }

    function buyLaser() {
        var cost = 12 + laser * 10
        if (laser >= 5) {
            status = "Laser already maxed"
            return
        }
        if (ore < cost) {
            status = "Need " + cost + " ore"
            return
        }
        ore -= cost
        laser++
        if (laser >= 5) Achievements.unlock("max_laser")
        status = "Laser upgraded to P" + laser
        snd("level")
    }

    function repair() {
        var cost = 7
        if (hull >= maxHull) {
            status = "Hull already full"
            return
        }
        if (ore < cost) {
            status = "Need " + cost + " ore"
            return
        }
        ore -= cost
        hull = Math.min(maxHull, hull + 2)
        status = "Hull repaired"
        snd("level")
    }

    function nextSector() {
        sector++
        if (sector >= 5) Achievements.unlock("sector_5")
        mined = 0
        sectorGoal = 12 + sector * 3
        bestScore = Math.max(bestScore, score); GameStats.submitHighScore(bestScore); persistState(); status = "Sector " + sector + " — target " + sectorGoal
        snd("level")
    }

    function tick() {
        if (field.width < 80 || field.height < 150)
            return
        if (paused || over) {
            field.requestPaint()
            return
        }
        shipX = clamp(shipX, 24, field.width - 24)
        if (fireTick > 0)
            fireTick--
        fire()
        spawnTick--
        if (spawnTick <= 0) {
            spawnRock()
            spawnTick = Math.max(18, 50 - sector * 2)
        }

        for (var i = 0; i < rocks.length; ++i) {
            var rock = rocks[i]
            if (!rock.alive)
                continue
            rock.x += rock.drift
            rock.y += rock.speed
            rock.spin += 0.025
            rock.x = clamp(rock.x, rock.size / 2, field.width - rock.size / 2)
            if (rock.y > field.height - 45) {
                rock.alive = false
                damageShip()
            }
        }

        for (var s = 0; s < shots.length; ++s) {
            var shot = shots[s]
            if (!shot.alive)
                continue
            shot.x += shot.vx
            shot.y += shot.vy
            if (shot.y < -12) {
                shot.alive = false
                continue
            }
            for (var r = 0; r < rocks.length; ++r) {
                var target = rocks[r]
                if (!target.alive)
                    continue
                var rr = Math.max(6, target.size * 0.48)
                var dx = shot.x - target.x
                var dy = shot.y - target.y
                if (dx * dx + dy * dy <= rr * rr) {
                    shot.alive = false
                    target.hp -= shot.damage
                    snd("hit")
                    if (target.hp <= 0)
                        explodeRock(target)
                    break
                }
            }
        }

        for (var o = 0; o < oreDrops.length; ++o) {
            var drop = oreDrops[o]
            if (!drop.alive)
                continue
            drop.x += drop.vx
            drop.y += drop.vy
            if (drop.y > field.height + 12) {
                drop.alive = false
                continue
            }
            if (Math.abs(drop.x - shipX) < 24 && Math.abs(drop.y - (field.height - 34)) < 24) {
                drop.alive = false
                ore++
                score += 10
            }
        }

        for (var sp = 0; sp < sparks.length; ++sp) {
            sparks[sp].x += sparks[sp].vx
            sparks[sp].y += sparks[sp].vy
            sparks[sp].life--
        }

        if (mined >= sectorGoal)
            nextSector()

        if (rocks.length > 100)
            rocks = rocks.filter(function(v) { return v.alive })
        if (shots.length > 160)
            shots = shots.filter(function(v) { return v.alive })
        if (oreDrops.length > 120)
            oreDrops = oreDrops.filter(function(v) { return v.alive })
        if (sparks.length > 120)
            sparks = sparks.filter(function(v) { return v.life > 0 })

        field.requestPaint()
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_A) { shipX -= 28; event.accepted = true }
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) { shipX += 28; event.accepted = true }
        else if (event.key === Qt.Key_P) { paused = !paused; event.accepted = true }
    }


    // v0.6.2 public runtime integration. The classic UI/game loop stays intact.
    function tr(key, fallback) { return GameI18n.text(key, fallback) }
    function persistState() {
        GameSave.set("sector", sector)
        GameSave.set("laser", laser)
        GameSave.set("maxHull", maxHull)
        GameSave.save("autosave")
    }
    function restoreState() {
        if (GameSave.load("autosave")) {
            sector = GameSave.get("sector", sector)
            laser = GameSave.get("laser", laser)
            maxHull = GameSave.get("maxHull", maxHull)
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
        function onActionPressed(action, value) { if(action==="move_left") shipX-=28; else if(action==="move_right") shipX+=28; else if(action==="pause") paused=!paused; }
    }

    Component.onCompleted: {
        GameRandom.seed("meteor_miner")
        GameStats.increment("sessions")
        var names = ["start", "shoot", "hit", "mine", "hurt", "level", "fail"]
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
                spacing: 14
                Text { text: tr("hull","HULL") + " " + hull + "/" + maxHull; color: hull <= 2 ? red : cream; font.pixelSize: 12; font.bold: true }
                Text { text: tr("ore","ORE") + " " + ore; color: gold; font.pixelSize: 12; font.bold: true }
                Text { text: "LASER P" + laser; color: blue; font.pixelSize: 12 }
                Text { text: tr("sector","SECTOR") + " " + sector; color: cream; font.pixelSize: 12 }
                Text { text: tr("score","SCORE") + " " + score; color: gold; font.pixelSize: 12 }
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

        onPaint: {
            if (width < 40 || height < 100)
                return
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = root.bg
            ctx.fillRect(0, 0, width, height)

            for (var i = 0; i < root.rocks.length; ++i) {
                var rock = root.rocks[i]
                if (!rock.alive)
                    continue
                var radius = Math.max(4, rock.size * 0.5)
                ctx.save()
                ctx.translate(rock.x, rock.y)
                ctx.rotate(rock.spin)
                ctx.fillStyle = root.muted
                ctx.beginPath()
                ctx.moveTo(radius, 0)
                for (var p = 1; p < 8; ++p) {
                    var angle = p / 8 * Math.PI * 2
                    var wobble = radius * (0.78 + ((p * 7) % 3) * 0.09)
                    ctx.lineTo(Math.cos(angle) * wobble, Math.sin(angle) * wobble)
                }
                ctx.closePath()
                ctx.fill()
                ctx.strokeStyle = root.bronze
                ctx.stroke()
                ctx.restore()
                if (rock.hp < rock.maxHp) {
                    ctx.fillStyle = Qt.darker(root.red, 1.45)
                    ctx.fillRect(rock.x - radius, rock.y - radius - 6, radius * 2, 3)
                    ctx.fillStyle = root.green
                    ctx.fillRect(rock.x - radius, rock.y - radius - 6, radius * 2 * Math.max(0, rock.hp / rock.maxHp), 3)
                }
            }

            ctx.fillStyle = root.gold
            for (var s = 0; s < root.shots.length; ++s) {
                var shot = root.shots[s]
                if (shot.alive)
                    ctx.fillRect(shot.x - 2, shot.y - 8, 4, 14)
            }

            ctx.fillStyle = root.green
            for (var o = 0; o < root.oreDrops.length; ++o) {
                var drop = root.oreDrops[o]
                if (!drop.alive)
                    continue
                ctx.beginPath(); ctx.arc(drop.x, drop.y, 4, 0, Math.PI * 2); ctx.fill()
            }

            for (var sp = 0; sp < root.sparks.length; ++sp) {
                var spark = root.sparks[sp]
                if (spark.life <= 0)
                    continue
                ctx.globalAlpha = Math.max(0, spark.life / 20)
                ctx.fillStyle = root.gold
                ctx.fillRect(spark.x, spark.y, 2, 2)
            }
            ctx.globalAlpha = 1

            ctx.save()
            ctx.translate(root.shipX, height - 34)
            ctx.fillStyle = root.gold
            ctx.beginPath()
            ctx.moveTo(0, -18)
            ctx.lineTo(-18, 15)
            ctx.lineTo(0, 9)
            ctx.lineTo(18, 15)
            ctx.closePath()
            ctx.fill()
            ctx.fillStyle = root.blue
            ctx.fillRect(-4, -4, 8, 12)
            ctx.restore()

            ctx.fillStyle = root.muted
            ctx.font = "11px sans-serif"
            ctx.fillText("Mined " + root.mined + " / " + root.sectorGoal, 10, 20)

            if (root.paused || root.over) {
                ctx.fillStyle = "rgba(5,5,7,0.76)"
                ctx.fillRect(0, 0, width, height)
                ctx.fillStyle = root.gold
                ctx.font = "bold 24px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText(root.over ? "MINER LOST" : "PAUSED", width / 2, height / 2)
            }
        }

        MouseArea {
            anchors.fill: parent
            onPressed: function(mouse) {
                if (root.over) { root.restart(); return }
                root.shipX = root.clamp(mouse.x, 24, field.width - 24)
            }
            onPositionChanged: function(mouse) {
                if (pressed && !root.over)
                    root.shipX = root.clamp(mouse.x, 24, field.width - 24)
            }
        }
    }

    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 62
        color: panel
        border.color: bronze
        Row {
            anchors.centerIn: parent
            spacing: 7
            GameButton { width: 110; text: tr("laser","LASER") + " " + (12 + laser * 10); enabled: laser < 5; onClicked: root.buyLaser() }
            GameButton { width: 92; text: "REPAIR 7"; enabled: hull < maxHull; onClicked: root.repair() }
            GameButton { width: 88; text: root.paused ? "RESUME" : "PAUSE"; onClicked: root.paused = !root.paused }
        }
    }

    Timer { interval: 16; repeat: true; running: true; onTriggered: root.tick() }
    Timer { id: initTimer; interval: 1; repeat: false; onTriggered: root.restart() }
}
