var NORMAL = 0
var ROW = 1
var COLUMN = 2
var BOMB = 3
var PRISM = 4
var NOVA = 5

function idx(x, y, cols) { return y * cols + x }
function xOf(i, cols) { return i % cols }
function yOf(i, cols) { return Math.floor(i / cols) }
function adjacent(a, b, cols) { return Math.abs(xOf(a, cols) - xOf(b, cols)) + Math.abs(yOf(a, cols) - yOf(b, cols)) === 1 }
function cloneArray(v) { return v.slice() }
function hasOwn(o, k) { return Object.prototype.hasOwnProperty.call(o, k) }

function swapPair(board, specials, a, b) {
    var nb = board.slice(), ns = specials.slice(), t
    t = nb[a]; nb[a] = nb[b]; nb[b] = t
    t = ns[a]; ns[a] = ns[b]; ns[b] = t
    return { board: nb, specials: ns }
}

function findRuns(board, cols, rows) {
    var runs = [], x, y, start, g, cells
    for (y = 0; y < rows; ++y) {
        x = 0
        while (x < cols) {
            start = x; g = board[idx(x, y, cols)]
            if (g < 0) { ++x; continue }
            ++x
            while (x < cols && board[idx(x, y, cols)] === g) ++x
            if (x - start >= 3) {
                cells = []
                for (var hx = start; hx < x; ++hx) cells.push(idx(hx, y, cols))
                runs.push({ cells: cells, horizontal: true, type: g, length: cells.length })
            }
        }
    }
    for (x = 0; x < cols; ++x) {
        y = 0
        while (y < rows) {
            start = y; g = board[idx(x, y, cols)]
            if (g < 0) { ++y; continue }
            ++y
            while (y < rows && board[idx(x, y, cols)] === g) ++y
            if (y - start >= 3) {
                cells = []
                for (var vy = start; vy < y; ++vy) cells.push(idx(x, vy, cols))
                runs.push({ cells: cells, horizontal: false, type: g, length: cells.length })
            }
        }
    }
    return runs
}

function runSharesCell(a, b) {
    for (var i = 0; i < a.cells.length; ++i)
        for (var j = 0; j < b.cells.length; ++j)
            if (a.cells[i] === b.cells[j]) return true
    return false
}

function groupRuns(runs) {
    var groups = [], used = []
    for (var i = 0; i < runs.length; ++i) used.push(false)
    for (var seed = 0; seed < runs.length; ++seed) {
        if (used[seed]) continue
        var group = [runs[seed]], queue = [seed]; used[seed] = true
        while (queue.length) {
            var cur = queue.shift()
            for (var j = 0; j < runs.length; ++j) {
                if (!used[j] && runs[j].type === runs[cur].type && runSharesCell(runs[cur], runs[j])) {
                    used[j] = true; queue.push(j); group.push(runs[j])
                }
            }
        }
        groups.push(group)
    }
    return groups
}

function groupCells(group) {
    var set = {}, result = []
    for (var r = 0; r < group.length; ++r) {
        for (var i = 0; i < group[r].cells.length; ++i) {
            var p = group[r].cells[i]
            if (!hasOwn(set, p)) { set[p] = true; result.push(p) }
        }
    }
    return result
}

function chooseAnchor(cells, preferredA, preferredB) {
    for (var i = 0; i < cells.length; ++i) if (cells[i] === preferredB) return preferredB
    for (var j = 0; j < cells.length; ++j) if (cells[j] === preferredA) return preferredA
    return cells[Math.floor(cells.length / 2)]
}

function buildMatchPlan(board, specials, cols, rows, preferredA, preferredB) {
    var runs = findRuns(board, cols, rows), groups = groupRuns(runs)
    var clear = {}, create = {}, specialCreated = { line: 0, bomb: 0, prism: 0, nova: 0 }
    for (var g = 0; g < groups.length; ++g) {
        var group = groups[g], cells = groupCells(group), hasH = false, hasV = false, maxLen = 0, kind = NORMAL
        for (var r = 0; r < group.length; ++r) {
            if (group[r].horizontal) hasH = true; else hasV = true
            maxLen = Math.max(maxLen, group[r].length)
        }
        if (maxLen >= 6) kind = NOVA
        else if (maxLen >= 5) kind = PRISM
        else if (hasH && hasV) kind = BOMB
        else if (maxLen === 4) kind = hasH ? ROW : COLUMN
        for (var c = 0; c < cells.length; ++c) clear[cells[c]] = true
        if (kind !== NORMAL) {
            var anchor = chooseAnchor(cells, preferredA, preferredB)
            if (Number(specials[anchor] || 0) !== NORMAL) {
                var normalAnchor = -1
                for (var ac = 0; ac < cells.length; ++ac) {
                    if (Number(specials[cells[ac]] || 0) === NORMAL) { normalAnchor = cells[ac]; break }
                }
                anchor = normalAnchor
            }
            if (anchor >= 0) {
                delete clear[anchor]
                create[anchor] = { kind: kind, type: board[anchor] }
                if (kind === BOMB) ++specialCreated.bomb
                else if (kind === PRISM) ++specialCreated.prism
                else if (kind === NOVA) ++specialCreated.nova
                else ++specialCreated.line
            }
        }
    }
    return { clear: clear, create: create, runs: runs, specialCreated: specialCreated }
}

function addRow(clear, row, cols) { for (var x = 0; x < cols; ++x) clear[idx(x, row, cols)] = true }
function addColumn(clear, col, cols, rows) { for (var y = 0; y < rows; ++y) clear[idx(col, y, cols)] = true }
function addRadius(clear, p, radius, cols, rows) {
    var cx = xOf(p, cols), cy = yOf(p, cols)
    for (var y = Math.max(0, cy - radius); y <= Math.min(rows - 1, cy + radius); ++y)
        for (var x = Math.max(0, cx - radius); x <= Math.min(cols - 1, cx + radius); ++x)
            clear[idx(x, y, cols)] = true
}
function addDiagonals(clear, p, cols, rows) {
    var cx = xOf(p, cols), cy = yOf(p, cols), x, y
    x = cx; y = cy
    while (x >= 0 && y >= 0) { clear[idx(x, y, cols)] = true; --x; --y }
    x = cx + 1; y = cy + 1
    while (x < cols && y < rows) { clear[idx(x, y, cols)] = true; ++x; ++y }
    x = cx; y = cy
    while (x >= 0 && y < rows) { clear[idx(x, y, cols)] = true; --x; ++y }
    x = cx + 1; y = cy - 1
    while (x < cols && y >= 0) { clear[idx(x, y, cols)] = true; ++x; --y }
}

function expandSpecials(board, specials, clear, cols, rows) {
    var result = {}, triggered = {}, k
    for (k in clear) if (hasOwn(clear, k)) result[k] = true
    var changed = true, guard = 0
    while (changed && guard++ < board.length + 12) {
        changed = false
        var keys = []
        for (k in result) if (hasOwn(result, k)) keys.push(Number(k))
        for (var i = 0; i < keys.length; ++i) {
            var p = keys[i], sp = Number(specials[p] || 0)
            if (sp === NORMAL || triggered[p]) continue
            triggered[p] = true
            var before = Object.keys(result).length
            if (sp === ROW) addRow(result, yOf(p, cols), cols)
            else if (sp === COLUMN) addColumn(result, xOf(p, cols), cols, rows)
            else if (sp === BOMB) addRadius(result, p, 1, cols, rows)
            else if (sp === PRISM) {
                var type = board[p]
                for (var q = 0; q < board.length; ++q) if (board[q] === type) result[q] = true
            } else if (sp === NOVA) {
                addRow(result, yOf(p, cols), cols)
                addColumn(result, xOf(p, cols), cols, rows)
                addDiagonals(result, p, cols, rows)
                addRadius(result, p, 1, cols, rows)
            }
            if (Object.keys(result).length > before) changed = true
        }
    }
    return { clear: result, triggered: triggered }
}

function dominantColor(board, ignoreIndex) {
    var counts = {}, bestType = -1, bestCount = -1
    for (var i = 0; i < board.length; ++i) {
        if (i === ignoreIndex) continue
        var g = Number(board[i])
        if (g < 0) continue
        counts[g] = Number(counts[g] || 0) + 1
        if (counts[g] > bestCount) { bestCount = counts[g]; bestType = g }
    }
    return bestType >= 0 ? bestType : Math.max(0, Number(board[ignoreIndex] || 0))
}

function singleSpecialPlan(board, specials, p, cols, rows) {
    var sp = Number(specials[p] || 0)
    if (sp === NORMAL) return null
    var clear = {}, transformed = {}, label = "manual_special"
    clear[p] = true
    if (sp === ROW) {
        addRow(clear, yOf(p, cols), cols)
        label = "tap_line_row"
    } else if (sp === COLUMN) {
        addColumn(clear, xOf(p, cols), cols, rows)
        label = "tap_line_column"
    } else if (sp === BOMB) {
        addRadius(clear, p, 2, cols, rows)
        label = "tap_bomb"
    } else if (sp === PRISM) {
        var type = dominantColor(board, p)
        for (var q = 0; q < board.length; ++q) if (board[q] === type) clear[q] = true
        label = "tap_prism"
    } else if (sp === NOVA) {
        addRow(clear, yOf(p, cols), cols)
        addColumn(clear, xOf(p, cols), cols, rows)
        addDiagonals(clear, p, cols, rows)
        addRadius(clear, p, 1, cols, rows)
        label = "tap_nova"
    }
    return { clear: clear, transformed: transformed, create: {}, label: label, specialCreated: { line: 0, bomb: 0, prism: 0, nova: 0 } }
}

function comboPlan(board, specials, a, b, cols, rows) {
    var sa = Number(specials[a] || 0), sb = Number(specials[b] || 0)
    if (sa === NORMAL && sb === NORMAL) return null
    var clear = {}, transformed = {}, all, p, type
    clear[a] = true; clear[b] = true
    if (sa === PRISM && sb === PRISM) {
        for (p = 0; p < board.length; ++p) clear[p] = true
        return { clear: clear, transformed: transformed, label: "prism_prism" }
    }
    if (sa === PRISM || sb === PRISM) {
        var prism = sa === PRISM ? a : b, other = prism === a ? b : a, otherSpecial = Number(specials[other] || 0)
        type = board[other]
        clear[prism] = true
        for (p = 0; p < board.length; ++p) {
            if (board[p] !== type) continue
            clear[p] = true
            if (otherSpecial === ROW || otherSpecial === COLUMN) transformed[p] = ((xOf(p, cols) + yOf(p, cols)) % 2 === 0) ? ROW : COLUMN
            else if (otherSpecial === BOMB) transformed[p] = BOMB
            else if (otherSpecial === NOVA) transformed[p] = NOVA
        }
        var prismLabel = "prism_line"
        if (otherSpecial === NORMAL) prismLabel = "prism_normal"
        else if (otherSpecial === BOMB) prismLabel = "prism_bomb"
        else if (otherSpecial === NOVA) prismLabel = "prism_nova"
        return { clear: clear, transformed: transformed, label: prismLabel }
    }
    var aLine = sa === ROW || sa === COLUMN, bLine = sb === ROW || sb === COLUMN
    if (aLine && bLine) {
        addRow(clear, yOf(a, cols), cols); addColumn(clear, xOf(a, cols), cols, rows)
        addRow(clear, yOf(b, cols), cols); addColumn(clear, xOf(b, cols), cols, rows)
        return { clear: clear, transformed: transformed, label: "line_line" }
    }
    if (sa === BOMB && sb === BOMB) {
        addRadius(clear, a, 2, cols, rows); addRadius(clear, b, 2, cols, rows)
        return { clear: clear, transformed: transformed, label: "bomb_bomb" }
    }
    if ((aLine && sb === BOMB) || (bLine && sa === BOMB)) {
        var bomb = sa === BOMB ? a : b, bx = xOf(bomb, cols), by = yOf(bomb, cols)
        for (var d = -1; d <= 1; ++d) {
            if (by + d >= 0 && by + d < rows) addRow(clear, by + d, cols)
            if (bx + d >= 0 && bx + d < cols) addColumn(clear, bx + d, cols, rows)
        }
        return { clear: clear, transformed: transformed, label: "line_bomb" }
    }
    if (sa === NOVA && sb === NOVA) {
        addRow(clear, yOf(a, cols), cols); addColumn(clear, xOf(a, cols), cols, rows); addDiagonals(clear, a, cols, rows); addRadius(clear, a, 2, cols, rows)
        addRow(clear, yOf(b, cols), cols); addColumn(clear, xOf(b, cols), cols, rows); addDiagonals(clear, b, cols, rows); addRadius(clear, b, 2, cols, rows)
        return { clear: clear, transformed: transformed, label: "nova_nova" }
    }
    if ((aLine && sb === NOVA) || (bLine && sa === NOVA)) {
        var novaLine = sa === NOVA ? a : b
        addRow(clear, yOf(novaLine, cols), cols); addColumn(clear, xOf(novaLine, cols), cols, rows); addDiagonals(clear, novaLine, cols, rows)
        var cx = xOf(novaLine, cols), cy = yOf(novaLine, cols)
        if (cy - 1 >= 0) addRow(clear, cy - 1, cols)
        if (cy + 1 < rows) addRow(clear, cy + 1, cols)
        if (cx - 1 >= 0) addColumn(clear, cx - 1, cols, rows)
        if (cx + 1 < cols) addColumn(clear, cx + 1, cols, rows)
        return { clear: clear, transformed: transformed, label: "line_nova" }
    }
    if ((sa === BOMB && sb === NOVA) || (sb === BOMB && sa === NOVA)) {
        var novaBomb = sa === NOVA ? a : b
        addRadius(clear, novaBomb, 2, cols, rows)
        addDiagonals(clear, novaBomb, cols, rows)
        addRow(clear, yOf(novaBomb, cols), cols)
        addColumn(clear, xOf(novaBomb, cols), cols, rows)
        return { clear: clear, transformed: transformed, label: "bomb_nova" }
    }
    return null
}

function isLegalSwap(board, specials, a, b, cols, rows) {
    if (!adjacent(a, b, cols)) return false
    if (comboPlan(board, specials, a, b, cols, rows) !== null) return true
    if (specials[a] === PRISM || specials[b] === PRISM) return true
    var swapped = swapPair(board, specials, a, b)
    var runs = findRuns(swapped.board, cols, rows)
    for (var r = 0; r < runs.length; ++r) {
        for (var c = 0; c < runs[r].cells.length; ++c)
            if (runs[r].cells[c] === a || runs[r].cells[c] === b) return true
    }
    return false
}

function enumerateLegalMoves(board, specials, cols, rows) {
    var moves = []
    for (var i = 0; i < board.length; ++i) {
        var x = xOf(i, cols), y = yOf(i, cols)
        if (x + 1 < cols && isLegalSwap(board, specials, i, i + 1, cols, rows)) moves.push([i, i + 1])
        if (y + 1 < rows && isLegalSwap(board, specials, i, i + cols, cols, rows)) moves.push([i, i + cols])
    }
    return moves
}

function countLegalMovesLimited(board, specials, cols, rows, limit) {
    var count = 0, max = Math.max(1, Number(limit || 1))
    for (var i = 0; i < board.length; ++i) {
        var x = xOf(i, cols), y = yOf(i, cols)
        if (x + 1 < cols && isLegalSwap(board, specials, i, i + 1, cols, rows)) { if (++count >= max) return count }
        if (y + 1 < rows && isLegalSwap(board, specials, i, i + cols, cols, rows)) { if (++count >= max) return count }
    }
    return count
}

function findPossibleMove(board, specials, cols, rows) {
    var moves = enumerateLegalMoves(board, specials, cols, rows)
    return moves.length > 0 ? moves[0] : []
}

function planAfterSwap(board, specials, a, b, cols, rows) {
    if (!adjacent(a, b, cols)) return null
    var combo = comboPlan(board, specials, a, b, cols, rows)
    var swapped = swapPair(board, specials, a, b)
    if (combo !== null) return { board: swapped.board, specials: swapped.specials, plan: combo, combo: true }
    if (!isLegalSwap(board, specials, a, b, cols, rows)) return null
    return {
        board: swapped.board,
        specials: swapped.specials,
        plan: buildMatchPlan(swapped.board, swapped.specials, cols, rows, a, b),
        combo: false
    }
}

function expandedPlanStats(board, specials, plan, cols, rows, context) {
    var ns = specials.slice(), clear, k, p, objectiveHits = 0, iceHits = 0
    if (plan && plan.transformed) {
        for (k in plan.transformed) if (hasOwn(plan.transformed, k)) ns[Number(k)] = Number(plan.transformed[k])
    }
    clear = expandSpecials(board, ns, plan && plan.clear ? plan.clear : {}, cols, rows).clear
    var clearCount = 0, triggeredSpecials = 0
    for (k in clear) {
        if (!hasOwn(clear, k)) continue
        p = Number(k); ++clearCount
        if (Number(ns[p] || 0) !== NORMAL) ++triggeredSpecials
        if (context && Number(context.targetType) >= 0 && Number(board[p]) === Number(context.targetType)) ++objectiveHits
        if (context && context.ice && Number(context.ice[p] || 0) > 0) ++iceHits
    }
    var created = { line: 0, bomb: 0, prism: 0, nova: 0 }, createdCount = 0
    if (plan && plan.create) {
        for (k in plan.create) {
            if (!hasOwn(plan.create, k)) continue
            ++createdCount
            var kind = Number(plan.create[k].kind || NORMAL)
            if (kind === ROW || kind === COLUMN) ++created.line
            else if (kind === BOMB) ++created.bomb
            else if (kind === PRISM) ++created.prism
            else if (kind === NOVA) ++created.nova
        }
    }
    return {
        clear: clear,
        clearCount: clearCount,
        triggeredSpecials: triggeredSpecials,
        objectiveHits: objectiveHits,
        iceHits: iceHits,
        created: created,
        createdCount: createdCount
    }
}

function moveScore(board, specials, a, b, cols, rows, context) {
    var after = planAfterSwap(board, specials, a, b, cols, rows)
    if (!after) return -1000000000
    var stats = expandedPlanStats(after.board, after.specials, after.plan, cols, rows, context)
    var score = stats.clearCount * 24 + stats.triggeredSpecials * 34
    score += stats.created.line * 80 + stats.created.bomb * 145 + stats.created.prism * 230 + stats.created.nova * 320
    if (after.combo) score += 520
    score += stats.objectiveHits * 42 + stats.iceHits * 52

    if (context) {
        var bombNeeded = Number(context.targetBombs || 0) - Number(context.bombsCreated || 0)
        if (bombNeeded > 0) score += stats.created.bomb * 170
        var collectRemaining = Math.max(0, Number(context.targetCount || 0) - Number(context.collectedCount || 0))
        if (collectRemaining > 0) score += Math.min(collectRemaining, stats.objectiveHits) * 14
        if (Number(context.movesLeft || 99) <= 5) {
            score += stats.objectiveHits * 24 + stats.iceHits * 28
            if (after.combo) score += 90
        }
    }

    // A small centre preference keeps hints readable and usually opens more
    // crossing geometry without dominating objective/special scoring.
    var cx = (cols - 1) * 0.5, cy = (rows - 1) * 0.5
    var mx = (xOf(a, cols) + xOf(b, cols)) * 0.5, my = (yOf(a, cols) + yOf(b, cols)) * 0.5
    score += Math.max(0, 8 - Math.abs(mx - cx) - Math.abs(my - cy))
    return score
}

function activationScore(board, specials, p, cols, rows, context) {
    var plan = singleSpecialPlan(board, specials, p, cols, rows)
    if (!plan) return -1000000000
    var stats = expandedPlanStats(board, specials, plan, cols, rows, context)
    var kind = Number(specials[p] || NORMAL)
    var score = stats.clearCount * 22 + stats.triggeredSpecials * 38 + stats.objectiveHits * 42 + stats.iceHits * 52
    if (kind === ROW || kind === COLUMN) score += 55
    else if (kind === BOMB) score += 125
    else if (kind === PRISM) score += 180
    else if (kind === NOVA) score += 250
    // Prefer combining adjacent specials over consuming one manually. The
    // combo candidate will receive a much larger bonus in moveScore().
    for (var i = 0; i < board.length; ++i) {
        if (i !== p && adjacent(i, p, cols) && Number(specials[i] || NORMAL) !== NORMAL) score -= 260
    }
    return score
}

function findBestAction(board, specials, cols, rows, context) {
    var moves = enumerateLegalMoves(board, specials, cols, rows)
    var best = null, i, score
    for (i = 0; i < moves.length; ++i) {
        score = moveScore(board, specials, moves[i][0], moves[i][1], cols, rows, context)
        if (!best || score > best.score) best = { type: "swap", cells: moves[i], score: score }
    }
    for (i = 0; i < specials.length; ++i) {
        if (Number(specials[i] || NORMAL) === NORMAL) continue
        score = activationScore(board, specials, i, cols, rows, context)
        if (!best || score > best.score) best = { type: "activate", cells: [i], score: score }
    }
    return best
}

function hasPlayableAction(board, specials, cols, rows) {
    if (enumerateLegalMoves(board, specials, cols, rows).length > 0) return true
    for (var i = 0; i < specials.length; ++i) if (Number(specials[i] || NORMAL) !== NORMAL) return true
    return false
}

function colorBalance(board, gemTypes) {
    var counts = [], i, min = 1000000, max = -1
    for (i = 0; i < gemTypes; ++i) counts.push(0)
    for (i = 0; i < board.length; ++i) if (Number(board[i]) >= 0 && Number(board[i]) < gemTypes) ++counts[Number(board[i])]
    for (i = 0; i < counts.length; ++i) { min = Math.min(min, counts[i]); max = Math.max(max, counts[i]) }
    return { counts: counts, spread: max - min }
}

function boardQuality(board, specials, cols, rows, gemTypes) {
    if (findRuns(board, cols, rows).length > 0) return -1000000
    var moves = enumerateLegalMoves(board, specials, cols, rows)
    if (moves.length === 0) return -1000000
    var balance = colorBalance(board, gemTypes)
    var score = 180 - Math.abs(moves.length - 12) * 4 - balance.spread * 6
    var specialMakingMoves = 0, comboMoves = 0
    for (var i = 0; i < moves.length; ++i) {
        var a = moves[i][0], b = moves[i][1]
        if (comboPlan(board, specials, a, b, cols, rows) !== null) { ++comboMoves; continue }
        var sw = swapPair(board, specials, a, b)
        var plan = buildMatchPlan(sw.board, sw.specials, cols, rows, a, b)
        if (plan && plan.create && countKeys(plan.create) > 0) ++specialMakingMoves
    }
    score += Math.min(3, specialMakingMoves) * 18 + Math.min(2, comboMoves) * 28
    if (moves.length < 5) score -= (5 - moves.length) * 45
    if (moves.length > 24) score -= (moves.length - 24) * 3
    return score
}

function makesInitialRun(board, p, cols) {
    var x = xOf(p, cols), y = yOf(p, cols), g = board[p]
    return (x >= 2 && board[p - 1] === g && board[p - 2] === g) ||
           (y >= 2 && board[p - cols] === g && board[p - 2 * cols] === g)
}

function tryGenerateBoard(cols, rows, gemTypes, randomInt, attempts) {
    var best = null, bestScore = -1000000000
    for (var attempt = 0; attempt < attempts; ++attempt) {
        var board = []
        for (var p = 0; p < cols * rows; ++p) {
            var tries = 0, g
            do { g = randomInt(0, gemTypes - 1); board[p] = g; ++tries } while (makesInitialRun(board, p, cols) && tries < 24)
        }
        var specials = []
        for (var s = 0; s < board.length; ++s) specials.push(NORMAL)
        if (findRuns(board, cols, rows).length !== 0) continue
        var quality = boardQuality(board, specials, cols, rows, gemTypes)
        if (quality > bestScore) {
            bestScore = quality
            best = { board: board.slice(), specials: specials.slice(), quality: quality }
        }
        var moveCount = enumerateLegalMoves(board, specials, cols, rows).length
        var balance = colorBalance(board, gemTypes)
        if (quality >= 145 && moveCount >= 7 && moveCount <= 18 && balance.spread <= 6) return best
    }
    return best
}

function generateBoard(cols, rows, gemTypes, randomInt) {
    // Evaluate several playable boards instead of accepting the first legal
    // one. This keeps opening boards varied but avoids low-agency layouts with
    // only one or two useful moves or severe colour starvation.
    var generated = tryGenerateBoard(cols, rows, gemTypes, randomInt, 4)
    if (generated) return { board: generated.board, specials: generated.specials }

    var state = ((cols * 73856093) ^ (rows * 19349663) ^ (gemTypes * 83492791) ^ 0x6d2b79f5) >>> 0
    function fallbackRandom(lo, hi) {
        state = (Math.imul ? Math.imul(1664525, state) : (1664525 * state)) + 1013904223
        state = state >>> 0
        return lo + (state % (hi - lo + 1))
    }
    generated = tryGenerateBoard(cols, rows, gemTypes, fallbackRandom, 50)
    return generated ? { board: generated.board, specials: generated.specials } : null
}

function shufflePairs(board, specials, cols, rows, randomInt) {
    var pairs = [], best = null, bestScore = -1000000000
    for (var i = 0; i < board.length; ++i) pairs.push({ gem: board[i], special: specials[i] })
    for (var attempt = 0; attempt < 5; ++attempt) {
        var n = pairs.slice()
        for (var k = n.length - 1; k > 0; --k) { var j = randomInt(0, k), t = n[k]; n[k] = n[j]; n[j] = t }
        var nb = [], ns = []
        for (var p = 0; p < n.length; ++p) { nb.push(n[p].gem); ns.push(n[p].special) }
        if (findRuns(nb, cols, rows).length !== 0) continue
        // Infer the active colour domain from the shuffled board.
        var inferredTypes = 0
        for (var q = 0; q < nb.length; ++q) inferredTypes = Math.max(inferredTypes, Number(nb[q]) + 1)
        var quality = boardQuality(nb, ns, cols, rows, Math.max(1, inferredTypes))
        if (quality > bestScore) { bestScore = quality; best = { board: nb, specials: ns } }
        var moveCount = enumerateLegalMoves(nb, ns, cols, rows).length
        if (quality >= 150 && moveCount >= 6) return best
    }
    if (best) return best

    // Adversarial fallback: preserve every special kind even if an unusually
    // weak RNG cannot find a valid permutation of the exact colour multiset.
    var gemTypes = 0, specialKinds = []
    for (var r = 0; r < board.length; ++r) {
        gemTypes = Math.max(gemTypes, Number(board[r]) + 1)
        if (Number(specials[r] || 0) !== NORMAL) specialKinds.push(Number(specials[r]))
    }
    var generated = generateBoard(cols, rows, Math.max(1, gemTypes), randomInt)
    if (!generated) return null
    var slots = []
    for (var u = 0; u < generated.board.length; ++u) slots.push(u)
    for (var sk = 0; sk < specialKinds.length && slots.length > 0; ++sk) {
        var pick = randomInt(0, slots.length - 1), pos = slots[pick]
        generated.specials[pos] = specialKinds[sk]
        slots.splice(pick, 1)
    }
    return generated
}

function wouldRunAt(board, p, gem, cols, rows) {
    var cx = xOf(p, cols), cy = yOf(p, cols), count = 1, x, y
    x = cx - 1
    while (x >= 0 && Number(board[idx(x, cy, cols)]) === gem) { ++count; --x }
    x = cx + 1
    while (x < cols && Number(board[idx(x, cy, cols)]) === gem) { ++count; ++x }
    if (count >= 3) return true
    count = 1; y = cy - 1
    while (y >= 0 && Number(board[idx(cx, y, cols)]) === gem) { ++count; --y }
    y = cy + 1
    while (y < rows && Number(board[idx(cx, y, cols)]) === gem) { ++count; ++y }
    return count >= 3
}

function weightedGemChoice(board, p, counts, gemTypes, randomInt, cols, rows, options) {
    var maxCount = 0, i, weights = [], total = 0
    for (i = 0; i < gemTypes; ++i) maxCount = Math.max(maxCount, Number(counts[i] || 0))
    var average = 0
    for (i = 0; i < gemTypes; ++i) average += Number(counts[i] || 0)
    average /= Math.max(1, gemTypes)
    for (i = 0; i < gemTypes; ++i) {
        // Inverse-frequency weighting is deliberately mild. It prevents one
        // colour from vanishing for long stretches without making refill feel
        // scripted or guaranteeing objectives.
        var weight = 12 + Math.max(0, maxCount - Number(counts[i] || 0)) * 2
        if (options && Number(options.targetType) === i && Number(counts[i] || 0) < average)
            weight += 2
        // Cascades are fun, but only apply a small positive bias. They remain
        // probabilistic and can still fail to appear for several moves.
        if (wouldRunAt(board, p, i, cols, rows)) weight += 2
        weights.push(weight); total += weight
    }
    var roll = randomInt(1, Math.max(1, total)), acc = 0
    for (i = 0; i < weights.length; ++i) { acc += weights[i]; if (roll <= acc) return i }
    return gemTypes - 1
}

function fillSpawnCandidate(baseBoard, baseSpecials, spawnPositions, cols, rows, gemTypes, randomInt, options) {
    var nb = baseBoard.slice(), ns = baseSpecials.slice(), counts = [], i
    for (i = 0; i < gemTypes; ++i) counts.push(0)
    for (i = 0; i < nb.length; ++i) if (Number(nb[i]) >= 0 && Number(nb[i]) < gemTypes) ++counts[Number(nb[i])]
    // Fill from lower empty cells towards the top. That order lets each next
    // choice see more of the board that will actually exist when it lands.
    for (i = 0; i < spawnPositions.length; ++i) {
        var p = spawnPositions[i]
        var gem = weightedGemChoice(nb, p, counts, gemTypes, randomInt, cols, rows, options)
        nb[p] = gem; ns[p] = NORMAL; ++counts[gem]
    }
    return { board: nb, specials: ns }
}

function refillQuality(board, specials, cols, rows, gemTypes) {
    var runs = findRuns(board, cols, rows)
    var spread = colorBalance(board, gemTypes).spread
    if (runs.length > 0) {
        var cells = {}, r, c
        for (r = 0; r < runs.length; ++r) for (c = 0; c < runs[r].cells.length; ++c) cells[runs[r].cells[c]] = true
        var n = countKeys(cells)
        // Reward a modest cascade; penalise huge accidental auto-clears that
        // make the player's own move feel irrelevant.
        return 150 + Math.min(7, n) * 8 - Math.max(0, n - 9) * 10 - spread * 3
    }
    // Refill is a hot path. Only inspect up to five legal continuations rather
    // than running the full smart-hint scorer after every gravity step.
    var choices = countLegalMovesLimited(board, specials, cols, rows, 5)
    if (choices === 0) return -1000000 - spread * 4
    return 120 + choices * 12 - spread * 4
}

function collapseAndRefill(board, specials, cols, rows, gemTypes, randomInt, options) {
    var base = board.slice(), baseSpecials = specials.slice(), distance = [], spawned = [], spawnPositions = []
    for (var z = 0; z < board.length; ++z) { distance.push(0); spawned.push(false) }
    for (var x = 0; x < cols; ++x) {
        var writeY = rows - 1
        for (var y = rows - 1; y >= 0; --y) {
            var p = idx(x, y, cols)
            if (base[p] < 0) continue
            var dest = idx(x, writeY, cols)
            if (dest !== p) {
                base[dest] = base[p]; baseSpecials[dest] = baseSpecials[p]; distance[dest] = writeY - y
                base[p] = -1; baseSpecials[p] = NORMAL
            }
            --writeY
        }
        var spawnRank = 0
        while (writeY >= 0) {
            var sp = idx(x, writeY, cols)
            base[sp] = -1; baseSpecials[sp] = NORMAL
            distance[sp] = writeY + 1 + spawnRank; spawned[sp] = true
            spawnPositions.push(sp)
            --writeY; ++spawnRank
        }
    }
    // Two lightweight candidates are enough to reduce colour drought without
    // turning every cascade into a solver pass on low-end devices.
    var best = null, bestScore = -1000000000
    for (var attempt = 0; attempt < 2; ++attempt) {
        var candidate = fillSpawnCandidate(base, baseSpecials, spawnPositions, cols, rows, gemTypes, randomInt, options)
        var score = refillQuality(candidate.board, candidate.specials, cols, rows, gemTypes)
        if (score > bestScore) { bestScore = score; best = candidate }
    }
    if (!best) best = fillSpawnCandidate(base, baseSpecials, spawnPositions, cols, rows, gemTypes, randomInt, options)
    return { board: best.board, specials: best.specials, fallDistance: distance, spawned: spawned }
}

function countKeys(o) { var n = 0; for (var k in o) if (hasOwn(o, k)) ++n; return n }
