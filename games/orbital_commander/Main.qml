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

    property var threats: []
    property var missiles: []
    property var pulses: []
    property int planetHp: 12
    property int maxPlanetHp: 12
    property real energy: 100
    property int score: 0
    property int wave: 1
    property int waveKills: 0
    property int waveTarget: 8
    property int spawnTick: 0
    property int missileCooldown: 0
    property int empCooldown: 0
    property bool over: false
    property bool paused: false
    property string status: tr("status_initial", "Tap a threat to launch a defense missile")
    property int credits: 0
    property int commandPoints: 0
    property int bestScore: 0
    property int bestWave: 1
    property int shield: 8
    property int maxShield: 8
    property int missileLevel: 1
    property int shieldLevel: 1
    property int droneLevel: 0
    property int autoTick: 0
    property int spawnedBossWave: 0

    function snd(name) { GameAudio.playEffect(Qt.resolvedUrl("sfx/" + name + ".wav")) }
    function centerX() { return field.width / 2 }
    function centerY() { return field.height / 2 }

    function restart() {
        threats = []
        missiles = []
        pulses = []
        planetHp = 12
        maxPlanetHp = 12
        energy = 100
        score = 0
        wave = 1
        waveKills = 0
        waveTarget = 8
        spawnTick = 20
        missileCooldown = 0
        empCooldown = 0
        over = false
        paused = false
        status = "Wave 1 — tap incoming threats"
        snd("start")
        field.requestPaint()
    }

    function spawnThreat() {
        var cx = centerX()
        var cy = centerY()
        var angle = GameRandom.nextReal() * Math.PI * 2
        var radius = Math.max(field.width, field.height) * 0.63 + 35
        var kindRoll = GameRandom.nextReal()
        var kind = "DRONE"
        if (wave % 5 === 0 && spawnedBossWave !== wave) { kind = "DREADNOUGHT"; spawnedBossWave = wave }
        else if (wave >= 8 && kindRoll > 0.94) kind = "CARRIER"
        else if (wave >= 5 && kindRoll > 0.84) kind = "CRUISER"
        else if (wave >= 4 && kindRoll > 0.68) kind = "BOMBER"
        else if (wave >= 3 && kindRoll > 0.48) kind = "COMET"
        var hp = kind === "DREADNOUGHT" ? 28 + wave*4 : (kind === "CARRIER" ? 14+wave*2 : (kind === "CRUISER" ? 7+wave : (kind === "BOMBER" ? 5+Math.floor(wave/2) : (kind === "COMET" ? 2+Math.floor(wave/3) : 2+Math.floor(wave/4)))))
        var speed = kind === "DREADNOUGHT" ? 0.25+wave*0.008 : (kind === "CARRIER" ? 0.36+wave*0.012 : (kind === "CRUISER" ? 0.48+wave*0.015 : (kind === "BOMBER" ? 0.60+wave*0.018 : (kind === "COMET" ? 1.15+wave*0.03 : 0.72+wave*0.02))))
        threats.push({x:cx+Math.cos(angle)*radius,y:cy+Math.sin(angle)*radius,hp:hp,maxHp:hp,speed:speed,kind:kind,alive:true})
    }

    function nearestThreat(x, y) {
        var best = null
        var bestDist = 999999999
        for (var i = 0; i < threats.length; ++i) {
            var t = threats[i]
            if (!t.alive)
                continue
            var dx = t.x - x
            var dy = t.y - y
            var d = dx * dx + dy * dy
            if (d < bestDist) {
                best = t
                bestDist = d
            }
        }
        return best
    }

    function launchAt(x, y) {
        if (over || paused || missileCooldown > 0)
            return
        var target = nearestThreat(x, y)
        if (!target)
            return
        if (energy < 12) {
            status = "Not enough energy"
            return
        }
        var dx = target.x - x
        var dy = target.y - y
        if (dx * dx + dy * dy > 90 * 90) {
            status = "Tap closer to a threat"
            return
        }
        energy -= 12
        missileCooldown = 10
        missiles.push({x:centerX(), y:centerY(), target:target, speed:5.2+missileLevel*0.35, damage:2+missileLevel, alive:true})
        snd("shoot")
    }

    function emp() {
        if (over || paused || empCooldown > 0)
            return
        if (energy < 55) {
            status = "Need 55 energy for EMP"
            return
        }
        energy -= 55
        empCooldown = 520
        pulses.push({radius: 28, life: 40})
        var cx = centerX()
        var cy = centerY()
        for (var i = 0; i < threats.length; ++i) {
            var t = threats[i]
            if (!t.alive)
                continue
            var dx = t.x - cx
            var dy = t.y - cy
            if (dx * dx + dy * dy < 230 * 230) {
                t.hp -= 2 + missileLevel
                if (t.hp <= 0)
                    destroyThreat(t)
            }
        }
        status = "EMP discharged"
        snd("wave")
        field.requestPaint()
    }

    function repair() {
        if (planetHp >= maxPlanetHp || energy < 35)
            return
        energy -= 35
        planetHp = Math.min(maxPlanetHp, planetHp + 2)
        status = "Planet shield repaired"
        snd("hit")
    }

    function destroyThreat(threat) {
        if (!threat.alive)
            return
        threat.alive = false
        waveKills++
        var reward = threat.kind === "DREADNOUGHT" ? 700 : (threat.kind === "CARRIER" ? 280 : (threat.kind === "CRUISER" ? 150 : (threat.kind === "BOMBER" ? 105 : (threat.kind === "COMET" ? 75 : 45))))
        score += reward
        credits += Math.max(2, Math.floor(reward / 12))
        if (threat.kind === "DREADNOUGHT") { Achievements.unlock("orbital_boss"); commandPoints += 2 }
        bestScore = Math.max(bestScore, score); bestWave = Math.max(bestWave, wave); GameStats.submitHighScore(bestScore)
        snd("hit")
    }

    function nextWave() {
        wave++
        waveKills = 0
        waveTarget = 6 + wave * 2
        spawnTick = 50
        energy = Math.min(100, energy + 25)
        credits += 18 + wave * 4
        shield = Math.min(maxShield, shield + 2 + shieldLevel)
        bestWave = Math.max(bestWave, wave); GameStats.submitHighScore(bestWave, "best_wave"); persistState()
        status = "Wave " + wave + " — defenses recharged"
        snd("wave")
    }

    function upgradeMissile() { var cost=45+missileLevel*35; if(credits<cost||missileLevel>=6)return; credits-=cost; missileLevel++; status="Missile guidance upgraded to L"+missileLevel; persistState(); snd("wave") }
    function upgradeShield() { var cost=55+shieldLevel*40; if(credits<cost||shieldLevel>=6)return; credits-=cost; shieldLevel++; maxShield=8+shieldLevel*4; shield=Math.min(maxShield,shield+5); status="Orbital shield upgraded"; persistState(); snd("wave") }
    function upgradeDrone() { var cost=80+droneLevel*55; if(credits<cost||droneLevel>=5)return; credits-=cost; droneLevel++; status="Auto-defense drone L"+droneLevel; persistState(); snd("wave") }
    function autoDefense() { if(droneLevel<=0||paused||over)return; var t=nearestThreat(centerX(),centerY()); if(!t)return; t.hp-=droneLevel; if(t.hp<=0)destroyThreat(t) }

    function tick() {
        if (field.width < 100 || field.height < 140)
            return
        if (paused || over) {
            field.requestPaint()
            return
        }
        energy = Math.min(100, energy + 0.085 + shieldLevel*0.004)
        shield = Math.min(maxShield, shield + 0.003 * shieldLevel)
        autoTick++; if (autoTick >= Math.max(18, 70-droneLevel*10)) { autoTick=0; autoDefense() }
        if (missileCooldown > 0)
            missileCooldown--
        if (empCooldown > 0)
            empCooldown--

        spawnTick--
        if (spawnTick <= 0 && waveKills < waveTarget) {
            spawnThreat()
            spawnTick = Math.max(20, 62 - wave * 2)
        }

        var cx = centerX()
        var cy = centerY()
        for (var i = 0; i < threats.length; ++i) {
            var threat = threats[i]
            if (!threat.alive)
                continue
            var dx = cx - threat.x
            var dy = cy - threat.y
            var dist = Math.max(0.001, Math.sqrt(dx * dx + dy * dy))
            threat.x += dx / dist * threat.speed
            threat.y += dy / dist * threat.speed
            if (dist < 44) {
                threat.alive = false
                var impact = threat.kind === "DREADNOUGHT" ? 4 : (threat.kind === "CARRIER" ? 2 : 1)
                var absorbed = Math.min(shield, impact); shield -= absorbed; impact -= absorbed
                if (impact > 0) planetHp = Math.max(0, planetHp - impact)
                status = "Planet hit — " + planetHp + " integrity · shield " + shield
                snd("hurt")
                if (planetHp <= 0) {
                    planetHp = 0
                    over = true
                    status = "Planet lost"
                    snd("fail")
                }
            }
        }

        for (var m = 0; m < missiles.length; ++m) {
            var missile = missiles[m]
            if (!missile.alive || !missile.target || !missile.target.alive) {
                missile.alive = false
                continue
            }
            var mdx = missile.target.x - missile.x
            var mdy = missile.target.y - missile.y
            var md = Math.max(0.001, Math.sqrt(mdx * mdx + mdy * mdy))
            missile.x += mdx / md * missile.speed
            missile.y += mdy / md * missile.speed
            if (md <= missile.speed + 5) {
                missile.alive = false
                missile.target.hp -= missile.damage
                if (missile.target.hp <= 0)
                    destroyThreat(missile.target)
                else
                    snd("hit")
            }
        }

        for (var p = 0; p < pulses.length; ++p) {
            pulses[p].radius += 6
            pulses[p].life--
        }

        var alive = false
        for (var a = 0; a < threats.length; ++a) {
            if (threats[a].alive) { alive = true; break }
        }
        if (waveKills >= waveTarget && !alive)
            nextWave()

        if (threats.length > 120)
            threats = threats.filter(function(v) { return v.alive })
        if (missiles.length > 150)
            missiles = missiles.filter(function(v) { return v.alive })
        if (pulses.length > 40)
            pulses = pulses.filter(function(v) { return v.life > 0 })
        field.requestPaint()
    }


    // v0.6.2 public runtime integration. The classic UI/game loop stays intact.
    function tr(key, fallback) { return GameI18n.text(key, fallback) }
    function persistState() {
        GameSave.set("bestScore", bestScore)
        GameSave.set("bestWave", bestWave)
        GameSave.set("credits", credits)
        GameSave.set("missileLevel", missileLevel)
        GameSave.set("shieldLevel", shieldLevel)
        GameSave.set("droneLevel", droneLevel)
        GameSave.save("autosave")
    }
    function restoreState() {
        if (GameSave.load("autosave")) {
            bestScore = GameSave.get("bestScore", bestScore)
            bestWave = GameSave.get("bestWave", bestWave)
            credits = GameSave.get("credits", credits)
            missileLevel = GameSave.get("missileLevel", missileLevel)
            shieldLevel = GameSave.get("shieldLevel", shieldLevel)
            droneLevel = GameSave.get("droneLevel", droneLevel)
        }
    }


    function fireNearest() {
        var t = nearestThreat(centerX(), centerY())
        if (t) launchAt(t.x, t.y)
    }
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_P) { paused = !paused; event.accepted = true }
        else if (event.key === Qt.Key_F || event.key === Qt.Key_Return) { fireNearest(); event.accepted = true }
        else if (event.key === Qt.Key_E) { emp(); event.accepted = true }
        else if (event.key === Qt.Key_R) { repair(); event.accepted = true }
        else if (event.key === Qt.Key_1) { upgradeMissile(); event.accepted = true }
        else if (event.key === Qt.Key_2) { upgradeShield(); event.accepted = true }
        else if (event.key === Qt.Key_3) { upgradeDrone(); event.accepted = true }
    }


    Connections {
        target: Lifecycle
        function onSaveRequested() { root.persistState() }
        function onBackgrounded() { root.lifecyclePaused = !root.paused; root.paused = true; root.persistState() }
        function onForegrounded() { if (root.lifecyclePaused) root.paused = false; root.lifecyclePaused = false }
    }
    Connections {
        target: GameInput
        function onActionPressed(action, value) { if(action==="fire") fireNearest(); else if(action==="pause") paused=!paused; else if(action==="ability") emp(); }
    }

    Component.onCompleted: {
        GameRandom.seed("orbital_commander")
        GameStats.increment("sessions")
        var names = ["start", "shoot", "hit", "hurt", "wave", "fail"]
        for (var i = 0; i < names.length; ++i)
            GameAudio.preload(Qt.resolvedUrl("sfx/" + names[i] + ".wav"))
        restoreState(); maxShield=8+shieldLevel*4; shield=maxShield; initTimer.start()
    }

    Component.onDestruction: persistState()

    Rectangle { anchors.fill: parent; color: bg }

    Rectangle {
        id: hud
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 68
        color: panel
        border.color: bronze
        Column {
            anchors.centerIn: parent
            spacing: 3
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                Text { text: tr("planet","PLANET") + " " + planetHp + "/" + maxPlanetHp; color: planetHp <= 4 ? red : cream; font.pixelSize: 12; font.bold: true }
                Text { text: tr("energy","ENERGY") + " " + Math.floor(energy); color: energy < 20 ? red : blue; font.pixelSize: 12; font.bold: true }
                Text { text: tr("shield","SHIELD") + " " + Math.floor(shield) + "/" + maxShield; color: shield < 3 ? red : blue; font.pixelSize: 12 }
                Text { text: tr("credits","CREDITS") + " " + credits; color: gold; font.pixelSize: 12 }
                Text { text: tr("wave","WAVE") + " " + wave; color: cream; font.pixelSize: 12 }
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
            if (width < 40 || height < 80)
                return
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = root.bg
            ctx.fillRect(0, 0, width, height)
            var cx = width / 2
            var cy = height / 2

            ctx.strokeStyle = Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.22)
            ctx.lineWidth = 1
            ctx.beginPath(); ctx.arc(cx, cy, Math.max(20, Math.min(width, height) * 0.28), 0, Math.PI * 2); ctx.stroke()
            ctx.beginPath(); ctx.arc(cx, cy, Math.max(28, Math.min(width, height) * 0.42), 0, Math.PI * 2); ctx.stroke()

            ctx.fillStyle = root.blue
            ctx.beginPath(); ctx.arc(cx, cy, 32, 0, Math.PI * 2); ctx.fill()
            ctx.fillStyle = root.green
            ctx.beginPath(); ctx.arc(cx - 8, cy - 6, 10, 0, Math.PI * 2); ctx.fill()
            ctx.strokeStyle = root.gold
            ctx.lineWidth = 2
            ctx.beginPath(); ctx.arc(cx, cy, 38, 0, Math.PI * 2); ctx.stroke()

            for (var i = 0; i < root.threats.length; ++i) {
                var t = root.threats[i]
                if (!t.alive)
                    continue
                ctx.fillStyle = t.kind === "DREADNOUGHT" ? root.red : (t.kind === "CARRIER" ? root.blue : (t.kind === "CRUISER" ? root.gold : (t.kind === "BOMBER" ? root.bronze : (t.kind === "COMET" ? root.red : root.cream))))
                var rr = t.kind === "DREADNOUGHT" ? 20 : (t.kind === "CARRIER" ? 16 : (t.kind === "CRUISER" ? 13 : (t.kind === "BOMBER" ? 10 : (t.kind === "COMET" ? 8 : 7))))
                ctx.beginPath(); ctx.arc(t.x, t.y, rr, 0, Math.PI * 2); ctx.fill()
                var ratio = Math.max(0, t.hp / Math.max(1, t.maxHp))
                if (t.hp < t.maxHp) {
                    ctx.fillStyle = Qt.darker(root.red, 1.45)
                    ctx.fillRect(t.x - 12, t.y - rr - 6, 24, 3)
                    ctx.fillStyle = root.green
                    ctx.fillRect(t.x - 12, t.y - rr - 6, 24 * ratio, 3)
                }
            }

            ctx.fillStyle = root.gold
            for (var m = 0; m < root.missiles.length; ++m) {
                var missile = root.missiles[m]
                if (!missile.alive)
                    continue
                ctx.beginPath(); ctx.arc(missile.x, missile.y, 3, 0, Math.PI * 2); ctx.fill()
            }

            for (var p = 0; p < root.pulses.length; ++p) {
                var pulse = root.pulses[p]
                if (pulse.life <= 0)
                    continue
                ctx.globalAlpha = Math.max(0, pulse.life / 40)
                ctx.strokeStyle = root.blue
                ctx.lineWidth = 3
                ctx.beginPath(); ctx.arc(cx, cy, Math.max(1, pulse.radius), 0, Math.PI * 2); ctx.stroke()
            }
            ctx.globalAlpha = 1

            ctx.fillStyle = root.muted
            ctx.font = "11px sans-serif"
            ctx.textAlign = "left"
            ctx.fillText("Neutralized " + root.waveKills + " / " + root.waveTarget, 10, 20)

            if (root.paused || root.over) {
                ctx.fillStyle = Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.82)
                ctx.fillRect(0, 0, width, height)
                ctx.fillStyle = root.gold
                ctx.font = "bold 24px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText(root.over ? "PLANET LOST" : "PAUSED", width / 2, height / 2)
            }
        }

        TapHandler {
            onTapped: function(point) {
                if (root.over) { root.restart(); return }
                root.launchAt(point.position.x, point.position.y)
            }
        }
    }

    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 108
        color: panel
        border.color: bronze
        Column {
            anchors.centerIn: parent
            spacing: 5
            Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 7
                GameButton { width: 104; text: "EMP 55 [E]"; enabled: root.empCooldown <= 0; onClicked: root.emp() }
                GameButton { width: 104; text: "REPAIR [R]"; enabled: root.planetHp < root.maxPlanetHp; onClicked: root.repair() }
                GameButton { width: 92; text: root.paused ? tr("play","PLAY") : tr("pause","PAUSE"); onClicked: root.paused = !root.paused }
            }
            Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                GameButton { width: 100; height: 34; text: tr("missile","MISSILE")+" L"+root.missileLevel; onClicked: root.upgradeMissile() }
                GameButton { width: 100; height: 34; text: tr("shield","SHIELD")+" L"+root.shieldLevel; onClicked: root.upgradeShield() }
                GameButton { width: 100; height: 34; text: tr("drone","DRONE")+" L"+root.droneLevel; onClicked: root.upgradeDrone() }
            }
        }
    }

    Timer { interval: 16; repeat: true; running: true; onTriggered: root.tick() }
    Timer { id: initTimer; interval: 1; repeat: false; onTriggered: root.restart() }
}
