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
    property color red: GameTheme.color("color.danger")
    property color muted: GameTheme.color("color.textMuted")

    property var puzzleSets: {"Easy":["000078910600195308098302560859701020400853700710924800061007204280000600345000179","000678000602005340100302007059761400426850701710924806901000004000410635300206170"],"Medium":["530070912002000308090040507809701023400003700710900006061500280200000605005280070","004070012000000340008000560859760400000003700703924856901500280200410000300086000"],"Hard":["030070000000105340108040000009761000406850000003020850000537200200409600000000109","000670900000005040000002560050700003000003090700904050960000200080009035345006070"]}
    property string solutionText: "534678912672195348198342567859761423426853791713924856961537284287419635345286179"
    property var board: []
    property var given: []
    property var notes: []
    property int selected: -1
    property int mistakes: 0
    property int hints: 3
    property int seconds: 0
    property string difficulty: "Medium"
    property string status: tr("status_initial", "Select a cell")
    property bool lifecyclePaused: false
    property bool noteMode: false
    property bool done: false

    function snd(name) { GameAudio.playEffect(Qt.resolvedUrl("sfx/" + name + ".wav")) }

    function loadPuzzle() {
        var choices = puzzleSets[difficulty]
        var puzzle = choices[Math.floor(GameRandom.nextReal() * choices.length)]
        board = []
        given = []
        notes = []
        for (var i = 0; i < 81; ++i) {
            var v = Number(puzzle.charAt(i))
            board.push(v)
            given.push(v !== 0)
            notes.push("")
        }
        selected = -1
        mistakes = 0
        hints = 3
        seconds = 0
        noteMode = false
        done = false
        status = "New " + difficulty + " puzzle"
        snd("start")
        gridCanvas.requestPaint()
    }

    function solutionAt(index) { return Number(solutionText.charAt(index)) }

    function setNumber(n) {
        if (done || selected < 0 || given[selected]) {
            snd("bad")
            return
        }
        if (noteMode) {
            var s = notes[selected]
            var digit = String(n)
            var at = s.indexOf(digit)
            if (at >= 0)
                s = s.slice(0, at) + s.slice(at + 1)
            else
                s += digit
            var chars = s.split("")
            chars.sort()
            notes[selected] = chars.join("")
            notes = notes.slice()
            gridCanvas.requestPaint()
            return
        }

        if (n !== solutionAt(selected)) {
            mistakes++
            status = "Mistake " + mistakes + " / 3"
            snd("bad")
            if (mistakes >= 3)
                status = "Three mistakes — use NEW to try again"
            return
        }

        board[selected] = n
        board = board.slice()
        notes[selected] = ""
        notes = notes.slice()
        snd("place")
        checkSolved()
        gridCanvas.requestPaint()
    }

    function eraseCell() {
        if (selected >= 0 && !given[selected] && !done) {
            board[selected] = 0
            board = board.slice()
            notes[selected] = ""
            notes = notes.slice()
            gridCanvas.requestPaint()
        }
    }

    function hint() {
        if (done || hints <= 0)
            return
        var candidates = []
        for (var i = 0; i < 81; ++i) {
            if (board[i] === 0)
                candidates.push(i)
        }
        if (candidates.length === 0)
            return
        var pick = selected >= 0 && board[selected] === 0 ? selected : candidates[Math.floor(GameRandom.nextReal() * candidates.length)]
        board[pick] = solutionAt(pick)
        board = board.slice()
        notes[pick] = ""
        notes = notes.slice()
        selected = pick
        hints--
        status = "Hint used — " + hints + " left"
        snd("hint")
        checkSolved()
        gridCanvas.requestPaint()
    }

    function checkSolved() {
        for (var i = 0; i < 81; ++i) {
            if (board[i] !== solutionAt(i))
                return
        }
        done = true
        Achievements.unlock("first_solve")
        if (seconds <= 300) Achievements.unlock("speed_solver")
        status = "Solved in " + seconds + " seconds"
        snd("win")
        var key = "mods/sudoku/best/" + difficulty
        GameSave.load("autosave")
        var best = Number(GameSave.get(key, 0))
        if (best <= 0 || seconds < best)
            GameSave.set(key, seconds); GameSave.save("autosave")
    }


    // v0.6.2 public runtime integration. The classic UI/game loop stays intact.
    function tr(key, fallback) { return GameI18n.text(key, fallback) }
    function persistState() {
        GameSave.set("difficulty", difficulty)
        GameSave.set("board", board)
        GameSave.set("given", given)
        GameSave.set("notes", notes)
        GameSave.set("selected", selected)
        GameSave.set("mistakes", mistakes)
        GameSave.set("hints", hints)
        GameSave.set("seconds", seconds)
        GameSave.set("noteMode", noteMode)
        GameSave.set("done", done)
        GameSave.save("autosave")
    }
    function restoreState() {
        if (GameSave.load("autosave")) {
            difficulty = GameSave.get("difficulty", difficulty)
            board = GameSave.get("board", board)
            given = GameSave.get("given", given)
            notes = GameSave.get("notes", notes)
            selected = GameSave.get("selected", selected)
            mistakes = GameSave.get("mistakes", mistakes)
            hints = GameSave.get("hints", hints)
            seconds = GameSave.get("seconds", seconds)
            noteMode = GameSave.get("noteMode", noteMode)
            done = GameSave.get("done", done)
        }
    }


    function moveSelection(dx, dy) {
        var i = selected < 0 ? 0 : selected
        var r = Math.floor(i / 9), c = i % 9
        r = Math.max(0, Math.min(8, r + dy)); c = Math.max(0, Math.min(8, c + dx))
        selected = r * 9 + c; gridCanvas.requestPaint()
    }
    Keys.onPressed: function(event) {
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) { setNumber(event.key - Qt.Key_0); event.accepted = true }
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_A) { moveSelection(-1,0); event.accepted = true }
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) { moveSelection(1,0); event.accepted = true }
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_W) { moveSelection(0,-1); event.accepted = true }
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_S) { moveSelection(0,1); event.accepted = true }
        else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) { eraseCell(); event.accepted = true }
        else if (event.key === Qt.Key_N) { noteMode = !noteMode; event.accepted = true }
        else if (event.key === Qt.Key_H) { hint(); event.accepted = true }
    }


    Connections {
        target: Lifecycle
        function onSaveRequested() { root.persistState() }
        function onBackgrounded() { root.lifecyclePaused = true; root.persistState() }
        function onForegrounded() { root.lifecyclePaused = false }
    }
    Connections {
        target: GameInput
        function onActionPressed(action, value) { if(action==="move_left") moveSelection(-1,0); else if(action==="move_right") moveSelection(1,0); else if(action==="up") moveSelection(0,-1); else if(action==="down") moveSelection(0,1); else if(action==="hint") hint(); }
    }

    Component.onCompleted: {
        GameRandom.seed("sudoku_master")
        GameStats.increment("sessions")
        var names = ["start", "place", "bad", "hint", "win"]
        for (var i = 0; i < names.length; ++i)
            GameAudio.preload(Qt.resolvedUrl("sfx/" + names[i] + ".wav"))
        loadPuzzle(); restoreState()
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
            spacing: 13
            Text { text: difficulty; color: cream; font.pixelSize: 13; font.bold: true }
            Text { text: tr("time","TIME") + " " + seconds; color: gold; font.pixelSize: 13; font.bold: true }
            Text { text: tr("errors","ERR") + " " + mistakes + "/3"; color: mistakes >= 3 ? red : cream; font.pixelSize: 13 }
            Text { text: tr("hint","HINT") + " " + hints; color: cream; font.pixelSize: 13 }
        }
    }

    Item {
        id: gameArea
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: controls.top
        anchors.margins: 8

        Canvas {
            id: gridCanvas
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(9, Math.min(parent.width, parent.height - 34))
            height: width

            onPaint: {
                if (width < 9 || height < 9)
                    return
                var ctx = getContext("2d")
                ctx.reset()
                ctx.fillStyle = root.panel
                ctx.fillRect(0, 0, width, height)
                var cell = Math.max(1, width / 9)

                if (root.selected >= 0) {
                    var sr = Math.floor(root.selected / 9)
                    var sc = root.selected % 9
                    ctx.fillStyle = Qt.lighter(root.bronze, 1.12)
                    ctx.fillRect(sc * cell, sr * cell, cell, cell)
                }

                for (var i = 0; i < 81; ++i) {
                    var row = Math.floor(i / 9)
                    var col = i % 9
                    var value = root.board[i]
                    if (value !== 0) {
                        ctx.fillStyle = root.given[i] ? root.cream : root.gold
                        ctx.font = "bold " + Math.max(12, Math.floor(cell * 0.46)) + "px sans-serif"
                        ctx.textAlign = "center"
                        ctx.textBaseline = "middle"
                        ctx.fillText(String(value), (col + 0.5) * cell, (row + 0.52) * cell)
                    } else if (root.notes[i].length > 0) {
                        ctx.fillStyle = root.muted
                        ctx.font = Math.max(7, Math.floor(cell * 0.17)) + "px sans-serif"
                        ctx.textAlign = "center"
                        ctx.textBaseline = "middle"
                        var ns = root.notes[i]
                        for (var k = 0; k < ns.length; ++k) {
                            var digit = Number(ns.charAt(k))
                            var nr = Math.floor((digit - 1) / 3)
                            var nc = (digit - 1) % 3
                            ctx.fillText(String(digit), (col + (nc + 0.5) / 3) * cell, (row + (nr + 0.5) / 3) * cell)
                        }
                    }
                }

                for (var line = 0; line <= 9; ++line) {
                    ctx.strokeStyle = line % 3 === 0 ? root.gold : root.bronze
                    ctx.lineWidth = line % 3 === 0 ? 2 : 1
                    ctx.beginPath()
                    ctx.moveTo(line * cell, 0)
                    ctx.lineTo(line * cell, height)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(0, line * cell)
                    ctx.lineTo(width, line * cell)
                    ctx.stroke()
                }
            }

            TapHandler {
                onTapped: function(point) {
                    if (gridCanvas.width < 9)
                        return
                    var cell = gridCanvas.width / 9
                    var col = Math.max(0, Math.min(8, Math.floor(point.position.x / cell)))
                    var row = Math.max(0, Math.min(8, Math.floor(point.position.y / cell)))
                    root.selected = row * 9 + col
                    gridCanvas.requestPaint()
                }
            }
        }

        Text {
            anchors.top: gridCanvas.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            text: status
            color: mistakes >= 3 ? red : gold
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: controls
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 120
        color: panel
        border.color: bronze

        Column {
            anchors.centerIn: parent
            spacing: 6
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 3
                Repeater {
                    model: 9
                    delegate: GameButton {
                        required property int index
                        width: Math.max(30, Math.min(42, (root.width - 44) / 9))
                        height: 38
                        text: String(index + 1)
                        enabled: root.mistakes < 3 && !root.done
                        onClicked: root.setNumber(index + 1)
                    }
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                GameButton { width: 76; height: 38; text: tr("erase","ERASE"); onClicked: root.eraseCell() }
                GameButton { width: 76; height: 38; text: root.noteMode ? tr("notes_on","NOTES ON") : tr("notes","NOTES"); onClicked: root.noteMode = !root.noteMode }
                GameButton { width: 70; height: 38; text: tr("hint","HINT"); enabled: root.hints > 0; onClicked: root.hint() }
                GameButton {
                    width: 88
                    height: 38
                    text: root.difficulty
                    onClicked: {
                        root.difficulty = root.difficulty === "Easy" ? "Medium" : (root.difficulty === "Medium" ? "Hard" : "Easy")
                        root.loadPuzzle()
                    }
                }
                GameButton { width: 64; height: 38; text: "NEW"; onClicked: root.loadPuzzle() }
            }
        }
    }

    Timer { interval: 1000; repeat: true; running: !root.done && root.mistakes < 3 && !root.lifecyclePaused; onTriggered: root.seconds++ }
}
