import QtQuick
import QtQuick.Controls

Item {
    id: root
    anchors.fill: parent
    focus: true

    property color bg: GameTheme.color("color.background")
    property color panel: GameTheme.color("color.surfaceRaised")
    property color gold: GameTheme.color("color.primary")
    property color cream: GameTheme.color("color.text")
    property color bronze: GameTheme.color("color.borderStrong")
    property color green: GameTheme.color("color.success")
    property color red: GameTheme.color("color.danger")
    property color muted: GameTheme.color("color.textMuted")

    property var cells: []
    property var undoCells: []
    property int score: 0
    property int undoScore: 0
    property int best: 0
    property int hammers: 1
    property bool hammerMode: false
    property bool over: false
    property bool won: false
    property real pressX: 0
    property real pressY: 0
    property string status: tr("status_initial", "Swipe to merge matching ingots")

    function snd(name) { GameAudio.playEffect(Qt.resolvedUrl("sfx/" + name + ".wav")) }
    function idx(r, c) { return r * 4 + c }

    function newGame() {
        cells = []
        for (var i = 0; i < 16; ++i)
            cells.push(0)
        score = 0
        hammers = 1
        hammerMode = false
        over = false
        won = false
        status = "Swipe to merge matching ingots"
        addTile()
        addTile()
        snd("start")
        board.requestPaint()
    }

    function emptyIndices(source) {
        var list = []
        for (var i = 0; i < source.length; ++i) {
            if (source[i] === 0)
                list.push(i)
        }
        return list
    }

    function addTile() {
        var empty = emptyIndices(cells)
        if (empty.length === 0)
            return
        var at = empty[Math.floor(GameRandom.nextReal() * empty.length)]
        cells[at] = GameRandom.nextReal() < 0.88 ? 2 : 4
        cells = cells.slice()
    }

    function compressLine(line) {
        var clean = []
        for (var i = 0; i < line.length; ++i) {
            if (line[i] !== 0)
                clean.push(line[i])
        }
        var out = []
        var gained = 0
        for (var j = 0; j < clean.length; ++j) {
            if (j + 1 < clean.length && clean[j] === clean[j + 1]) {
                var value = clean[j] * 2
                out.push(value)
                gained += value
                j++
            } else {
                out.push(clean[j])
            }
        }
        while (out.length < 4)
            out.push(0)
        return {line: out, gained: gained}
    }

    function same(a, b) {
        if (a.length !== b.length)
            return false
        for (var i = 0; i < a.length; ++i) {
            if (a[i] !== b[i])
                return false
        }
        return true
    }

    function move(direction) {
        if (over || hammerMode)
            return
        var old = cells.slice()
        var next = cells.slice()
        var gained = 0

        for (var lineIndex = 0; lineIndex < 4; ++lineIndex) {
            var line = []
            var i
            if (direction === "left") {
                for (i = 0; i < 4; ++i) line.push(next[idx(lineIndex, i)])
            } else if (direction === "right") {
                for (i = 3; i >= 0; --i) line.push(next[idx(lineIndex, i)])
            } else if (direction === "up") {
                for (i = 0; i < 4; ++i) line.push(next[idx(i, lineIndex)])
            } else {
                for (i = 3; i >= 0; --i) line.push(next[idx(i, lineIndex)])
            }

            var result = compressLine(line)
            gained += result.gained
            var n = result.line
            if (direction === "left") {
                for (i = 0; i < 4; ++i) next[idx(lineIndex, i)] = n[i]
            } else if (direction === "right") {
                for (i = 0; i < 4; ++i) next[idx(lineIndex, 3 - i)] = n[i]
            } else if (direction === "up") {
                for (i = 0; i < 4; ++i) next[idx(i, lineIndex)] = n[i]
            } else {
                for (i = 0; i < 4; ++i) next[idx(3 - i, lineIndex)] = n[i]
            }
        }

        if (same(old, next)) {
            status = "No movement in that direction"
            return
        }

        undoCells = old
        undoScore = score
        cells = next
        score += gained
        if (score >= 5000) Achievements.unlock("score_5000")
        if (gained > 0) {
            snd("merge")
            if (score > 0 && score % 500 < gained) {
                hammers = Math.min(3, hammers + 1)
                status = "Hammer earned"
            }
        } else {
            snd("move")
        }
        addTile()
        checkState()
        board.requestPaint()
    }

    function checkState() {
        for (var i = 0; i < 16; ++i) {
            if (cells[i] >= 2048 && !won) {
                won = true
                Achievements.unlock("forge_2048")
                status = "2048 forged — keep going!"
            }
        }
        if (emptyIndices(cells).length > 0)
            return
        for (var r = 0; r < 4; ++r) {
            for (var c = 0; c < 4; ++c) {
                var v = cells[idx(r, c)]
                if (c < 3 && cells[idx(r, c + 1)] === v)
                    return
                if (r < 3 && cells[idx(r + 1, c)] === v)
                    return
            }
        }
        over = true
        best = Math.max(best, score); GameStats.submitHighScore(best)
        GameSave.set("best", best); GameSave.save("autosave")
        status = "Foundry jammed — use NEW"
        snd("fail")
    }

    function undo() {
        if (undoCells.length !== 16 || over)
            return
        cells = undoCells.slice()
        score = undoScore
        undoCells = []
        status = "Last move restored"
        board.requestPaint()
    }

    function useHammer(index) {
        if (!hammerMode || hammers <= 0 || index < 0 || index >= 16 || cells[index] === 0)
            return
        cells[index] = 0
        cells = cells.slice()
        hammers--
        hammerMode = false
        over = false
        status = "Tile removed"
        snd("merge")
        board.requestPaint()
    }

    function tileColor(value) {
        if (value <= 2) return root.panel2
        if (value <= 4) return Qt.lighter(root.panel2,1.12)
        if (value <= 8) return Qt.lighter(root.bronze,1.10)
        if (value <= 16) return Qt.lighter(root.bronze,1.18)
        if (value <= 32) return root.bronze
        if (value <= 64) return Qt.lighter(root.bronze,1.28)
        if (value <= 128) return Qt.lighter(root.gold,1.02)
        if (value <= 256) return root.gold
        if (value <= 512) return Qt.lighter(root.gold, 1.10)
        if (value <= 1024) return Qt.lighter(root.gold, 1.18)
        return Qt.lighter(root.gold, 1.24)
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_A) { move("left"); event.accepted = true }
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) { move("right"); event.accepted = true }
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_W) { move("up"); event.accepted = true }
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_S) { move("down"); event.accepted = true }
    }


    // v0.6.2 public runtime integration. The classic UI/game loop stays intact.
    function tr(key, fallback) { return GameI18n.text(key, fallback) }
    function persistState() {
        GameSave.set("best", best)
        GameSave.set("hammers", hammers)
        GameSave.save("autosave")
    }
    function restoreState() {
        if (GameSave.load("autosave")) {
            best = GameSave.get("best", best)
            hammers = GameSave.get("hammers", hammers)
        }
    }


    Connections {
        target: Lifecycle
        function onSaveRequested() { root.persistState() }
    }
    Connections {
        target: GameInput
        function onActionPressed(action, value) { if(action==="move_left") move("left"); else if(action==="move_right") move("right"); else if(action==="up") move("up"); else if(action==="down") move("down"); }
    }

    Component.onCompleted: {
        GameRandom.seed("merge_foundry")
        GameStats.increment("sessions")
        restoreState(); best = Number(GameSave.get("best", best))
        var names = ["start", "move", "merge", "fail"]
        for (var i = 0; i < names.length; ++i)
            GameAudio.preload(Qt.resolvedUrl("sfx/" + names[i] + ".wav"))
        newGame()
    }

    Component.onDestruction: persistState()

    Rectangle { anchors.fill: parent; color: bg }

    Rectangle {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 66
        color: panel
        border.color: bronze
        Column {
            anchors.centerIn: parent
            spacing: 3
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 20
                Text { text: tr("score","SCORE") + " " + score; color: gold; font.pixelSize: 14; font.bold: true }
                Text { text: tr("best","BEST") + " " + best; color: cream; font.pixelSize: 12 }
                Text { text: tr("hammer","HAMMER") + " " + hammers; color: hammers > 0 ? green : cream; font.pixelSize: 12 }
            }
            Text { text: status; color: hammerMode ? green : cream; font.pixelSize: 10; width: Math.max(0, Math.min(root.width - 20, 520)); horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
        }
    }

    Canvas {
        id: board
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.margins: 10

        onPaint: {
            if (width < 20 || height < 20)
                return
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = root.panel
            ctx.fillRect(0, 0, width, height)
            var size = Math.max(4, Math.min(width, height))
            var cell = size / 4
            var ox = (width - size) / 2
            var oy = (height - size) / 2
            var gap = Math.max(3, cell * 0.05)

            for (var r = 0; r < 4; ++r) {
                for (var c = 0; c < 4; ++c) {
                    var value = root.cells[root.idx(r, c)]
                    var x = ox + c * cell + gap
                    var y = oy + r * cell + gap
                    var w = Math.max(1, cell - gap * 2)
                    ctx.fillStyle = value === 0 ? root.panel2 : root.tileColor(value)
                    ctx.fillRect(x, y, w, w)
                    if (value !== 0) {
                        ctx.fillStyle = value >= 512 ? root.bg : root.cream
                        var digits = String(value).length
                        ctx.font = "bold " + Math.max(12, Math.floor(cell * (digits >= 4 ? 0.25 : 0.34))) + "px sans-serif"
                        ctx.textAlign = "center"
                        ctx.textBaseline = "middle"
                        ctx.fillText(String(value), ox + (c + 0.5) * cell, oy + (r + 0.52) * cell)
                    }
                }
            }

            if (root.over || root.hammerMode) {
                ctx.fillStyle = root.over ? Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.78) : "rgba(8,5,3,0.42)"
                ctx.fillRect(0, 0, width, height)
                ctx.fillStyle = root.gold
                ctx.font = "bold 22px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText(root.over ? "FOUNDRY JAMMED" : "TAP A TILE TO BREAK", width / 2, height / 2)
            }
        }

        MouseArea {
            anchors.fill: parent
            onPressed: function(mouse) { root.pressX = mouse.x; root.pressY = mouse.y }
            onReleased: function(mouse) {
                if (root.hammerMode) {
                    var size = Math.max(4, Math.min(board.width, board.height))
                    var cell = size / 4
                    var ox = (board.width - size) / 2
                    var oy = (board.height - size) / 2
                    var col = Math.floor((mouse.x - ox) / cell)
                    var row = Math.floor((mouse.y - oy) / cell)
                    if (row >= 0 && col >= 0 && row < 4 && col < 4)
                        root.useHammer(root.idx(row, col))
                    return
                }
                var dx = mouse.x - root.pressX
                var dy = mouse.y - root.pressY
                if (Math.abs(dx) < 18 && Math.abs(dy) < 18)
                    return
                if (Math.abs(dx) > Math.abs(dy))
                    root.move(dx > 0 ? "right" : "left")
                else
                    root.move(dy > 0 ? "down" : "up")
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
            GameButton { width: 92; text: tr("undo","UNDO"); enabled: root.undoCells.length === 16; onClicked: root.undo() }
            GameButton { width: 104; text: root.hammerMode ? "CANCEL" : "HAMMER"; enabled: root.hammers > 0; onClicked: root.hammerMode = !root.hammerMode }
            GameButton { width: 92; text: "NEW"; onClicked: root.newGame() }
        }
    }
}
