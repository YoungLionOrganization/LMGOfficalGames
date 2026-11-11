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

    property var bricks: []
    property var drops: []
    property real paddleX: 0
    property real paddleW: 108
    property real ballX: 0
    property real ballY: 0
    property real ballVX: 190
    property real ballVY: -250
    property real ballRadius: 7
    property int score: 0
    property int best: 0
    property int level: 1
    property int lives: 3
    property int combo: 0
    property int wideTicks: 0
    property int slowTicks: 0
    property bool running: false
    property bool gameOver: false
    property bool paused: false
    property string status: tr("status_initial", "Tap the field to launch")

    function snd(name) { GameAudio.playEffect(Qt.resolvedUrl("sfx/" + name + ".wav")) }

    function clamp(value, low, high) { return Math.max(low, Math.min(high, value)) }

    function levelPattern(row, col, rows, cols) {
        var mode = (level - 1) % 4
        if (mode === 0)
            return true
        if (mode === 1)
            return row === 0 || row === rows - 1 || col === 0 || col === cols - 1 || ((row + col) % 3 !== 0)
        if (mode === 2)
            return Math.abs(col - (cols - 1) / 2) <= row + 1
        return (row + col) % 2 === 0 || row < 2
    }

    function buildBricks() {
        bricks = []
        drops = []
        if (field.width < 80 || field.height < 180)
            return
        var cols = field.width < 380 ? 7 : 9
        var rows = Math.min(7, 4 + Math.floor((level - 1) / 2))
        var gap = 5
        var margin = 10
        var top = 38
        var brickH = 22
        var brickW = Math.max(12, (field.width - margin * 2 - gap * (cols - 1)) / cols)
        for (var r = 0; r < rows; ++r) {
            for (var c = 0; c < cols; ++c) {
                if (!levelPattern(r, c, rows, cols))
                    continue
                var hp = 1
                if ((r + c + level) % 8 === 0)
                    hp = 2
                if (level >= 5 && (r * 3 + c) % 13 === 0)
                    hp = 3
                bricks.push({
                    x: margin + c * (brickW + gap),
                    y: top + r * (brickH + gap),
                    w: brickW,
                    h: brickH,
                    hp: hp,
                    maxHp: hp,
                    alive: true
                })
            }
        }
    }

    function resetBall() {
        running = false
        paddleW = wideTicks > 0 ? 158 : 108
        paddleX = clamp(field.width / 2 - paddleW / 2, 0, Math.max(0, field.width - paddleW))
        ballX = field.width / 2
        ballY = Math.max(100, field.height - 76)
        var speedX = 175 + level * 8
        ballVX = (GameRandom.nextReal() < 0.5 ? -1 : 1) * speedX
        ballVY = -(235 + level * 10)
        combo = 0
        status = "Tap the field to launch"
        field.requestPaint()
    }

    function newRun() {
        score = 0
        level = 1
        lives = 3
        combo = 0
        wideTicks = 0
        slowTicks = 0
        paused = false
        gameOver = false
        buildBricks()
        resetBall()
        snd("start")
    }

    function nextLevel() {
        running = false
        level++
        score += 250 * level
        if (level >= 5) Achievements.unlock("forge_level_5")
        if (level >= 10) Achievements.unlock("forge_level_10")
        status = "Level " + level
        snd("win")
        buildBricks()
        resetBall()
    }

    function launch() {
        if (gameOver) {
            newRun()
            return
        }
        if (!running && !paused) {
            running = true
            status = ""
            snd("launch")
        }
    }

    function brickAlive() {
        for (var i = 0; i < bricks.length; ++i) {
            if (bricks[i].alive)
                return true
        }
        return false
    }

    function damageBrick(index) {
        var brick = bricks[index]
        if (!brick.alive)
            return
        brick.hp--
        combo++
        score += 10 + Math.min(100, combo * 3)
        if (brick.hp <= 0) {
            brick.alive = false
            if (GameRandom.nextReal() < 0.16) {
                var types = ["WIDE", "SLOW", "LIFE"]
                drops.push({
                    x: brick.x + brick.w / 2,
                    y: brick.y + brick.h,
                    type: types[Math.floor(GameRandom.nextReal() * types.length)],
                    alive: true
                })
            }
            snd("hit")
        } else {
            snd("chip")
        }
    }

    function loseLife() {
        lives--
        snd("fail")
        if (lives <= 0) {
            gameOver = true
            running = false
            status = "Run over — tap to restart"
            best = Math.max(best, score); GameStats.submitHighScore(best)
            GameSave.set("best", best); GameSave.save("autosave")
        } else {
            resetBall()
        }
    }

    function applyDrop(drop) {
        if (drop.type === "WIDE") {
            paddleW = 158
            wideTicks = 650
        } else if (drop.type === "SLOW") {
            slowTicks = 520
        } else {
            lives = Math.min(5, lives + 1)
        }
        score += 60
        snd("power")
    }

    function tick() {
        if (field.width < 80 || field.height < 180)
            return
        if (paused || gameOver) {
            field.requestPaint()
            return
        }

        if (wideTicks > 0) {
            wideTicks--
            if (wideTicks === 0) {
                paddleW = 108
                paddleX = clamp(paddleX, 0, field.width - paddleW)
            }
        }
        if (slowTicks > 0)
            slowTicks--

        if (!running) {
            ballX = clamp(paddleX + paddleW / 2, ballRadius, field.width - ballRadius)
            ballY = Math.max(80, field.height - 76)
            field.requestPaint()
            return
        }

        var dt = 0.016 * (slowTicks > 0 ? 0.72 : 1.0)
        var oldX = ballX
        var oldY = ballY
        ballX += ballVX * dt
        ballY += ballVY * dt

        if (ballX <= ballRadius) {
            ballX = ballRadius
            ballVX = Math.abs(ballVX)
        } else if (ballX >= field.width - ballRadius) {
            ballX = field.width - ballRadius
            ballVX = -Math.abs(ballVX)
        }
        if (ballY <= ballRadius) {
            ballY = ballRadius
            ballVY = Math.abs(ballVY)
        }

        var paddleY = field.height - 42
        if (ballVY > 0 && ballY + ballRadius >= paddleY && oldY <= paddleY + 12 && ballX >= paddleX - ballRadius && ballX <= paddleX + paddleW + ballRadius) {
            ballY = paddleY - ballRadius - 1
            var relative = (ballX - (paddleX + paddleW / 2)) / Math.max(1, paddleW / 2)
            var speed = Math.min(390, 260 + level * 12)
            ballVX = relative * speed
            ballVY = -Math.max(220, Math.abs(ballVY) * 1.01)
            combo = 0
            snd("paddle")
        }

        for (var i = 0; i < bricks.length; ++i) {
            var b = bricks[i]
            if (!b.alive)
                continue
            if (ballX + ballRadius > b.x && ballX - ballRadius < b.x + b.w && ballY + ballRadius > b.y && ballY - ballRadius < b.y + b.h) {
                var cameFromVertical = oldY + ballRadius <= b.y || oldY - ballRadius >= b.y + b.h
                if (cameFromVertical)
                    ballVY = -ballVY
                else
                    ballVX = -ballVX
                damageBrick(i)
                break
            }
        }

        for (var d = 0; d < drops.length; ++d) {
            var drop = drops[d]
            if (!drop.alive)
                continue
            drop.y += 2.0
            if (drop.y > field.height + 12) {
                drop.alive = false
                continue
            }
            if (drop.y + 9 >= paddleY && drop.x >= paddleX && drop.x <= paddleX + paddleW) {
                drop.alive = false
                applyDrop(drop)
            }
        }

        if (ballY > field.height + 16) {
            loseLife()
        } else if (!brickAlive()) {
            nextLevel()
        }

        field.requestPaint()
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_A) {
            paddleX = clamp(paddleX - 28, 0, field.width - paddleW)
            event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) {
            paddleX = clamp(paddleX + 28, 0, field.width - paddleW)
            event.accepted = true
        } else if (event.key === Qt.Key_Space) {
            launch()
            event.accepted = true
        } else if (event.key === Qt.Key_P) {
            paused = !paused
            event.accepted = true
        }
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
        function onActionPressed(action, value) { if(action==="move_left") paddleX=clamp(paddleX-28,0,field.width-paddleW); else if(action==="move_right") paddleX=clamp(paddleX+28,0,field.width-paddleW); else if(action==="fire") launch(); else if(action==="pause") paused=!paused; }
    }

    Component.onCompleted: {
        GameRandom.seed("brick_forge")
        GameStats.increment("sessions")
        restoreState(); best = Number(GameSave.get("best", best))
        var names = ["start", "launch", "hit", "chip", "paddle", "power", "fail", "win"]
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
        height: 56
        color: panel
        border.color: bronze
        Row {
            anchors.centerIn: parent
            spacing: 16
            Text { text: tr("score","SCORE") + " " + root.score; color: gold; font.pixelSize: 13; font.bold: true }
            Text { text: tr("best","BEST") + " " + root.best; color: cream; font.pixelSize: 12 }
            Text { text: tr("level","LEVEL") + " " + root.level; color: cream; font.pixelSize: 12 }
            Text { text: tr("lives","LIVES") + " " + root.lives; color: root.lives <= 1 ? red : cream; font.pixelSize: 12 }
            Text { text: root.combo >= 4 ? "x" + root.combo : ""; color: green; font.pixelSize: 12; font.bold: true }
        }
    }

    Canvas {
        id: field
        anchors.top: hud.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.margins: 8

        onWidthChanged: {
            root.paddleX = root.clamp(root.paddleX, 0, Math.max(0, width - root.paddleW))
            if (root.bricks.length === 0 && width > 100)
                initTimer.restart()
        }

        onPaint: {
            if (width < 40 || height < 100)
                return
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = root.panel
            ctx.fillRect(0, 0, width, height)

            for (var i = 0; i < root.bricks.length; ++i) {
                var b = root.bricks[i]
                if (!b.alive)
                    continue
                ctx.fillStyle = b.hp >= 3 ? root.red : (b.hp === 2 ? root.gold : root.bronze)
                ctx.fillRect(b.x, b.y, Math.max(1, b.w), Math.max(1, b.h))
                ctx.strokeStyle = Qt.lighter(root.gold, 1.16)
                ctx.lineWidth = 1
                ctx.strokeRect(b.x + 0.5, b.y + 0.5, Math.max(1, b.w - 1), Math.max(1, b.h - 1))
            }

            for (var d = 0; d < root.drops.length; ++d) {
                var drop = root.drops[d]
                if (!drop.alive)
                    continue
                ctx.fillStyle = drop.type === "LIFE" ? root.green : (drop.type === "SLOW" ? root.blue : root.gold)
                ctx.fillRect(drop.x - 12, drop.y - 7, 24, 14)
                ctx.fillStyle = root.bg
                ctx.font = "bold 8px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText(drop.type.charAt(0), drop.x, drop.y)
            }

            var paddleY = height - 42
            ctx.fillStyle = root.gold
            ctx.fillRect(root.paddleX, paddleY, Math.max(1, root.paddleW), 14)
            ctx.fillStyle = root.cream
            ctx.fillRect(root.paddleX + 5, paddleY + 3, Math.max(1, root.paddleW - 10), 3)

            ctx.fillStyle = root.cream
            ctx.beginPath()
            ctx.arc(root.ballX, root.ballY, Math.max(2, root.ballRadius), 0, Math.PI * 2)
            ctx.fill()

            if (!root.running || root.paused || root.gameOver) {
                ctx.fillStyle = "rgba(8,5,3,0.62)"
                ctx.fillRect(0, 0, width, height)
                ctx.fillStyle = root.gold
                ctx.font = "bold 18px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText(root.paused ? "PAUSED" : root.status, width / 2, height / 2)
            }
        }

        MouseArea {
            anchors.fill: parent
            onPressed: function(mouse) {
                if (root.gameOver) {
                    root.newRun()
                    return
                }
                root.paddleX = root.clamp(mouse.x - root.paddleW / 2, 0, field.width - root.paddleW)
                if (!root.running)
                    root.launch()
            }
            onPositionChanged: function(mouse) {
                if (pressed)
                    root.paddleX = root.clamp(mouse.x - root.paddleW / 2, 0, field.width - root.paddleW)
            }
        }
    }

    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 60
        color: panel
        border.color: bronze
        Row {
            anchors.centerIn: parent
            spacing: 8
            GameButton { width: 118; text: root.running ? "PAUSE" : "LAUNCH"; onClicked: { if (root.running) root.paused = !root.paused; else root.launch() } }
            GameButton { width: 108; text: tr("new_run","NEW RUN"); onClicked: root.newRun() }
        }
    }

    Timer { id: frameTimer; interval: 16; repeat: true; running: true; onTriggered: root.tick() }
    Timer { id: initTimer; interval: 1; repeat: false; onTriggered: root.newRun() }
}
