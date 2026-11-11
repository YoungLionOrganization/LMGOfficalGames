import QtQuick
import "components" as Components

FocusScope {
    id: root
    focus: true
    readonly property string gameId: "dungeon_delver"
    readonly property string version: "6.6.3"
    readonly property int cols: 13
    readonly property int rows: 13
    property int themeRevision: 0
    property int languageRevision: 0
    property bool initialized: false
    property bool dirty: false

    property var map: []
    property var seen: []
    property var monsters: []
    property int boardRevision: 0
    property int playerX: 1
    property int playerY: 1
    property int hp: 24
    property int maxHp: 24
    property int attack: 4
    property int armor: 0
    property int floorNo: 1
    property int coins: 0
    property int potions: 2
    property int bombs: 1
    property int keys: 0
    property int xp: 0
    property int heroLevel: 1
    property var relics: []
    property bool dead: false
    property string message: ""

    // Persistent meta-progression.
    property int soulShards: 0
    property var upgrades: ({ vitality: 0, might: 0, fortune: 0, torch: 0 })
    property int bestFloor: 1
    property int totalKills: 0
    property int bestRunCoins: 0
    property bool tutorialCompleted: false
    property bool soundEnabled: true
    property bool vibrationEnabled: true
    property int artStyle: 0

    property bool shopOpen: false
    property bool settingsOpen: false
    property bool helpOpen: false
    property bool classPickerOpen: false

    // Run-specific hero identity and active-skill state.
    property int heroClass: 0
    property int skillCooldown: 0
    property int guardTurns: 0
    property int evadeTurns: 0
    property int turnCount: 0

    property int impactCell: -1
    property real impactProgress: 1
    property real impactStrength: 0
    property color impactColor: accentColor

    readonly property bool shortLandscape: height < 520 && width > height
    readonly property bool compactLayout: width < 760 || height > width * 1.15
    readonly property bool inputReady: initialized && !dead && !shopOpen && !settingsOpen && !helpOpen && !classPickerOpen
    readonly property color bg: themeColor("color.background", "#11100e")
    readonly property color panel: themeColor("color.surfaceRaised", "#201c18")
    readonly property color floorColor: artStyle === 0 ? themeColor("color.surface", "#25201b") : (artStyle === 1 ? Qt.darker(themeColor("color.surface", "#25201b"), 1.18) : Qt.darker(themeColor("color.surface", "#25201b"), 1.06))
    readonly property color wallColor: artStyle === 0 ? themeColor("color.borderStrong", "#6d583f") : (artStyle === 1 ? Qt.darker(themeColor("color.borderStrong", "#6d583f"), 1.18) : Qt.darker(themeColor("color.primary", "#a77a39"), 1.28))
    readonly property color wallEdge: artStyle === 1 ? themeColor("color.danger", "#b44d4d") : (artStyle === 2 ? themeColor("color.info", "#5f93dc") : themeColor("color.primary", "#b78945"))
    readonly property color accentColor: themeColor("color.primary", "#b78945")
    readonly property color textColor: themeColor("color.text", "#f4efe6")
    readonly property color mutedColor: themeColor("color.textMuted", "#a69c8e")
    readonly property color dangerColor: themeColor("color.danger", "#cf5252")
    readonly property color successColor: themeColor("color.success", "#65b36b")
    readonly property color infoColor: themeColor("color.info", "#5f93dc")

    function themeColor(token, fallback) {
        var touch = themeRevision
        try {
            if (typeof GameTheme !== "undefined") {
                var v = GameTheme.color(token)
                if (v !== undefined && v !== null && String(v).length > 0) return v
            }
        } catch (e) {}
        return fallback
    }
    function tr(key, fallback) {
        var touch = languageRevision
        try {
            if (typeof GameI18n !== "undefined") {
                var v = GameI18n.text(key, fallback)
                if (v !== undefined && v !== null && String(v).length > 0) return String(v)
            }
        } catch (e) {}
        return fallback
    }
    function idx(x, y) { return y * cols + x }
    function xOf(i) { return i % cols }
    function yOf(i) { return Math.floor(i / cols) }
    function inside(x, y) { return x >= 0 && y >= 0 && x < cols && y < rows }
    function tile(x, y) { return inside(x, y) ? String(map[idx(x, y)] || "#") : "#" }
    function copy(o) { return JSON.parse(JSON.stringify(o)) }
    function randomReal() {
        try { if (typeof GameRandom !== "undefined") return Number(GameRandom.nextReal()) } catch (e) {}
        return Math.random()
    }
    function randomInt(lo, hi) { return lo + Math.floor(randomReal() * Math.max(1, hi - lo + 1)) }
    function shuffle(array) {
        for (var i = array.length - 1; i > 0; --i) {
            var j = randomInt(0, i), t = array[i]; array[i] = array[j]; array[j] = t
        }
        return array
    }
    function setMessage(key, fallback) { message = tr(key, fallback) }
    function refreshStatusMessage() {
        if(dead) message=tr("death_message","You fell on floor %1").replace("%1",floorNo)
        else if(floorNo%5===0 && bossAlive()) message=tr("boss_floor","Floor %1 - defeat the Guardian to unseal the stairs").replace("%1",floorNo)
        else message=tr("floor_start","Floor %1 - find the stairs").replace("%1",floorNo)
    }
    function className() {
        return heroClass===0 ? tr("class_sentinel","Sentinel") : (heroClass===1 ? tr("class_rogue","Rogue") : tr("class_arcanist","Arcanist"))
    }
    function classDescription(c) {
        if(c===0) return tr("class_sentinel_desc","High endurance. Shield Bash damages adjacent enemies and grants temporary guard.")
        if(c===1) return tr("class_rogue_desc","Fast striker. Shadow Strike hits a nearby enemy hard and grants brief evasion.")
        return tr("class_arcanist_desc","Area specialist. Arc Nova damages every nearby enemy at once.")
    }
    function skillName() {
        return heroClass===0 ? tr("skill_sentinel","Shield Bash") : (heroClass===1 ? tr("skill_rogue","Shadow Strike") : tr("skill_arcanist","Arc Nova"))
    }
    function skillIcon() {
        return heroClass===0 ? Qt.resolvedUrl("assets/ui/skill_sentinel.svg") : (heroClass===1 ? Qt.resolvedUrl("assets/ui/skill_rogue.svg") : Qt.resolvedUrl("assets/ui/skill_arcanist.svg"))
    }
    function heroIcon(c) {
        return c===0 ? Qt.resolvedUrl("assets/characters/hero_knight.svg") : (c===1 ? Qt.resolvedUrl("assets/characters/hero_rogue.svg") : Qt.resolvedUrl("assets/characters/hero_arcanist.svg"))
    }
    function skillButtonText() {
        return skillCooldown>0 ? skillName()+" - "+tr("cooldown_short","CD")+" "+skillCooldown : skillName()
    }
    function floorObjectiveText() {
        if(floorNo%5===0 && bossAlive()) return tr("objective_guardian","Defeat the Guardian, then reach the stairs")
        if(floorNo===1) return tr("objective_first_floor","Explore - open a chest - collect a Soul Shard - find the stairs")
        return tr("objective_floor","Explore, gather loot, and reach the stairs")
    }

    function serviceContextReady() {
        if (typeof GameSave === "undefined" || typeof GameI18n === "undefined" || typeof GameRandom === "undefined") return false
        try {
            if (GameSave.ready !== undefined && !Boolean(GameSave.ready)) return false
            if (GameSave.gameId !== undefined && String(GameSave.gameId) !== gameId) return false
            if (GameI18n.ready !== undefined && !Boolean(GameI18n.ready)) return false
            if (GameI18n.gameId !== undefined && String(GameI18n.gameId) !== gameId) return false
        } catch (e) { return false }
        return true
    }

    function playSfx(name) {
        if (!soundEnabled) return
        try {
            if (audioLoader.status === Loader.Ready && audioLoader.item) audioLoader.item.play(name)
        } catch (e) {}
    }
    function preloadAudio() {
        try { if (audioLoader.status === Loader.Ready && audioLoader.item) audioLoader.item.preloadHost() } catch (e) {}
    }
    function haptic(kind) {
        if (!vibrationEnabled) return
        try {
            if (typeof Haptics === "undefined") return
            if (kind === "heavy") Haptics.heavy()
            else if (kind === "medium") Haptics.medium()
            else Haptics.light()
        } catch (e) {}
    }
    function impact(cell, strength, color) {
        impactCell = cell
        impactStrength = Math.max(0.2, Math.min(1.5, Number(strength || 0.5)))
        impactColor = color || accentColor
        impactAnim.stop()
        impactProgress = 0
        impactAnim.start()
    }

    function carveMaze() {
        var m = [], s = []
        for (var i=0;i<cols*rows;++i) { m.push("#"); s.push(false) }
        var stack=[[1,1]]; m[idx(1,1)]="."
        while(stack.length>0) {
            var cur=stack[stack.length-1]
            var dirs=shuffle([[2,0],[-2,0],[0,2],[0,-2]])
            var moved=false
            for(var d=0;d<dirs.length;++d) {
                var nx=cur[0]+dirs[d][0], ny=cur[1]+dirs[d][1]
                if(nx>0&&ny>0&&nx<cols-1&&ny<rows-1&&m[idx(nx,ny)]==="#") {
                    m[idx(cur[0]+dirs[d][0]/2,cur[1]+dirs[d][1]/2)]="."
                    m[idx(nx,ny)]="."
                    stack.push([nx,ny]); moved=true; break
                }
            }
            if(!moved) stack.pop()
        }
        // Open a few small chambers; carving can only add connectivity.
        var rooms=Math.min(5,1+Math.floor(floorNo/3))
        for(var r=0;r<rooms;++r) {
            var cx=randomInt(2,cols-3), cy=randomInt(2,rows-3)
            for(var yy=cy-1;yy<=cy+1;++yy) for(var xx=cx-1;xx<=cx+1;++xx) m[idx(xx,yy)]="."
        }
        map=m; seen=s
    }
    function emptyCells() {
        var cells=[]
        for(var y=1;y<rows-1;++y) for(var x=1;x<cols-1;++x)
            if(tile(x,y)==="." && !(x===1&&y===1)) cells.push([x,y])
        return shuffle(cells)
    }
    function farthestCell(cells) {
        var best=-1,bestD=-1
        for(var i=0;i<cells.length;++i) { var d=cells[i][0]+cells[i][1]; if(d>bestD){bestD=d;best=i} }
        if(best<0) return null
        var p=cells[best]; cells.splice(best,1); return p
    }
    function enemyKindForFloor(n) {
        var pool=["slime","goblin"]
        if(n>=2) pool.push("bat")
        if(n>=3) pool.push("skeleton")
        if(n>=5) pool.push("cultist")
        if(n>=7) pool.push("ogre")
        if(n>=9) pool.push("wraith")
        return pool[randomInt(0,pool.length-1)]
    }
    function enemyTemplate(kind, x, y) {
        var bonus=Math.floor(floorNo*0.72)+Math.floor(heroLevel*0.35)
        var base={kind:kind,x:x,y:y,alive:true,hp:5+bonus,maxHp:5+bonus,attack:1+Math.floor(floorNo/5),xp:3,coin:3,boss:false}
        if(kind==="slime") { base.hp=4+bonus; base.maxHp=base.hp; base.attack=1+Math.floor(floorNo/7); base.xp=2; base.coin=2 }
        else if(kind==="goblin") { base.hp=6+bonus; base.maxHp=base.hp; base.xp=3; base.coin=4 }
        else if(kind==="bat") { base.hp=4+bonus; base.maxHp=base.hp; base.attack=1+Math.floor(floorNo/6); base.xp=3; base.coin=3 }
        else if(kind==="skeleton") { base.hp=8+bonus; base.maxHp=base.hp; base.attack=2+Math.floor(floorNo/6); base.xp=5; base.coin=5 }
        else if(kind==="cultist") { base.hp=7+bonus; base.maxHp=base.hp; base.attack=2+Math.floor(floorNo/5); base.xp=6; base.coin=6 }
        else if(kind==="ogre") { base.hp=13+bonus*2; base.maxHp=base.hp; base.attack=3+Math.floor(floorNo/5); base.xp=8; base.coin=8 }
        else if(kind==="wraith") { base.hp=10+bonus; base.maxHp=base.hp; base.attack=3+Math.floor(floorNo/5); base.xp=9; base.coin=8 }
        return base
    }
    function guardianTemplate(x,y) {
        var hpValue=22+floorNo*3+heroLevel*2
        return {kind:"guardian",x:x,y:y,alive:true,hp:hpValue,maxHp:hpValue,attack:3+Math.floor(floorNo/5),xp:20+floorNo,coin:18+floorNo*2,boss:true}
    }
    function placeNearStart(cells, symbol, maxDistance) {
        var best=-1,bestD=999
        for(var i=0;i<cells.length;++i){
            var d=Math.abs(cells[i][0]-1)+Math.abs(cells[i][1]-1)
            if(d>=2&&d<=maxDistance&&d<bestD){best=i;bestD=d}
        }
        if(best<0){placeTile(cells,symbol,1);return}
        var p=cells[best];cells.splice(best,1);map[idx(p[0],p[1])]=symbol
    }
    function placeTile(cells, symbol, count) {
        for(var i=0;i<count&&cells.length>0;++i){ var p=cells.pop(); map[idx(p[0],p[1])]=symbol }
    }
    function makeFloor() {
        carveMaze(); playerX=1; playerY=1; monsters=[]
        var cells=emptyCells()
        var stairs=farthestCell(cells); if(stairs) map[idx(stairs[0],stairs[1])]=">"
        var enemyCount=Math.min(17,4+floorNo+Math.floor(floorNo/3))
        for(var i=0;i<enemyCount&&cells.length>0;++i){ var p=cells.pop(); monsters.push(enemyTemplate(enemyKindForFloor(floorNo),p[0],p[1])) }
        if(floorNo%5===0 && cells.length>0){ var bp=farthestCell(cells); if(bp) monsters.push(guardianTemplate(bp[0],bp[1])) }
        if(floorNo===1){
            // Make the expanded game visible immediately rather than hiding it behind later floors.
            placeNearStart(cells,"$",3)
            placeNearStart(cells,"*",4)
            placeNearStart(cells,"K",4)
            placeNearStart(cells,"C",5)
            placeNearStart(cells,"S",5)
            placeNearStart(cells,"B",5)
            placeNearStart(cells,"R",6)
            placeTile(cells,"$",2)
            placeTile(cells,"!",1)
        }else{
            placeTile(cells,"$",Math.min(6,3+Math.floor(floorNo/3)))
            placeTile(cells,"!",1+(floorNo%3===0?1:0))
            placeTile(cells,"K",Math.min(2,1+Math.floor(floorNo/8)))
            placeTile(cells,"C",Math.min(2,1+Math.floor(floorNo/6)))
            placeTile(cells,"^",Math.min(4,Math.floor(floorNo/2)))
            placeTile(cells,"S",1)
            placeTile(cells,"B",1)
            if(floorNo%2===0)placeTile(cells,"R",1)
            placeTile(cells,"*",1)
        }
        revealAround(); boardRevision++
        message=tr("floor_start","Floor %1 - find the stairs").replace("%1",floorNo)
        if(floorNo%5===0) message=tr("boss_floor","Floor %1 - defeat the Guardian to unseal the stairs").replace("%1",floorNo)
        if(!classPickerOpen){
            playSfx(floorNo===1?"start":(floorNo%5===0?"boss_roar":"stairs"))
            haptic(floorNo%5===0?"heavy":"light")
        }
        markDirty(true)
    }
    function hasRelic(name) { for(var i=0;i<relics.length;++i) if(String(relics[i])===name)return true; return false }
    function visionRadius() { return 4 + Math.min(3,Number(upgrades.torch||0)) + (hasRelic("lantern")?1:0) }
    function revealAround() {
        var a=seen.slice(), r=visionRadius()
        for(var y=playerY-r;y<=playerY+r;++y) for(var x=playerX-r;x<=playerX+r;++x)
            if(inside(x,y) && Math.abs(x-playerX)+Math.abs(y-playerY)<=r+1) a[idx(x,y)]=true
        seen=a; boardRevision++
    }
    function isCellVisible(i) { var t=boardRevision; var x=xOf(i),y=yOf(i); return Boolean(seen[i]) || Math.abs(x-playerX)+Math.abs(y-playerY)<=visionRadius()+1 }
    function enemyAt(x,y) { for(var i=0;i<monsters.length;++i) if(monsters[i].alive&&monsters[i].x===x&&monsters[i].y===y) return i; return -1 }
    function enemyKindAtIndex(i) { var t=boardRevision,x=xOf(i),y=yOf(i),m=enemyAt(x,y); return m>=0?String(monsters[m].kind):"" }
    function enemyHpAtIndex(i) { var t=boardRevision,x=xOf(i),y=yOf(i),m=enemyAt(x,y); return m>=0?Math.max(0,Number(monsters[m].hp)/Math.max(1,Number(monsters[m].maxHp))):0 }
    function bossAlive() { for(var i=0;i<monsters.length;++i) if(monsters[i].alive&&monsters[i].boss) return true; return false }
    function walkableForMonster(x,y,moving) {
        if(tile(x,y)==="#"||(x===playerX&&y===playerY)) return false
        for(var i=0;i<monsters.length;++i) if(i!==moving&&monsters[i].alive&&monsters[i].x===x&&monsters[i].y===y) return false
        return true
    }

    function gainXp(amount) {
        xp+=amount
        var leveled=false
        while(xp>=heroLevel*10){ xp-=heroLevel*10; heroLevel++; attack++; maxHp+=4; hp=maxHp; leveled=true }
        if(leveled){ message=tr("level_up","Level up! Attack and HP increased"); playSfx("level"); haptic("heavy"); impact(idx(playerX,playerY),0.65,successColor) }
    }
    function killMonster(index) {
        var m=monsters[index]; if(!m.alive) return
        m.alive=false; totalKills++; coins+=Number(m.coin||0)+Math.floor(Number(upgrades.fortune||0)/2)+(hasRelic("gilded")?2:0); gainXp(Number(m.xp||0)); if(hasRelic("bloodstone"))hp=Math.min(maxHp,hp+2)
        if(m.boss){ soulShards+=3+Math.floor(floorNo/5); message=tr("boss_defeated","Guardian defeated - the stairs are unsealed"); playSfx("boss_die"); haptic("heavy"); impact(idx(m.x,m.y),1.35,dangerColor) }
        else { message=tr("enemy_defeated","Enemy defeated"); playSfx("enemy_die"); haptic("medium"); impact(idx(m.x,m.y),0.8,dangerColor) }
        try { if(typeof Achievements!=="undefined") Achievements.unlock(totalKills===1?"first_monster":"dungeon_hunter") } catch(e){}
        bestRunCoins=Math.max(bestRunCoins,coins)
    }
    function damagePlayer(amount, sourceCell) {
        if(heroClass===1 && evadeTurns>0 && randomReal()<0.45){
            message=tr("evaded","You evade the attack");playSfx("step");haptic("light");impact(idx(playerX,playerY),0.28,infoColor);return
        }
        var effectiveArmor=armor+(guardTurns>0?2:0)
        var dmg=Math.max(1,Number(amount)-effectiveArmor)
        hp=Math.max(0,hp-dmg); message=tr("hurt_message","You take %1 damage").replace("%1",dmg)
        playSfx("hurt"); haptic(dmg>=4?"heavy":"medium"); impact(sourceCell>=0?sourceCell:idx(playerX,playerY),Math.min(1.2,0.4+dmg*0.12),dangerColor)
        if(hp<=0){ dead=true; message=tr("death_message","You fell on floor %1").replace("%1",floorNo); playSfx("fail"); haptic("heavy"); bestFloor=Math.max(bestFloor,floorNo); markDirty(true) }
    }
    function monsterTurn() {
        if(dead) return
        for(var i=0;i<monsters.length;++i){
            var m=monsters[i]; if(!m.alive) continue
            var dx=playerX-m.x,dy=playerY-m.y,dist=Math.abs(dx)+Math.abs(dy)
            if(m.kind==="cultist" && dist<=3 && (dx===0||dy===0) && randomReal()<0.65){ damagePlayer(m.attack,idx(m.x,m.y)); if(dead) break; continue }
            if(dist===1){ damagePlayer(m.attack,idx(m.x,m.y)); if(dead) break; continue }
            var chance=m.kind==="bat"?0.93:(m.kind==="slime"?0.58:(m.boss?0.92:0.76))
            if(dist<=8&&randomReal()<chance){
                var dirs=shuffle([[1,0],[-1,0],[0,1],[0,-1]])
                dirs.sort(function(a,b){
                    var da=Math.abs(playerX-(m.x+a[0]))+Math.abs(playerY-(m.y+a[1]))
                    var db=Math.abs(playerX-(m.x+b[0]))+Math.abs(playerY-(m.y+b[1]))
                    return da-db
                })
                for(var c=0;c<dirs.length;++c){
                    var mx=m.x+dirs[c][0],my=m.y+dirs[c][1]
                    if(walkableForMonster(mx,my,i)){m.x=mx;m.y=my;break}
                }
            }
        }
        monsters=monsters.slice(); boardRevision++
    }
    function finishTurn() {
        if(dead) return
        monsterTurn()
        if(skillCooldown>0) skillCooldown--
        if(guardTurns>0) guardTurns--
        if(evadeTurns>0) evadeTurns--
        turnCount++
        markDirty(false)
    }
    function nearestEnemy(maxDist) {
        var best=-1,bestD=9999
        for(var i=0;i<monsters.length;++i){
            var m=monsters[i];if(!m.alive)continue
            var d=Math.abs(m.x-playerX)+Math.abs(m.y-playerY)
            if(d<=maxDist&&d<bestD){best=i;bestD=d}
        }
        return best
    }
    function useClassSkill() {
        if(!inputReady||skillCooldown>0)return
        var center=idx(playerX,playerY),hitAny=false
        if(heroClass===0){
            guardTurns=3
            for(var i=0;i<monsters.length;++i){var m=monsters[i];if(!m.alive)continue;var d=Math.abs(m.x-playerX)+Math.abs(m.y-playerY);if(d===1){m.hp-=attack+3;hitAny=true;if(m.hp<=0)killMonster(i)}}
            monsters=monsters.slice();boardRevision++;skillCooldown=Math.max(2,6-(hasRelic("quickglass")?1:0))
            message=hitAny?tr("skill_guard_hit","Shield Bash strikes nearby enemies and raises your guard"):tr("skill_guard_ready","Guard raised for incoming attacks")
            playSfx("skill_guard");haptic("heavy");impact(center,0.95,accentColor)
        }else if(heroClass===1){
            var target=nearestEnemy(3);evadeTurns=2;skillCooldown=Math.max(2,5-(hasRelic("quickglass")?1:0))
            if(target>=0){var r=monsters[target];r.hp-=attack*2+2;hitAny=true;if(r.hp<=0)killMonster(target);monsters=monsters.slice();boardRevision++;message=tr("skill_rogue_hit","Shadow Strike hits for %1").replace("%1",attack*2+2);impact(idx(r.x,r.y),0.9,infoColor)}
            else message=tr("skill_rogue_evade","No target nearby - evasion increased")
            playSfx("skill_rogue");haptic("medium")
        }else{
            var damage=attack+4,count=0
            for(var a=0;a<monsters.length;++a){var e=monsters[a];if(!e.alive)continue;var dist=Math.abs(e.x-playerX)+Math.abs(e.y-playerY);if(dist<=3){e.hp-=damage;count++;if(e.hp<=0)killMonster(a)}}
            monsters=monsters.slice();boardRevision++;skillCooldown=Math.max(2,7-(hasRelic("quickglass")?1:0))
            message=tr("skill_arcane_hit","Arc Nova hits %1 enemies").replace("%1",count)
            playSfx("skill_arcane");haptic(count>=3?"heavy":"medium");impact(center,1.08,infoColor)
        }
        finishTurn()
    }

    function relicName(r) {
        if(r==="blade") return tr("relic_blade","Delver Blade")
        if(r==="charm") return tr("relic_charm","Vital Charm")
        if(r==="ward") return tr("relic_ward","Stone Ward")
        if(r==="lantern") return tr("relic_lantern","Moon Lantern")
        if(r==="bloodstone") return tr("relic_bloodstone","Bloodstone")
        if(r==="blastcore") return tr("relic_blastcore","Blast Core")
        if(r==="quickglass") return tr("relic_quickglass","Quickglass")
        return tr("relic_gilded","Gilded Token")
    }
    function relicFound() {
        var available=["blade","charm","ward","lantern","bloodstone","blastcore","quickglass","gilded"]
        var r=available[randomInt(0,available.length-1)]; relics=relics.concat([r])
        if(r==="blade") attack+=2
        else if(r==="charm"){ maxHp+=6; hp=Math.min(maxHp,hp+6) }
        else if(r==="ward") armor+=1
        else if(r==="lantern") revealAround()
        message=tr("relic_found","Relic found: %1").replace("%1",relicName(r))
        playSfx("relic"); haptic("medium"); impact(idx(playerX,playerY),0.75,infoColor)
    }
    function processTile() {
        var p=idx(playerX,playerY),t=String(map[p])
        if(t==="!"){ potions++;map[p]=".";message=tr("potion_found","Potion found");playSfx("potion");haptic("light");impact(p,0.28,successColor) }
        else if(t==="$" ){ var reward=4+floorNo+Number(upgrades.fortune||0)+(hasRelic("gilded")?2:0);coins+=reward;map[p]=".";message=tr("coins_found","+%1 coins").replace("%1",reward);playSfx("coin");haptic("light");impact(p,0.24,accentColor);bestRunCoins=Math.max(bestRunCoins,coins) }
        else if(t==="K"){ keys++;map[p]=".";message=tr("key_found","Key found");playSfx("key");haptic("light");impact(p,0.24,textColor) }
        else if(t==="B"){ bombs++;map[p]=".";message=tr("bomb_found","Bomb found");playSfx("chest");haptic("light");impact(p,0.28,dangerColor) }
        else if(t==="*"){ soulShards++;map[p]=".";message=tr("shard_found","Soul Shard found");playSfx("shard");haptic("medium");impact(p,0.55,infoColor) }
        else if(t==="R"){ map[p]=".";relicFound() }
        else if(t==="S"){ var heal=Math.min(maxHp-hp,8+heroLevel*2);hp+=heal;map[p]=".";message=tr("shrine_used","Shrine restores %1 HP").replace("%1",heal);playSfx("shrine");haptic("medium");impact(p,0.55,successColor) }
        else if(t==="^"){ map[p]=".";playSfx("trap");damagePlayer(2+Math.floor(floorNo/3),p) }
        else if(t==="C"){
            if(keys<=0){ message=tr("chest_locked","Locked chest - you need a key");playSfx("wall") }
            else { keys--;map[p]=".";var loot=8+floorNo*2+Number(upgrades.fortune||0)*2+(hasRelic("gilded")?4:0);coins+=loot;if(randomReal()<0.45)potions++;if(randomReal()<0.35)bombs++;message=tr("chest_opened","Chest opened: +%1 coins").replace("%1",loot);playSfx("chest");haptic("medium");impact(p,0.65,accentColor);bestRunCoins=Math.max(bestRunCoins,coins) }
        }
        else if(t===">"){
            if(bossAlive()){ message=tr("stairs_sealed","The Guardian seals the stairs");playSfx("wall");return false }
            floorNo++;bestFloor=Math.max(bestFloor,floorNo);coins+=3+Math.floor(floorNo/2);if(floorNo%3===0)soulShards++;makeFloor();return true
        }
        boardRevision++
        return false
    }
    function move(dx,dy) {
        if(!inputReady) return
        var nx=playerX+dx,ny=playerY+dy
        if(tile(nx,ny)==="#"){ message=tr("wall_block","A wall blocks the way");playSfx("wall");haptic("light");impact(idx(playerX,playerY),0.22,wallEdge);return }
        var mi=enemyAt(nx,ny)
        if(mi>=0){
            var m=monsters[mi];playSfx("swing");m.hp-=attack;message=tr("strike_message","You strike for %1").replace("%1",attack);playSfx("hit");haptic("medium");impact(idx(nx,ny),0.65,dangerColor)
            if(m.hp<=0){ killMonster(mi);playerX=nx;playerY=ny;revealAround();processTile() }
            monsters=monsters.slice();boardRevision++;if(!dead)finishTurn();return
        }
        playerX=nx;playerY=ny;playSfx("step");revealAround();var changedFloor=processTile();if(changedFloor)return
        if(!dead)finishTurn()
    }
    function drinkPotion() {
        if(!inputReady||potions<=0||hp>=maxHp)return
        potions--;var amount=Math.min(maxHp-hp,8+heroLevel*2);hp+=amount;message=tr("potion_used","Recovered %1 HP").replace("%1",amount);playSfx("potion");haptic("medium");impact(idx(playerX,playerY),0.45,successColor);finishTurn()
    }
    function useBomb() {
        if(!inputReady||bombs<=0)return
        bombs--;var center=idx(playerX,playerY);var killed=0
        for(var i=0;i<monsters.length;++i){var m=monsters[i];if(!m.alive)continue;var d=Math.abs(m.x-playerX)+Math.abs(m.y-playerY);if(d<=2){m.hp-=8+heroLevel*2+(hasRelic("blastcore")?5:0);if(m.hp<=0){killMonster(i);killed++}}}
        monsters=monsters.slice();boardRevision++;message=killed>0?tr("bomb_kills","Bomb defeated %1 enemies").replace("%1",killed):tr("bomb_used","Bomb detonated");playSfx("bomb");haptic("heavy");impact(center,1.25,dangerColor);finishTurn()
    }

    function supplyCost(kind) {
        if(kind==="potion") return 10+floorNo*2
        if(kind==="bomb") return 14+floorNo*2
        if(kind==="key") return 8+floorNo
        return 0
    }
    function buySupply(kind) {
        if(dead)return
        var cost=supplyCost(kind);if(coins<cost)return
        coins-=cost;if(kind==="potion")potions++;else if(kind==="bomb")bombs++;else if(kind==="key")keys++
        message=tr("purchase_complete","Purchase complete");playSfx("buy");haptic("light");markDirty(true)
    }
    function upgradeCost(kind) { return 8 + Number(upgrades[kind]||0)*7 }
    function buyUpgrade(kind) {
        var cost=upgradeCost(kind);if(soulShards<cost)return
        var u=copy(upgrades);soulShards-=cost;u[kind]=Number(u[kind]||0)+1;upgrades=u
        if(kind==="vitality"){maxHp+=4;hp+=4}else if(kind==="might")attack++
        else if(kind==="torch")revealAround()
        message=tr("legacy_upgraded","Legacy upgraded");playSfx("upgrade");haptic("medium");impact(idx(playerX,playerY),0.65,infoColor);markDirty(true)
    }
    function styleName() { return artStyle===0?tr("style_keep","Iron Keep"):(artStyle===1?tr("style_crypt","Ember Crypt"):tr("style_arcane","Moon Ruins")) }
    function cycleStyle() { artStyle=(artStyle+1)%3;boardRevision++;playSfx("button");markDirty(true) }
    function toggleSound() { soundEnabled=!soundEnabled;if(audioLoader.status===Loader.Ready&&audioLoader.item)audioLoader.item.enabled=soundEnabled;markDirty(true);if(soundEnabled)playSfx("button") }
    function toggleVibration() { vibrationEnabled=!vibrationEnabled;if(vibrationEnabled)haptic("medium");markDirty(true) }

    function applyNewRunStats() {
        maxHp=24+Number(upgrades.vitality||0)*4;attack=4+Number(upgrades.might||0);armor=0
        if(heroClass===0){maxHp+=6;armor=1}
        else if(heroClass===1){maxHp=Math.max(18,maxHp-2);attack+=1}
        else {maxHp+=1}
        hp=maxHp;floorNo=1;coins=0;potions=heroClass===2?3:2;bombs=heroClass===1?2:1;keys=0;xp=0;heroLevel=1;relics=[];dead=false
        skillCooldown=0;guardTurns=0;evadeTurns=0;turnCount=0
    }
    function requestNewRun() { shopOpen=false;settingsOpen=false;helpOpen=false;classPickerOpen=true;playSfx("button") }
    function startNewRunAs(c) {
        heroClass=Math.max(0,Math.min(2,Number(c||0)));classPickerOpen=false;applyNewRunStats();makeFloor();forceActiveFocus()
        if(!tutorialCompleted && !classPickerOpen)helpOpen=true
    }
    function newRun() { requestNewRun() }

    function campaignSnapshot() {
        return {soulShards:soulShards,upgrades:upgrades,bestFloor:bestFloor,totalKills:totalKills,bestRunCoins:bestRunCoins,tutorialCompleted:tutorialCompleted,soundEnabled:soundEnabled,vibrationEnabled:vibrationEnabled,artStyle:artStyle}
    }
    function runSnapshot() {
        return {map:map,seen:seen,monsters:monsters,playerX:playerX,playerY:playerY,hp:hp,maxHp:maxHp,attack:attack,armor:armor,floorNo:floorNo,coins:coins,potions:potions,bombs:bombs,keys:keys,xp:xp,heroLevel:heroLevel,relics:relics,dead:dead,heroClass:heroClass,skillCooldown:skillCooldown,guardTurns:guardTurns,evadeTurns:evadeTurns,turnCount:turnCount}
    }
    function snapshotForSave() { return {schema:2,version:version,campaign:campaignSnapshot(),run:runSnapshot()} }
    function markDirty(immediate) { if(!initialized||classPickerOpen)return;dirty=true;if(immediate)forceSave();else saveTimer.restart() }
    function forceSave() {
        if(!initialized||!dirty||!serviceContextReady())return
        try { GameSave.set("snapshotJson",JSON.stringify(snapshotForSave()));GameSave.set("schema",2);GameSave.save("autosave");dirty=false } catch(e){ console.warn("Dungeon Delver save failed:",e) }
    }
    function sanitizeRestoredRun() {
        if(!map||map.length!==cols*rows||!seen||seen.length!==cols*rows||!monsters)return false
        var allowed={"#":true,".":true,">":true,"!":true,"$":true,"C":true,"K":true,"S":true,"^":true,"*":true,"R":true,"B":true}
        var stairs=0
        for(var i=0;i<map.length;++i){var v=String(map[i]);if(!allowed[v])return false;if(v===">")stairs++}
        if(stairs!==1||!inside(playerX,playerY)||tile(playerX,playerY)==="#")return false
        var occupied={}
        for(var m=0;m<monsters.length;++m){
            var e=monsters[m];if(!e||typeof e!=="object")return false
            e.x=Number(e.x);e.y=Number(e.y);e.hp=Number(e.hp);e.maxHp=Math.max(1,Math.min(5000,Number(e.maxHp||1)));e.attack=Math.max(1,Math.min(500,Number(e.attack||1)));e.alive=Boolean(e.alive)
            if(!inside(e.x,e.y)||tile(e.x,e.y)==="#"||!isFinite(e.hp)||!isFinite(e.maxHp))return false
            if(e.hp<=0)e.alive=false;else e.hp=Math.min(e.maxHp,e.hp)
            var pos=idx(e.x,e.y);if(e.alive&&occupied[pos])return false;if(e.alive)occupied[pos]=true
            if(e.alive&&e.x===playerX&&e.y===playerY)return false
            if(["slime","goblin","skeleton","bat","cultist","ogre","wraith","guardian"].indexOf(String(e.kind))<0)return false
        }
        maxHp=Math.max(1,Math.min(5000,Number(maxHp||24)));hp=Math.max(0,Math.min(maxHp,Number(hp||0)));attack=Math.max(1,Math.min(500,Number(attack||4)));armor=Math.max(0,Math.min(100,Number(armor||0)));floorNo=Math.max(1,Math.min(9999,Number(floorNo||1)));coins=Math.max(0,Math.min(999999999,Number(coins||0)));potions=Math.max(0,Math.min(9999,Number(potions||0)));bombs=Math.max(0,Math.min(9999,Number(bombs||0)));keys=Math.max(0,Math.min(9999,Number(keys||0)));heroLevel=Math.max(1,Math.min(9999,Number(heroLevel||1)));xp=Math.max(0,Math.min(999999999,Number(xp||0)));dead=dead||hp<=0
        var validRelics={blade:true,charm:true,ward:true,lantern:true,bloodstone:true,blastcore:true,quickglass:true,gilded:true},cleanRelics=[]
        for(var rr=0;rr<relics.length&&cleanRelics.length<128;++rr)if(validRelics[String(relics[rr])])cleanRelics.push(String(relics[rr]))
        relics=cleanRelics
        var u=copy(upgrades||{});u.vitality=Math.max(0,Number(u.vitality||0));u.might=Math.max(0,Number(u.might||0));u.fortune=Math.max(0,Number(u.fortune||0));u.torch=Math.max(0,Number(u.torch||0));upgrades=u
        artStyle=Math.max(0,Math.min(2,Number(artStyle||0)));heroClass=Math.max(0,Math.min(2,Number(heroClass||0)));skillCooldown=Math.max(0,Math.min(99,Number(skillCooldown||0)));guardTurns=Math.max(0,Math.min(9,Number(guardTurns||0)));evadeTurns=Math.max(0,Math.min(9,Number(evadeTurns||0)));turnCount=Math.max(0,Number(turnCount||0));boardRevision++;return true
    }
    function restoreSnapshot(payload) {
        if(!payload||Number(payload.schema||0)<2||!payload.campaign)return false
        var c=payload.campaign
        soulShards=Math.max(0,Number(c.soulShards||0));upgrades=c.upgrades||{vitality:0,might:0,fortune:0,torch:0};bestFloor=Math.max(1,Number(c.bestFloor||1));totalKills=Math.max(0,Number(c.totalKills||0));bestRunCoins=Math.max(0,Number(c.bestRunCoins||0));tutorialCompleted=Boolean(c.tutorialCompleted);soundEnabled=c.soundEnabled===undefined?true:Boolean(c.soundEnabled);vibrationEnabled=c.vibrationEnabled===undefined?true:Boolean(c.vibrationEnabled);artStyle=Math.max(0,Math.min(2,Number(c.artStyle||0)))
        var r=payload.run;if(!r||!r.map||r.map.length!==cols*rows||!r.seen||r.seen.length!==cols*rows||!r.monsters)return false
        map=r.map.slice();seen=r.seen.slice();monsters=copy(r.monsters);playerX=Number(r.playerX||1);playerY=Number(r.playerY||1);hp=Number(r.hp||1);maxHp=Number(r.maxHp||24);attack=Number(r.attack||4);armor=Number(r.armor||0);floorNo=Math.max(1,Number(r.floorNo||1));coins=Math.max(0,Number(r.coins||0));potions=Math.max(0,Number(r.potions||0));bombs=Math.max(0,Number(r.bombs||0));keys=Math.max(0,Number(r.keys||0));xp=Math.max(0,Number(r.xp||0));heroLevel=Math.max(1,Number(r.heroLevel||1));relics=r.relics||[];dead=Boolean(r.dead);heroClass=Math.max(0,Math.min(2,Number(r.heroClass||0)));skillCooldown=Math.max(0,Number(r.skillCooldown||0));guardTurns=Math.max(0,Number(r.guardTurns||0));evadeTurns=Math.max(0,Number(r.evadeTurns||0));turnCount=Math.max(0,Number(r.turnCount||0))
        return sanitizeRestoredRun()
    }
    function migrateLegacy() {
        try {
            if(!GameSave.load("autosave"))return false
            var oldFloor=Number(GameSave.get("floorNo",0));if(oldFloor<=0)return false
            soulShards=Math.max(0,Math.floor(oldFloor/3));bestFloor=Math.max(1,oldFloor);upgrades={vitality:0,might:0,fortune:0,torch:0};heroClass=0;applyNewRunStats();floorNo=Math.max(1,oldFloor);coins=Math.max(0,Number(GameSave.get("coins",0)));potions=Math.max(0,Number(GameSave.get("potions",2)));xp=Math.max(0,Number(GameSave.get("xp",0)));heroLevel=Math.max(1,Number(GameSave.get("heroLevel",1)));attack=Math.max(4,Number(GameSave.get("attack",attack)));maxHp=Math.max(24,Number(GameSave.get("maxHp",maxHp)));hp=maxHp;makeFloor();return true
        } catch(e){return false}
    }
    function loadGame() {
        var restored=false
        try { if(GameSave.load("autosave")){var json=String(GameSave.get("snapshotJson",""));if(json.length>0)restored=restoreSnapshot(JSON.parse(json))} } catch(e){console.warn("Dungeon Delver load failed:",e)}
        if(!restored)restored=migrateLegacy()
        if(!restored){heroClass=0;classPickerOpen=true;applyNewRunStats();makeFloor();dirty=false}
        else refreshStatusMessage()
        dirty=false
    }
    function initializeGame() {
        if(initialized||!serviceContextReady())return
        initialized=true
        try{GameRandom.seed("dungeon_delver_v66")}catch(e){}
        preloadAudio();loadGame();forceActiveFocus();try{if(typeof GameStats!=="undefined")GameStats.increment("sessions")}catch(e2){}
        if(!tutorialCompleted && !classPickerOpen)helpOpen=true
    }

    // Physical-key fallback keeps QWERTY gameplay positions stable when the
    // active keyboard layout changes (for example Azerbaijani W -> U-diaeresis).
    // QML KeyEvent.nativeScanCode is layout-independent at the native level.
    function physicalKey(event, name) {
        var sc = Number(event.nativeScanCode || 0)
        var os = Qt.platform.os
        var winEvdev = {w:17,a:30,s:31,d:32,e:18,f:33,h:35,b:48,space:57}
        var x11 = {w:25,a:38,s:39,d:40,e:26,f:41,h:43,b:56,space:65}
        var mac = {w:13,a:0,s:1,d:2,e:14,f:3,h:4,b:11,space:49}
        if (os === "windows") return sc === Number(winEvdev[name])
        if (os === "osx" || os === "macos") return sc === Number(mac[name])
        if (sc <= 0) return false
        if (os === "linux") return sc === Number(winEvdev[name]) || sc === Number(x11[name])
        return false
    }
    function keyMatches(event, logicalKey, physicalName) {
        return event.key === logicalKey || (physicalName && physicalKey(event, physicalName))
    }

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
        if(event.key===Qt.Key_Left||keyMatches(event,Qt.Key_A,"a")){move(-1,0);event.accepted=true}
        else if(event.key===Qt.Key_Right||keyMatches(event,Qt.Key_D,"d")){move(1,0);event.accepted=true}
        else if(event.key===Qt.Key_Up||keyMatches(event,Qt.Key_W,"w")){move(0,-1);event.accepted=true}
        else if(event.key===Qt.Key_Down||keyMatches(event,Qt.Key_S,"s")){move(0,1);event.accepted=true}
        else if(keyMatches(event,Qt.Key_H,"h")){drinkPotion();event.accepted=true}
        else if(keyMatches(event,Qt.Key_B,"b")){useBomb();event.accepted=true}
        else if(keyMatches(event,Qt.Key_F,"f")||keyMatches(event,Qt.Key_Space,"space")){useClassSkill();event.accepted=true}
        else if(keyMatches(event,Qt.Key_E,"e")){shopOpen=!shopOpen;event.accepted=true}
        else if(event.key===Qt.Key_Escape){if(helpOpen)helpOpen=false;else if(shopOpen)shopOpen=false;else settingsOpen=!settingsOpen;event.accepted=true}
    }

    Timer { id:saveTimer;interval:420;repeat:false;onTriggered:root.forceSave() }
    Timer { id:hostWaitTimer;interval:90;repeat:true;running:!root.initialized;onTriggered:root.initializeGame() }
    NumberAnimation { id:impactAnim;target:root;property:"impactProgress";from:0;to:1;duration:190;easing.type:Easing.OutCubic }

    Loader { id:audioLoader;active:true;asynchronous:true;source:"components/AudioBus.qml";onLoaded:{if(item){item.enabled=root.soundEnabled;item.preloadHost()}} }

    Connections { target: typeof Lifecycle!=="undefined"?Lifecycle:null;ignoreUnknownSignals:true
        function onSaveRequested(){root.forceSave()} function onBackgrounded(){root.forceSave()} function onPaused(){root.forceSave()} function onClosing(){root.forceSave()} function onUnloading(){root.forceSave()} }
    Connections { target: typeof GameI18n!=="undefined"?GameI18n:null;ignoreUnknownSignals:true
        function onReadyChanged(){root.languageRevision++;root.initializeGame();if(root.initialized)root.refreshStatusMessage()} function onLocaleChanged(){root.languageRevision++;root.refreshStatusMessage()} function onLanguageChanged(){root.languageRevision++;root.refreshStatusMessage()} }
    Connections { target: typeof GameTheme!=="undefined"?GameTheme:null;ignoreUnknownSignals:true
        function onThemeChanged(){root.themeRevision++;root.boardRevision++} function onCurrentThemeChanged(){root.themeRevision++;root.boardRevision++} }
    Connections { target: typeof GameInput!=="undefined"?GameInput:null;ignoreUnknownSignals:true
        function onActionPressed(action,value){if(action==="move_left")root.move(-1,0);else if(action==="move_right")root.move(1,0);else if(action==="up")root.move(0,-1);else if(action==="down")root.move(0,1);else if(action==="use")root.drinkPotion();else if(action==="fire")root.useBomb();else if(action==="skill"||action==="secondary")root.useClassSkill();else if(action==="pause")root.settingsOpen=!root.settingsOpen} }

    Rectangle { anchors.fill:parent;color:bg }

    Column {
        id: page
        anchors.fill:parent
        anchors.topMargin: Math.max(8,12+root.SafeArea.margins.top)
        anchors.bottomMargin: Math.max(8,12+root.SafeArea.margins.bottom)
        anchors.leftMargin: Math.max(8,12+root.SafeArea.margins.left)
        anchors.rightMargin: Math.max(8,12+root.SafeArea.margins.right)
        spacing:8

        Rectangle {
            id:header
            width:parent.width
            height:root.shortLandscape?74:(root.compactLayout?128:106)
            color:panel
            border.color:wallEdge
            border.width:1
            radius:12
            Column {
                anchors.fill:parent
                anchors.margins:8
                spacing:4
                Row {
                    width:parent.width
                    spacing:8
                    Image {
                        width:34;height:34
                        source:root.heroIcon(root.heroClass)
                        fillMode:Image.PreserveAspectFit;smooth:true;mipmap:true
                    }
                    Column {
                        width:Math.max(80,parent.width-128)
                        spacing:1
                        Text { width:parent.width;text:tr("title","Dungeon Delver")+" - "+root.className()+" - v"+root.version;color:textColor;font.pixelSize:14;font.bold:true;elide:Text.ElideRight }
                        Text { width:parent.width;text:root.styleName()+" - "+root.floorObjectiveText();color:mutedColor;font.pixelSize:10;elide:Text.ElideRight }
                    }
                    Text { width:76;text:tr("floor","FLOOR")+" "+root.floorNo;color:accentColor;font.pixelSize:13;font.bold:true;horizontalAlignment:Text.AlignRight }
                }
                Rectangle {
                    width:parent.width;height:15;radius:7;color:Qt.darker(panel,1.35);border.width:1;border.color:Qt.rgba(wallEdge.r,wallEdge.g,wallEdge.b,.35)
                    Rectangle { width:parent.width*Math.max(0,Math.min(1,root.hp/Math.max(1,root.maxHp)));height:parent.height;radius:parent.radius;color:root.hp<=root.maxHp*.3?dangerColor:successColor }
                    Text { anchors.centerIn:parent;text:tr("hp","HP")+" "+root.hp+" / "+root.maxHp;color:"white";font.pixelSize:9;font.bold:true }
                }
                Rectangle {
                    width:parent.width;height:7;radius:3;color:Qt.darker(panel,1.25)
                    Rectangle { width:parent.width*Math.max(0,Math.min(1,root.xp/Math.max(1,root.heroLevel*10)));height:parent.height;radius:parent.radius;color:infoColor }
                }
                Row {
                    anchors.horizontalCenter:parent.horizontalCenter
                    spacing:root.compactLayout?8:15
                    Row { spacing:3; Image { width:14;height:14;source:Qt.resolvedUrl("assets/ui/coin_hud.svg");fillMode:Image.PreserveAspectFit } Text{text:String(root.coins);color:accentColor;font.pixelSize:11;font.bold:true} }
                    Row { spacing:3; Image { width:14;height:14;source:Qt.resolvedUrl("assets/ui/shard_hud.svg");fillMode:Image.PreserveAspectFit } Text{text:String(root.soulShards);color:infoColor;font.pixelSize:11;font.bold:true} }
                    Text{text:tr("level_short","LV")+" "+root.heroLevel;color:successColor;font.pixelSize:11}
                    Text{text:tr("attack","ATK")+" "+root.attack;color:textColor;font.pixelSize:11}
                    Text{text:tr("armor_short","ARM")+" "+(root.armor+(root.guardTurns>0?2:0));color:textColor;font.pixelSize:11}
                    Text{visible:!root.compactLayout;text:tr("potions_short","POT")+" "+root.potions+" - "+tr("bombs_short","BOMB")+" "+root.bombs+" - "+tr("keys_short","KEY")+" "+root.keys;color:mutedColor;font.pixelSize:10}
                }
                Text { width:parent.width;text:root.message;color:mutedColor;font.pixelSize:10;horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight }
            }
        }

        Item {
            id:mainArea;width:parent.width;height:Math.max(100,parent.height-header.height-controls.height-page.spacing*2)
            readonly property real sideWidth: (root.compactLayout||root.shortLandscape)?0:220
            readonly property real availableBoardWidth: width-sideWidth-(root.compactLayout?0:10)
            readonly property real boardLimit: Math.max(60,Math.min(availableBoardWidth,height))
            readonly property real gap: boardLimit<390?1:2
            readonly property real cellSize: Math.max(4,(boardLimit-gap*(root.cols-1))/root.cols)
            readonly property real boardSize: cellSize*root.cols+gap*(root.cols-1)

            Item {
                id:boardFrame
                width:mainArea.boardSize;height:width
                x:root.compactLayout?(parent.width-width)/2:0;anchors.verticalCenter:parent.verticalCenter
                transform: Translate {
                    x: root.impactProgress<1 ? Math.sin(root.impactProgress*Math.PI*7)*(1-root.impactProgress)*root.impactStrength*5 : 0
                    y: root.impactProgress<1 ? Math.cos(root.impactProgress*Math.PI*6)*(1-root.impactProgress)*root.impactStrength*3 : 0
                }
                Rectangle { anchors.fill:parent;color:Qt.darker(root.floorColor,1.18);border.width:2;border.color:root.wallEdge;radius:8 }
                Grid {
                    anchors.centerIn:parent;columns:root.cols;spacing:mainArea.gap
                    Repeater {
                        model:root.cols*root.rows
                        Components.DungeonCell {
                            required property int index
                            cellIndex:index;cellSize:mainArea.cellSize
                            visibleCell:root.isCellVisible(index);explored:Boolean(root.seen[index]);tile:{var touch=root.boardRevision;return String(root.map[index]===undefined?"#":root.map[index])}
                            actorType:root.enemyKindAtIndex(index);actorHpRatio:root.enemyHpAtIndex(index);playerHere:index===root.idx(root.playerX,root.playerY);artStyle:root.artStyle;heroClass:root.heroClass;themeRevision:root.themeRevision
                            impactProgress:root.impactProgress;impactCell:root.impactCell;floorColor:root.floorColor;wallColor:root.wallColor;wallEdge:root.wallEdge;accentColor:root.accentColor;dangerColor:root.dangerColor;successColor:root.successColor;infoColor:root.infoColor
                        }
                    }
                }
                Rectangle { anchors.fill:parent;color:root.impactColor;opacity:root.impactProgress<1?Math.max(0,(1-root.impactProgress)*0.11*root.impactStrength):0;radius:8 }
                MouseArea {
                    anchors.fill:parent;enabled:root.inputReady
                    property real sx:0;property real sy:0
                    onPressed:function(mouse){sx=mouse.x;sy=mouse.y}
                    onReleased:function(mouse){var dx=mouse.x-sx,dy=mouse.y-sy,threshold=Math.max(18,mainArea.cellSize*.62);if(Math.max(Math.abs(dx),Math.abs(dy))<threshold)return;if(Math.abs(dx)>=Math.abs(dy))root.move(dx>0?1:-1,0);else root.move(0,dy>0?1:-1)}
                }
            }

            Rectangle {
                visible:!root.compactLayout&&!root.shortLandscape
                anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter
                width:mainArea.sideWidth;height:Math.min(parent.height,boardFrame.height)
                color:panel;border.color:wallEdge;border.width:1;radius:12
                Flickable {
                    anchors.fill:parent;anchors.margins:10;clip:true;contentWidth:width;contentHeight:sideColumn.implicitHeight
                    Column { id:sideColumn;width:parent.width;spacing:7
                        Text{text:root.className();color:textColor;font.bold:true;font.pixelSize:15}
                        Text{width:parent.width;wrapMode:Text.WordWrap;text:root.floorObjectiveText();color:accentColor;font.pixelSize:11;font.bold:true}
                        GameButton{themeRevision:root.themeRevision;width:parent.width;iconSource:root.skillIcon();text:root.skillButtonText()+"  F";primary:root.skillCooldown===0;enabled:root.inputReady&&root.skillCooldown===0;onClicked:root.useClassSkill()}
                        Row{spacing:6
                            GameButton{themeRevision:root.themeRevision;width:(parent.parent.width-6)/2;compact:true;iconSource:Qt.resolvedUrl("assets/items/potion.svg");text:String(root.potions);enabled:root.potions>0&&root.hp<root.maxHp&&!root.dead;onClicked:root.drinkPotion()}
                            GameButton{themeRevision:root.themeRevision;width:(parent.parent.width-6)/2;compact:true;iconSource:Qt.resolvedUrl("assets/items/bomb.svg");text:String(root.bombs);enabled:root.bombs>0&&!root.dead;onClicked:root.useBomb()}
                        }
                        Rectangle{width:parent.width;height:1;color:wallEdge;opacity:.45}
                        Text{text:tr("inventory","Inventory");color:textColor;font.pixelSize:12;font.bold:true}
                        Text{width:parent.width;wrapMode:Text.WordWrap;text:tr("inventory_summary","Coins %1 - Keys %2 - Potions %3 - Bombs %4").replace("%1",root.coins).replace("%2",root.keys).replace("%3",root.potions).replace("%4",root.bombs);color:mutedColor;font.pixelSize:10}
                        Text{width:parent.width;wrapMode:Text.WordWrap;text:tr("relic_summary","Relics: %1").replace("%1",root.relics.length>0?root.relics.map(function(r){return root.relicName(r)}).join(", "):tr("none","None"));color:mutedColor;font.pixelSize:10}
                        GameButton{themeRevision:root.themeRevision;width:parent.width;iconSource:Qt.resolvedUrl("assets/ui/shop.svg");text:tr("shop","Shop / Legacy")+"  E";onClicked:{root.playSfx("shop");root.shopOpen=true}}
                        GameButton{themeRevision:root.themeRevision;width:parent.width;iconSource:Qt.resolvedUrl("assets/ui/settings.svg");text:tr("settings","Settings");onClicked:{root.playSfx("button");root.settingsOpen=true}}
                        Text{width:parent.width;wrapMode:Text.WordWrap;text:tr("progress_summary","Best floor %1 - Kills %2 - Relics %3").replace("%1",bestFloor).replace("%2",totalKills).replace("%3",relics.length);color:mutedColor;font.pixelSize:10}
                    }
                }
            }
        }

        Rectangle {
            id:controls;width:parent.width;height:root.shortLandscape?48:(root.compactLayout?176:52);color:panel;border.color:wallEdge;border.width:1;radius:10
            Item { anchors.fill:parent;anchors.margins:6
                Item {
                    visible:root.compactLayout&&!root.shortLandscape
                    anchors.left:parent.left;anchors.verticalCenter:parent.verticalCenter;width:178;height:160
                    GameButton{themeRevision:root.themeRevision;width:56;height:48;anchors.horizontalCenter:parent.horizontalCenter;anchors.top:parent.top;text:"";iconSource:Qt.resolvedUrl("assets/ui/arrow_up.svg");onClicked:root.move(0,-1)}
                    GameButton{themeRevision:root.themeRevision;width:56;height:48;anchors.left:parent.left;anchors.verticalCenter:parent.verticalCenter;text:"";iconSource:Qt.resolvedUrl("assets/ui/arrow_left.svg");onClicked:root.move(-1,0)}
                    GameButton{themeRevision:root.themeRevision;width:56;height:48;anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;text:"";iconSource:Qt.resolvedUrl("assets/ui/arrow_down.svg");onClicked:root.move(0,1)}
                    GameButton{themeRevision:root.themeRevision;width:56;height:48;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;text:"";iconSource:Qt.resolvedUrl("assets/ui/arrow_right.svg");onClicked:root.move(1,0)}
                    Rectangle{width:42;height:42;anchors.centerIn:parent;radius:21;color:Qt.rgba(root.accentColor.r,root.accentColor.g,root.accentColor.b,.12);border.color:root.wallEdge}
                }
                Column {
                    visible:root.compactLayout&&!root.shortLandscape
                    anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;width:Math.max(128,parent.width-190);spacing:5
                    GameButton{themeRevision:root.themeRevision;width:parent.width;height:42;compact:true;iconSource:root.skillIcon();text:root.skillCooldown>0?tr("cooldown_short","CD")+" "+root.skillCooldown:root.skillName();primary:root.skillCooldown===0;enabled:root.inputReady&&root.skillCooldown===0;onClicked:root.useClassSkill()}
                    Row{spacing:5;anchors.horizontalCenter:parent.horizontalCenter
                        GameButton{themeRevision:root.themeRevision;width:Math.max(58,(parent.parent.width-5)/2);height:42;compact:true;iconSource:Qt.resolvedUrl("assets/items/potion.svg");text:String(root.potions);enabled:root.potions>0&&root.hp<root.maxHp&&!root.dead;onClicked:root.drinkPotion()}
                        GameButton{themeRevision:root.themeRevision;width:Math.max(58,(parent.parent.width-5)/2);height:42;compact:true;iconSource:Qt.resolvedUrl("assets/items/bomb.svg");text:String(root.bombs);enabled:root.bombs>0&&!root.dead;onClicked:root.useBomb()}
                    }
                    Row{spacing:5;anchors.horizontalCenter:parent.horizontalCenter
                        GameButton{themeRevision:root.themeRevision;width:Math.max(58,(parent.parent.width-5)/2);height:42;compact:true;iconSource:Qt.resolvedUrl("assets/ui/shop.svg");text:tr("shop","Shop");onClicked:{root.playSfx("shop");root.shopOpen=true}}
                        GameButton{themeRevision:root.themeRevision;width:Math.max(58,(parent.parent.width-5)/2);height:42;compact:true;iconSource:Qt.resolvedUrl("assets/ui/settings.svg");text:tr("settings_short","Options");onClicked:root.settingsOpen=true}
                    }
                }
                Row { visible:!root.compactLayout;anchors.centerIn:parent;spacing:8
                    GameButton{themeRevision:root.themeRevision;compact:true;iconSource:root.skillIcon();text:root.skillButtonText()+" (F)";primary:root.skillCooldown===0;enabled:root.inputReady&&root.skillCooldown===0;onClicked:root.useClassSkill()}
                    GameButton{themeRevision:root.themeRevision;compact:true;iconSource:Qt.resolvedUrl("assets/items/potion.svg");text:tr("drink_potion","Drink Potion")+" (H)";enabled:root.potions>0&&root.hp<root.maxHp&&!root.dead;onClicked:root.drinkPotion()}
                    GameButton{themeRevision:root.themeRevision;compact:true;iconSource:Qt.resolvedUrl("assets/items/bomb.svg");text:tr("use_bomb","Use Bomb")+" (B)";enabled:root.bombs>0&&!root.dead;onClicked:root.useBomb()}
                    GameButton{themeRevision:root.themeRevision;compact:true;iconSource:Qt.resolvedUrl("assets/ui/shop.svg");text:tr("shop","Shop / Legacy")+" (E)";onClicked:{root.playSfx("shop");root.shopOpen=true}}
                    GameButton{themeRevision:root.themeRevision;compact:true;iconSource:Qt.resolvedUrl("assets/ui/settings.svg");text:tr("settings","Settings");onClicked:root.settingsOpen=true}
                }
            }
        }
    }

    Rectangle {
        visible:root.classPickerOpen
        anchors.fill:parent
        z:120
        color:Qt.rgba(0,0,0,.72)
        MouseArea{anchors.fill:parent}
        Rectangle {
            width:Math.min(parent.width-24,560)
            height:Math.min(parent.height-24,600)
            anchors.centerIn:parent
            color:panel
            border.color:wallEdge
            border.width:2
            radius:16
            Flickable {
                anchors.fill:parent
                anchors.margins:14
                contentWidth:width
                contentHeight:classColumn.implicitHeight
                clip:true
                Column {
                    id:classColumn
                    width:parent.width
                    spacing:10
                    Text{width:parent.width;text:tr("choose_delver","Choose your Delver");color:textColor;font.pixelSize:22;font.bold:true;horizontalAlignment:Text.AlignHCenter}
                    Text{width:parent.width;wrapMode:Text.WordWrap;text:tr("choose_delver_hint","Each class has different starting stats and an active skill. You can choose again on every new run.");color:mutedColor;font.pixelSize:12;horizontalAlignment:Text.AlignHCenter}
                    Repeater {
                        model:3
                        Rectangle {
                            required property int index
                            width:classColumn.width
                            height:112
                            radius:12
                            color:Qt.lighter(panel,1.08)
                            border.width:1
                            border.color:index===root.heroClass?accentColor:wallEdge
                            Row {
                                anchors.fill:parent
                                anchors.margins:8
                                spacing:10
                                Image{width:72;height:72;anchors.verticalCenter:parent.verticalCenter;source:root.heroIcon(index);fillMode:Image.PreserveAspectFit;smooth:true;mipmap:true}
                                Column{width:Math.max(120,parent.width-190);anchors.verticalCenter:parent.verticalCenter;spacing:4
                                    Text{text:index===0?tr("class_sentinel","Sentinel"):(index===1?tr("class_rogue","Rogue"):tr("class_arcanist","Arcanist"));color:textColor;font.pixelSize:16;font.bold:true}
                                    Text{width:parent.width;wrapMode:Text.WordWrap;maximumLineCount:3;elide:Text.ElideRight;text:root.classDescription(index);color:mutedColor;font.pixelSize:11}
                                    Text{text:index===0?tr("class_sentinel_stats","HP+6 - Armor+1 - Guard"):(index===1?tr("class_rogue_stats","ATK+1 - Bomb+1 - Evasion"):tr("class_arcanist_stats","Potion+1 - Area magic"));color:index===2?infoColor:accentColor;font.pixelSize:10;font.bold:true}
                                }
                                GameButton{themeRevision:root.themeRevision;width:86;height:42;anchors.verticalCenter:parent.verticalCenter;text:tr("choose","Choose");primary:index===root.heroClass;onClicked:root.startNewRunAs(index)}
                            }
                        }
                    }
                    Rectangle{width:parent.width;height:1;color:wallEdge;opacity:.5}
                    Row{anchors.horizontalCenter:parent.horizontalCenter;spacing:8
                        Text{anchors.verticalCenter:parent.verticalCenter;text:tr("visual_style","Visual style")+": "+root.styleName();color:mutedColor;font.pixelSize:11}
                        GameButton{themeRevision:root.themeRevision;compact:true;text:tr("change","Change");onClicked:root.cycleStyle()}
                    }
                }
            }
        }
    }

    Rectangle {
        visible:root.shopOpen;anchors.fill:parent;z:80;color:Qt.rgba(0,0,0,.58)
        MouseArea{anchors.fill:parent}
        Rectangle { width:Math.min(parent.width-28,520);height:Math.min(parent.height-28,560);anchors.centerIn:parent;color:panel;border.color:wallEdge;border.width:2;radius:14
            Flickable { anchors.fill:parent;anchors.margins:14;contentWidth:width;contentHeight:shopColumn.implicitHeight;clip:true
                Column { id:shopColumn;width:parent.width;spacing:8
                    Text{text:tr("shop_title","Delver's Camp");color:textColor;font.pixelSize:20;font.bold:true}
                    Text{text:tr("run_currency","Run coins: %1").replace("%1",coins);color:accentColor;font.bold:true}
                    GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("buy_potion","Potion - %1 coins").replace("%1",root.supplyCost("potion"));enabled:!root.dead&&root.coins>=root.supplyCost("potion");onClicked:root.buySupply("potion")}
                    GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("buy_bomb","Bomb - %1 coins").replace("%1",root.supplyCost("bomb"));enabled:!root.dead&&root.coins>=root.supplyCost("bomb");onClicked:root.buySupply("bomb")}
                    GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("buy_key","Key - %1 coins").replace("%1",root.supplyCost("key"));enabled:!root.dead&&root.coins>=root.supplyCost("key");onClicked:root.buySupply("key")}
                    Rectangle{width:parent.width;height:1;color:wallEdge;opacity:.55}
                    Row { spacing:6; Image { width:18;height:18;source:Qt.resolvedUrl("assets/ui/shard_hud.svg");fillMode:Image.PreserveAspectFit } Text{text:tr("legacy_title","Soul Legacy")+" - "+soulShards;color:infoColor;font.pixelSize:16;font.bold:true} }
                    Text{width:parent.width;wrapMode:Text.WordWrap;text:tr("legacy_hint","Soul Shards survive run restarts and buy permanent upgrades.");color:mutedColor;font.pixelSize:12}
                    GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("upgrade_vitality","Vitality %1 - %2 shards").replace("%1",Number(root.upgrades.vitality||0)).replace("%2",root.upgradeCost("vitality"));enabled:root.soulShards>=root.upgradeCost("vitality");onClicked:root.buyUpgrade("vitality")}
                    GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("upgrade_might","Might %1 - %2 shards").replace("%1",Number(root.upgrades.might||0)).replace("%2",root.upgradeCost("might"));enabled:root.soulShards>=root.upgradeCost("might");onClicked:root.buyUpgrade("might")}
                    GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("upgrade_fortune","Fortune %1 - %2 shards").replace("%1",Number(root.upgrades.fortune||0)).replace("%2",root.upgradeCost("fortune"));enabled:root.soulShards>=root.upgradeCost("fortune");onClicked:root.buyUpgrade("fortune")}
                    GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("upgrade_torch","Torch %1 - %2 shards").replace("%1",Number(root.upgrades.torch||0)).replace("%2",root.upgradeCost("torch"));enabled:root.soulShards>=root.upgradeCost("torch");onClicked:root.buyUpgrade("torch")}
                    GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("close","Close");primary:true;onClicked:{root.shopOpen=false;root.forceActiveFocus()}}
                }
            }
        }
    }

    Rectangle {
        visible:root.settingsOpen;anchors.fill:parent;z:85;color:Qt.rgba(0,0,0,.58)
        MouseArea{anchors.fill:parent}
        Rectangle { width:Math.min(parent.width-28,440);height:Math.min(parent.height-28,470);anchors.centerIn:parent;color:panel;border.color:wallEdge;border.width:2;radius:14
            Flickable { anchors.fill:parent;anchors.margins:14;contentWidth:width;contentHeight:settingsColumn.implicitHeight;clip:true
                Column { id:settingsColumn;width:parent.width;spacing:9
                    Text{text:tr("settings","Settings");color:textColor;font.pixelSize:20;font.bold:true}
                    GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("visual_style","Visual style")+": "+root.styleName();onClicked:root.cycleStyle()}
                    GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("sound","Sound")+": "+(root.soundEnabled?tr("on","On"):tr("off","Off"));onClicked:root.toggleSound()}
                    GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("test_sound","Test Sound");enabled:root.soundEnabled;onClicked:{root.playSfx("coin");root.haptic("light")}}
                    GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("vibration","Vibration")+": "+(root.vibrationEnabled?tr("on","On"):tr("off","Off"));onClicked:root.toggleVibration()}
                    GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("guide","Guide");onClicked:root.helpOpen=true}
                    Rectangle{width:parent.width;height:1;color:wallEdge;opacity:.55}
                    Text{width:parent.width;wrapMode:Text.WordWrap;text:tr("run_warning","Starting a new run keeps Soul Shards and legacy upgrades, but resets the current dungeon run.");color:mutedColor;font.pixelSize:12}
                    GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("new_run","Start New Run");onClicked:{root.newRun();root.settingsOpen=false}}
                    GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("close","Close");primary:true;onClicked:{root.settingsOpen=false;root.forceActiveFocus()}}
                }
            }
        }
    }

    Rectangle {
        visible:root.helpOpen;anchors.fill:parent;z:90;color:Qt.rgba(0,0,0,.62)
        MouseArea{anchors.fill:parent}
        Rectangle { width:Math.min(parent.width-28,500);height:Math.min(parent.height-28,440);anchors.centerIn:parent;color:panel;border.color:wallEdge;border.width:2;radius:14
            Flickable { anchors.fill:parent;anchors.margins:14;contentWidth:width;contentHeight:helpColumn.implicitHeight;clip:true
                Column { id:helpColumn;width:parent.width;spacing:9
                    Text{text:tr("guide_title","Dungeon Delver Guide");color:textColor;font.pixelSize:20;font.bold:true}
                    Text{width:parent.width;wrapMode:Text.WordWrap;text:tr("guide_move","Desktop: WASD/arrows. Mobile: swipe on the dungeon or use the large D-pad.");color:textColor;font.pixelSize:13}
                    Text{width:parent.width;wrapMode:Text.WordWrap;text:tr("guide_combat","Walk into enemies to attack. Potions heal; bombs damage nearby enemies.");color:textColor;font.pixelSize:13}
                    Text{width:parent.width;wrapMode:Text.WordWrap;text:tr("guide_skill","Use your class skill with F/Space on desktop or the highlighted skill button on mobile. Skills recharge as you take turns.");color:textColor;font.pixelSize:13}
                    Text{width:parent.width;wrapMode:Text.WordWrap;text:tr("guide_loot","Keys open chests. Relics improve the current run. Soul Shards survive death and buy permanent upgrades.");color:textColor;font.pixelSize:13}
                    Text{width:parent.width;wrapMode:Text.WordWrap;text:tr("guide_boss","Every fifth floor has a Guardian. Defeat it before the stairs can be used.");color:textColor;font.pixelSize:13}
                    GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("got_it","Got it");primary:true;onClicked:{root.helpOpen=false;root.tutorialCompleted=true;root.markDirty(true);root.forceActiveFocus()}}
                }
            }
        }
    }

    Rectangle {
        visible:root.dead;anchors.fill:parent;z:70;color:Qt.rgba(0,0,0,.64)
        MouseArea{anchors.fill:parent}
        Rectangle { width:Math.min(parent.width-32,380);implicitHeight:deathColumn.implicitHeight+28;anchors.centerIn:parent;color:panel;border.color:dangerColor;border.width:2;radius:14
            Column { id:deathColumn;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:14;spacing:10
                Text{width:parent.width;text:tr("run_ended","Run Ended");color:dangerColor;font.pixelSize:22;font.bold:true;horizontalAlignment:Text.AlignHCenter}
                Text{width:parent.width;text:tr("death_summary","Floor %1 - Coins %2 - Soul Shards %3").replace("%1",floorNo).replace("%2",coins).replace("%3",soulShards);color:textColor;horizontalAlignment:Text.AlignHCenter}
                GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("new_run","Start New Run");primary:true;onClicked:root.newRun()}
                GameButton{themeRevision:root.themeRevision;width:parent.width;text:tr("legacy_shop","Open Legacy Shop");onClicked:root.shopOpen=true}
            }
        }
    }

    Component.onCompleted: initializeGame()
    Component.onDestruction: forceSave()
}
