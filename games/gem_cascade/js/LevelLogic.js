function config(level) {
    var n = Math.max(1, Number(level || 1))
    var cycle = (n - 1) % 6
    // Difficulty rises in bounded tiers instead of scaling objectives forever.
    // This prevents late campaign levels from becoming mathematically unrealistic
    // with a fixed-size 8x8 board and a limited move budget.
    var tier = Math.min(12, Math.floor((n - 1) / 3))
    var cfg = {
        moves: Math.max(19, 25 - Math.floor(tier / 2)),
        targetScore: 1100 + tier * 450,
        collectType: cycle,
        collectCount: 10 + Math.min(12, tier),
        iceLayers: n >= 3 && n % 3 === 0 ? Math.min(12, 2 + tier) : 0,
        bombTarget: 0,
        cascadeTarget: 0
    }
    if (n >= 8 && n % 8 === 0) { cfg.bombTarget = 1; cfg.moves += 2 }
    // Cascades are partially RNG-dependent, so keep this objective demanding but
    // bounded at x3 rather than requiring increasingly lucky x4/x5 chains.
    if (cfg.iceLayers > 0) cfg.moves += 2
    if (n >= 5 && n % 5 === 0) { cfg.cascadeTarget = tier >= 5 ? 3 : 2; cfg.moves += 2 }
    // When two RNG-sensitive secondary objectives coincide, give a small
    // deterministic move cushion instead of turning the level into a luck gate.
    if (cfg.iceLayers > 0 && cfg.cascadeTarget > 0) cfg.moves += 2
    return cfg
}

function starCount(score, targetScore, completed) {
    if (!completed) return 0
    if (score >= targetScore * 1.75) return 3
    if (score >= targetScore * 1.25) return 2
    return 1
}


function boosterRewards(level, stars, previousStars) {
    var n = Math.max(1, Number(level || 1))
    var currentStars = Math.max(0, Math.min(3, Number(stars || 0)))
    var oldStars = Math.max(0, Math.min(3, Number(previousStars || 0)))
    var rewards = {}
    function add(name, amount) { rewards[name] = Number(rewards[name] || 0) + amount }

    // One guaranteed tool for every newly-cleared level. Hammer is intentionally
    // the most common because it is precise rather than board-wide.
    if (oldStars < 1) {
        var rotation = ["hammer", "shuffle", "hammer", "extra", "hammer"]
        add(rotation[(n - 1) % rotation.length], 1)
    }

    // Performance reward is intentionally periodic, not every level, so 3-star
    // play matters without flooding inventory. It can be earned later by
    // improving an old level and is never repeat-farmable.
    if (oldStars < 3 && currentStars >= 3 && n % 3 === 0)
        add("shuffle", 1)

    // Cross Blast is the rarest progression gift. Only a NEW milestone clear
    // can award it, so replaying level 5/10/etc. cannot farm stock.
    if (oldStars < 1 && n % 5 === 0)
        add("cross", 1)

    return rewards
}
