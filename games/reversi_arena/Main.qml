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
    property color boardGreen: GameTheme.color("color.success")
    property color muted: GameTheme.color("color.textMuted")

    property var board: []
    property int turn: 1
    property bool thinking: false
    property bool finished: false
    property string status: tr("status_initial", "Your turn")
    property string difficulty: "Normal"
    property int wins: 0
    property int losses: 0
    property int draws: 0

    function snd(name) {
        GameAudio.playEffect(Qt.resolvedUrl("sfx/" + name + ".wav"))
    }

    function pos(r, c) { return r * 8 + c }
    function inside(r, c) { return r >= 0 && c >= 0 && r < 8 && c < 8 }

    function flips(r, c, player, source) {
        var b = source || board
        if (!inside(r, c) || b[pos(r, c)] !== 0)
            return []
        var result = []
        var dirs = [[-1,-1],[-1,0],[-1,1],[0,-1],[0,1],[1,-1],[1,0],[1,1]]
        for (var d = 0; d < dirs.length; ++d) {
            var rr = r + dirs[d][0]
            var cc = c + dirs[d][1]
            var line = []
            while (inside(rr, cc) && b[pos(rr, cc)] === -player) {
                line.push(pos(rr, cc))
                rr += dirs[d][0]
                cc += dirs[d][1]
            }
            if (line.length > 0 && inside(rr, cc) && b[pos(rr, cc)] === player)
                result = result.concat(line)
        }
        return result
    }

    function legal(player, source) {
        var out = []
        var b = source || board
        for (var r = 0; r < 8; ++r) {
            for (var c = 0; c < 8; ++c) {
                if (flips(r, c, player, b).length > 0)
                    out.push(pos(r, c))
            }
        }
        return out
    }

    function count(player, source) {
        var b = source || board
        var n = 0
        for (var i = 0; i < b.length; ++i) {
            if (b[i] === player)
                n++
        }
        return n
    }

    function applyMove(source, index, player) {
        var copy = source.slice()
        var r = Math.floor(index / 8)
        var c = index % 8
        var change = flips(r, c, player, copy)
        if (change.length === 0)
            return null
        copy[index] = player
        for (var i = 0; i < change.length; ++i)
            copy[change[i]] = player
        return copy
    }

    function newGame() {
        board = []
        for (var i = 0; i < 64; ++i)
            board.push(0)
        board[pos(3, 3)] = -1
        board[pos(4, 4)] = -1
        board[pos(3, 4)] = 1
        board[pos(4, 3)] = 1
        turn = 1
        thinking = false
        finished = false
        status = "Your turn"
        snd("start")
        boardCanvas.requestPaint()
    }

    function evaluate(source) {
        var value = (count(-1, source) - count(1, source)) * 2
        var corners = [0, 7, 56, 63]
        for (var i = 0; i < corners.length; ++i) {
            if (source[corners[i]] === -1)
                value += 45
            else if (source[corners[i]] === 1)
                value -= 45
        }
        value += (legal(-1, source).length - legal(1, source).length) * 4
        return value
    }

    function chooseAiMove() {
        var moves = legal(-1, board)
        if (moves.length === 0)
            return -1
        if (difficulty === "Easy")
            return moves[Math.floor(GameRandom.nextReal() * moves.length)]

        var bestMove = moves[0]
        var bestScore = -999999
        for (var i = 0; i < moves.length; ++i) {
            var next = applyMove(board, moves[i], -1)
            var score = evaluate(next)
            if (difficulty === "Hard") {
                var replies = legal(1, next)
                var worstReply = 999999
                if (replies.length === 0) {
                    worstReply = evaluate(next) + 8
                } else {
                    for (var j = 0; j < replies.length; ++j) {
                        var replyBoard = applyMove(next, replies[j], 1)
                        worstReply = Math.min(worstReply, evaluate(replyBoard))
                    }
                }
                score = worstReply
            }
            if (score > bestScore) {
                bestScore = score
                bestMove = moves[i]
            }
        }
        return bestMove
    }

    function makeMove(index, player) {
        var next = applyMove(board, index, player)
        if (next === null) {
            snd("bad")
            return false
        }
        board = next
        snd("place")
        boardCanvas.requestPaint()
        return true
    }

    function playerMove(index) {
        if (thinking || finished || turn !== 1)
            return
        if (!makeMove(index, 1))
            return
        advanceTurn(-1)
    }

    function advanceTurn(nextPlayer) {
        if (finished)
            return
        var me = legal(1, board)
        var ai = legal(-1, board)
        if (me.length === 0 && ai.length === 0) {
            finishGame()
            return
        }

        if (nextPlayer === -1) {
            if (ai.length === 0) {
                turn = 1
                thinking = false
                status = "AI passes — your turn"
                return
            }
            turn = -1
            thinking = true
            status = "AI thinking..."
            aiTimer.restart()
        } else {
            if (me.length === 0) {
                turn = -1
                thinking = true
                status = "No legal move — you pass"
                aiTimer.restart()
                return
            }
            turn = 1
            thinking = false
            status = "Your turn"
        }
    }

    function aiMove() {
        if (finished)
            return
        var move = chooseAiMove()
        thinking = false
        if (move >= 0)
            makeMove(move, -1)
        advanceTurn(1)
    }

    function finishGame() {
        finished = true
        thinking = false
        var white = count(1, board)
        var black = count(-1, board)
        if (white > black) {
            wins++
            Achievements.unlock("first_win")
            if (wins >= 10) Achievements.unlock("arena_veteran")
            status = "You win " + white + " — " + black
            snd("win")
        } else if (black > white) {
            losses++
            status = "AI wins " + black + " — " + white
            snd("fail")
        } else {
            draws++
            status = "Draw " + white + " — " + black
            snd("draw")
        }
        GameSave.set("wins", wins)
        GameSave.set("losses", losses)
        GameSave.set("draws", draws); GameSave.save("autosave"); GameStats.setCounter("wins",wins); GameStats.setCounter("losses",losses); GameStats.setCounter("draws",draws)
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_N) {
            newGame()
            event.accepted = true
        }
    }


    // v0.6.2 public runtime integration. The classic UI/game loop stays intact.
    function tr(key, fallback) { return GameI18n.text(key, fallback) }
    function persistState() {
        GameSave.set("wins", wins)
        GameSave.set("losses", losses)
        GameSave.set("draws", draws)
        GameSave.set("difficulty", difficulty)
        GameSave.save("autosave")
    }
    function restoreState() {
        if (GameSave.load("autosave")) {
            wins = GameSave.get("wins", wins)
            losses = GameSave.get("losses", losses)
            draws = GameSave.get("draws", draws)
            difficulty = GameSave.get("difficulty", difficulty)
        }
    }


    Connections {
        target: Lifecycle
        function onSaveRequested() { root.persistState() }
    }
    Connections {
        target: GameInput
        function onActionPressed(action, value) { if(action==="restart") newGame(); }
    }

    Component.onCompleted: {
        GameRandom.seed("reversi_arena")
        GameStats.increment("sessions")
        restoreState()
        var names = ["start", "place", "bad", "win", "fail", "draw"]
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
        height: 58
        color: panel
        border.color: bronze

        Row {
            anchors.centerIn: parent
            spacing: 18
            Text { text: "YOU  " + root.count(1, root.board); color: cream; font.pixelSize: 14; font.bold: true }
            Text { text: "AI  " + root.count(-1, root.board); color: gold; font.pixelSize: 14; font.bold: true }
            Text { text: "W " + wins + "  L " + losses + "  D " + draws; color: muted; font.pixelSize: 12 }
        }
    }

    Item {
        id: boardArea
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.margins: 10

        Canvas {
            id: boardCanvas
            anchors.centerIn: parent
            width: Math.max(8, Math.min(parent.width, parent.height - 38))
            height: width

            onPaint: {
                if (width < 8 || height < 8)
                    return
                var ctx = getContext("2d")
                ctx.reset()
                ctx.fillStyle = root.boardGreen
                ctx.fillRect(0, 0, width, height)
                var cell = Math.max(1, width / 8)
                var moves = root.turn === 1 && !root.thinking && !root.finished ? root.legal(1, root.board) : []

                ctx.strokeStyle = root.bronze
                ctx.lineWidth = 1
                for (var g = 0; g <= 8; ++g) {
                    ctx.beginPath()
                    ctx.moveTo(g * cell, 0)
                    ctx.lineTo(g * cell, height)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(0, g * cell)
                    ctx.lineTo(width, g * cell)
                    ctx.stroke()
                }

                for (var p = 0; p < 64; ++p) {
                    var value = root.board[p]
                    var row = Math.floor(p / 8)
                    var col = p % 8
                    var cx = (col + 0.5) * cell
                    var cy = (row + 0.5) * cell
                    if (value !== 0) {
                        var pieceRadius = Math.max(2, cell * 0.36)
                        ctx.fillStyle = value === 1 ? root.cream : root.panel
                        ctx.beginPath()
                        ctx.arc(cx, cy, pieceRadius, 0, Math.PI * 2)
                        ctx.fill()
                        if (value === -1) {
                            ctx.strokeStyle = root.gold
                            ctx.lineWidth = 1
                            ctx.stroke()
                        }
                    } else if (moves.indexOf(p) >= 0) {
                        ctx.fillStyle = "rgba(213,160,79,0.50)"
                        ctx.beginPath()
                        ctx.arc(cx, cy, Math.max(1.5, cell * 0.10), 0, Math.PI * 2)
                        ctx.fill()
                    }
                }
            }

            TapHandler {
                onTapped: function(point) {
                    if (boardCanvas.width < 8)
                        return
                    var cell = boardCanvas.width / 8
                    var col = Math.max(0, Math.min(7, Math.floor(point.position.x / cell)))
                    var row = Math.max(0, Math.min(7, Math.floor(point.position.y / cell)))
                    root.playerMove(row * 8 + col)
                }
            }
        }

        Text {
            anchors.top: boardCanvas.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            text: root.status
            color: root.gold
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 13
            font.bold: true
            elide: Text.ElideRight
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
            spacing: 8
            GameButton {
                width: 116
                text: "AI: " + root.difficulty
                onClicked: {
                    root.difficulty = root.difficulty === "Easy" ? "Normal" : (root.difficulty === "Normal" ? "Hard" : "Easy")
                    root.newGame()
                }
            }
            GameButton { width: 116; text: tr("new_match","NEW MATCH"); onClicked: root.newGame() }
        }
    }

    Timer { id: aiTimer; interval: 360; repeat: false; onTriggered: root.aiMove() }
}
