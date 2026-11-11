import QtQuick
import QtQuick.Controls

FocusScope {
    id: root
    anchors.fill: parent
    focus: true
    property bool lifecyclePaused: false

    property color bg: GameTheme.color("color.background")
    property color panel: GameTheme.color("color.surfaceRaised")
    property color gold: GameTheme.color("color.primary")
    property color cream: GameTheme.color("color.text")
    property color bronze: GameTheme.color("color.borderStrong")
    property color green: GameTheme.color("color.success")
    property color red: GameTheme.color("color.danger")

    property int cols: 18
    property int rows: 24
    property var snake: []
    property var obstacles: []
    property int foodX: 10
    property int foodY: 10
    property int dirX: 1
    property int dirY: 0
    property int nextX: 1
    property int nextY: 0
    property int score: 0
    property int best: 0
    property int level: 1
    property int eaten: 0
    property bool over: false
    property bool paused: false
    property real pressX: 0
    property real pressY: 0
    property string status: tr("status_initial", "Swipe or use arrows")
    property int unlockedLevel: 1

    function snd(name) { GameAudio.playEffect(Qt.resolvedUrl("sfx/" + name + ".wav")) }
    function key(x, y) { return x + ":" + y }

    function occupiesSnake(x, y, includeTail) {
        var limit = includeTail ? snake.length : Math.max(0, snake.length - 1)
        for (var i = 0; i < limit; ++i) {
            if (snake[i].x === x && snake[i].y === y)
                return true
        }
        return false
    }

    function occupiesObstacle(x, y) {
        for (var i = 0; i < obstacles.length; ++i) {
            if (obstacles[i].x === x && obstacles[i].y === y)
                return true
        }
        return false
    }

    function randomEmptyCell() {
        for (var tries = 0; tries < 300; ++tries) {
            var x = Math.floor(GameRandom.nextReal() * cols)
            var y = Math.floor(GameRandom.nextReal() * rows)
            if (!occupiesSnake(x, y, true) && !occupiesObstacle(x, y) && !(x === foodX && y === foodY))
                return {x: x, y: y}
        }
        return {x: 0, y: 0}
    }

    function spawnFood() {
        var p = randomEmptyCell()
        foodX = p.x
        foodY = p.y
    }

    function buildObstacles() {
        obstacles = []
        var count = Math.min(24, Math.max(0, (level - 1) * 2))
        for (var i = 0; i < count; ++i) {
            var p = randomEmptyCell()
            if (Math.abs(p.x - Math.floor(cols / 2)) + Math.abs(p.y - Math.floor(rows / 2)) > 4)
                obstacles.push(p)
        }
    }

    function restart() {
        var cx = Math.floor(cols / 2)
        var cy = Math.floor(rows / 2)
        snake = [{x: cx, y: cy}, {x: cx - 1, y: cy}, {x: cx - 2, y: cy}]
        dirX = 1
        dirY = 0
        nextX = 1
        nextY = 0
        score = 0
        level = 1
        eaten = 0
        over = false
        paused = false
        status = "Collect 5 cells to level up"
        obstacles = []
        spawnFood()
        snd("start")
        board.requestPaint()
    }

    function setDirection(x, y) {
        if (x === -dirX && y === -dirY)
            return
        nextX = x
        nextY = y
    }

    function endRun() {
        over = true
        best = Math.max(best, score); GameStats.submitHighScore(best)
        GameSave.set("best", best); GameSave.save("autosave")
        status = "Circuit broken — tap RESTART"
        snd("fail")
    }

    function step() {
        if (over || paused)
            return
        dirX = nextX
        dirY = nextY
        var head = snake[0]
        var nx = head.x + dirX
        var ny = head.y + dirY
        if (nx < 0 || ny < 0 || nx >= cols || ny >= rows || occupiesObstacle(nx, ny) || occupiesSnake(nx, ny, false)) {
            endRun()
            board.requestPaint()
            return
        }

        var ate = nx === foodX && ny === foodY
        var nextSnake = [{x: nx, y: ny}]
        for (var i = 0; i < snake.length; ++i)
            nextSnake.push(snake[i])
        if (!ate)
            nextSnake.pop()
        snake = nextSnake

        if (ate) {
            eaten++
            score += 20 * level
            if (score >= 1000) Achievements.unlock("score_1000")
            snd("eat")
            if (eaten % 5 === 0) {
                level++
                score += 100
                if (level >= 5) Achievements.unlock("circuit_level_5")
                buildObstacles()
                status = "Level " + level + " — speed increased"
                snd("level")
            }
            spawnFood()
        }
        board.requestPaint()
    }

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_A) { setDirection(-1, 0); event.accepted = true }
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) { setDirection(1, 0); event.accepted = true }
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_W) { setDirection(0, -1); event.accepted = true }
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_S) { setDirection(0, 1); event.accepted = true }
        else if (event.key === Qt.Key_P || event.key === Qt.Key_Space) { paused = !paused; event.accepted = true }
        else if (event.key === Qt.Key_R) { restart(); event.accepted = true }
    }


    // v0.6.2 public runtime integration. The classic UI/game loop stays intact.
    function tr(key, fallback) { return GameI18n.text(key, fallback) }
    function persistState() {
        GameSave.set("best", best)
        GameSave.set("unlockedLevel", unlockedLevel)
        GameSave.save("autosave")
    }
    function restoreState() {
        if (GameSave.load("autosave")) {
            best = GameSave.get("best", best)
            unlockedLevel = GameSave.get("unlockedLevel", unlockedLevel)
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
        function onActionPressed(action, value) { if(action==="move_left") setDirection(-1,0); else if(action==="move_right") setDirection(1,0); else if(action==="up") setDirection(0,-1); else if(action==="down") setDirection(0,1); else if(action==="pause") paused=!paused; else if(action==="restart") restart(); }
    }

    Component.onCompleted: {
        GameRandom.seed("snake_circuit")
        GameStats.increment("sessions")
        restoreState(); best = Number(GameSave.get("best", best))
        var names = ["start", "eat", "level", "fail"]
        for (var i = 0; i < names.length; ++i)
            GameAudio.preload(Qt.resolvedUrl("sfx/" + names[i] + ".wav"))
        restart()
        forceActiveFocus()
    }

    onVisibleChanged: if (visible) forceActiveFocus()

    Component.onDestruction: persistState()

    Rectangle { anchors.fill: parent; color: bg }

    Rectangle {
        id: hud
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 62
        color: panel
        border.color: bronze
        Column {
            anchors.centerIn: parent
            spacing: 2
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18
                Text { text: tr("score","SCORE") + " " + score; color: gold; font.pixelSize: 13; font.bold: true }
                Text { text: tr("best","BEST") + " " + best; color: cream; font.pixelSize: 12 }
                Text { text: tr("level","LEVEL") + " " + level; color: green; font.pixelSize: 12; font.bold: true }
                Text { text: tr("length","LEN") + " " + snake.length; color: cream; font.pixelSize: 12 }
            }
            Text { text: status; color: cream; font.pixelSize: 10; width: Math.max(0, Math.min(root.width - 20, 520)); horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
        }
    }

    Canvas {
        id: board
        anchors.top: hud.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.margins: 8

        onPaint: {
            if (width < 18 || height < 24)
                return
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = root.panel
            ctx.fillRect(0, 0, width, height)
            var cell = Math.max(1, Math.min(width / root.cols, height / root.rows))
            var ox = (width - cell * root.cols) / 2
            var oy = (height - cell * root.rows) / 2

            ctx.strokeStyle = "rgba(154,91,46,0.18)"
            ctx.lineWidth = 1
            for (var x = 0; x <= root.cols; ++x) {
                ctx.beginPath(); ctx.moveTo(ox + x * cell, oy); ctx.lineTo(ox + x * cell, oy + root.rows * cell); ctx.stroke()
            }
            for (var y = 0; y <= root.rows; ++y) {
                ctx.beginPath(); ctx.moveTo(ox, oy + y * cell); ctx.lineTo(ox + root.cols * cell, oy + y * cell); ctx.stroke()
            }

            ctx.fillStyle = root.bronze
            for (var o = 0; o < root.obstacles.length; ++o) {
                var ob = root.obstacles[o]
                ctx.fillRect(ox + ob.x * cell + 1, oy + ob.y * cell + 1, Math.max(1, cell - 2), Math.max(1, cell - 2))
            }

            ctx.fillStyle = root.gold
            ctx.beginPath()
            ctx.arc(ox + (root.foodX + 0.5) * cell, oy + (root.foodY + 0.5) * cell, Math.max(2, cell * 0.28), 0, Math.PI * 2)
            ctx.fill()

            for (var i = root.snake.length - 1; i >= 0; --i) {
                var part = root.snake[i]
                ctx.fillStyle = i === 0 ? root.cream : root.green
                var inset = i === 0 ? 1 : 2
                ctx.fillRect(ox + part.x * cell + inset, oy + part.y * cell + inset, Math.max(1, cell - inset * 2), Math.max(1, cell - inset * 2))
            }

            if (root.paused || root.over) {
                ctx.fillStyle = "rgba(8,5,3,0.70)"
                ctx.fillRect(0, 0, width, height)
                ctx.fillStyle = root.gold
                ctx.font = "bold 22px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText(root.over ? "RUN OVER" : "PAUSED", width / 2, height / 2)
            }
        }

        MouseArea {
            anchors.fill: parent
            onPressed: function(mouse) { root.forceActiveFocus(); root.pressX = mouse.x; root.pressY = mouse.y }
            onReleased: function(mouse) {
                var dx = mouse.x - root.pressX
                var dy = mouse.y - root.pressY
                if (Math.abs(dx) < 12 && Math.abs(dy) < 12) {
                    if (root.over) root.restart()
                    return
                }
                if (Math.abs(dx) > Math.abs(dy))
                    root.setDirection(dx > 0 ? 1 : -1, 0)
                else
                    root.setDirection(0, dy > 0 ? 1 : -1)
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
            GameButton { width: 110; text: root.paused ? "RESUME" : "PAUSE"; onClicked: { root.forceActiveFocus(); root.paused = !root.paused } }
            GameButton { width: 110; text: tr("restart","RESTART"); onClicked: { root.forceActiveFocus(); root.restart() } }
        }
    }

    Timer {
        interval: Math.max(58, 155 - (root.level - 1) * 9)
        repeat: true
        running: true
        onTriggered: root.step()
    }
}
