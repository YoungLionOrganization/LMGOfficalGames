import QtQuick

Item {
    id: root
    focus: true

    property int floor: 1
    property int hp: 58
    property int maxHp: 58
    property int gold: 0
    property int energy: 3
    property int block: 0
    property int enemyHp: 30
    property int enemyMax: 30
    property int enemyPower: 6
    property int enemyArmor: 0
    property string enemyName: "Raider"
    property string enemyIntent: "attack"
    property int vulnerableTurns: 0
    property int score: 0
    property var deck: []
    property var drawPile: []
    property var discard: []
    property var hand: []
    property var relics: []
    property var rewardChoices: []
    property bool choosingReward: false
    property int selectedCard: 0
    property string message: ""
    readonly property bool showHints: Boolean(GameSettings.value("showHints", true))

    readonly property var library: ({
        strike:   {id:"strike",   name:"Strike",       cost:1, text:"Deal 8 damage",             kind:"attack",  value:8,  color:"color.danger"},
        guard:    {id:"guard",    name:"Guard",        cost:1, text:"Gain 7 block",              kind:"block",   value:7,  color:"color.info"},
        focus:    {id:"focus",    name:"Focus",        cost:0, text:"Draw 1; gain 1 energy",     kind:"focus",   value:1,  color:"color.accent"},
        mend:     {id:"mend",     name:"Mend",         cost:2, text:"Heal 7",                    kind:"heal",    value:7,  color:"color.success"},
        heavy:    {id:"heavy",    name:"Heavy Blow",   cost:2, text:"Deal 15 damage",            kind:"attack",  value:15, color:"color.warningText"},
        fortify:  {id:"fortify",  name:"Fortify",      cost:2, text:"Gain 15 block",             kind:"block",   value:15, color:"color.primary"},
        leech:    {id:"leech",    name:"Leech",        cost:2, text:"Deal 9; heal 4",            kind:"leech",   value:9,  color:"color.accent"},
        volley:   {id:"volley",   name:"Volley",       cost:1, text:"Deal 4 × 2",                kind:"multi",   value:4,  color:"color.danger"},
        bash:     {id:"bash",     name:"Bash",         cost:2, text:"Deal 10; vulnerable 2",     kind:"bash",    value:10, color:"color.warningText"},
        quickstep:{id:"quickstep",name:"Quickstep",    cost:1, text:"Gain 5 block; draw 2",      kind:"quick",   value:5,  color:"color.info"},
        barrier:  {id:"barrier",  name:"Prism Barrier",cost:2, text:"Gain 11 block + 1 energy",  kind:"barrier", value:11, color:"color.primary"},
        execute:  {id:"execute",  name:"Execute",      cost:2, text:"12 damage; +10 under 35% HP",kind:"execute",value:12, color:"color.danger"}
    })

    function tr(k, f) { return GameI18n.text(k, f) }
    function freshDeck() { return ["strike","strike","strike","strike","guard","guard","guard","guard","focus","mend"] }
    function shuffle(a) { return GameRandom.shuffled(a) }
    function hasRelic(id) { return relics.indexOf(id) >= 0 }
    function attackBonus() { return hasRelic("ember_core") ? 2 : 0 }
    function blockBonus() { return hasRelic("iron_sigil") ? 2 : 0 }

    function draw(n) {
        var h = hand.slice(), dp = drawPile.slice(), dc = discard.slice()
        for (var i=0; i<n; ++i) {
            if (dp.length === 0) { dp = shuffle(dc); dc = [] }
            if (dp.length > 0 && h.length < 8) h.push(dp.pop())
        }
        hand = h; drawPile = dp; discard = dc
    }

    function enemyArchetype() {
        if (floor % 5 === 0) return {name:"Void Warden", hp:44+floor*9, power:8+Math.floor(floor*1.5), armor:4+Math.floor(floor/4), boss:true}
        var roll = GameRandom.nextInt(0,3)
        if (roll===0) return {name:"Raider", hp:24+floor*6, power:6+Math.floor(floor*1.25), armor:0, boss:false}
        if (roll===1) return {name:"Sentinel", hp:31+floor*7, power:5+Math.floor(floor*1.15), armor:3+Math.floor(floor/5), boss:false}
        if (roll===2) return {name:"Hex Adept", hp:26+floor*6, power:5+Math.floor(floor*1.2), armor:1, boss:false}
        return {name:"Bulwark", hp:37+floor*8, power:4+Math.floor(floor*1.1), armor:5+Math.floor(floor/4), boss:false}
    }

    function rollIntent() {
        var r = GameRandom.nextReal()
        if (enemyName === "Hex Adept" && r < 0.28) return "hex"
        if ((enemyName === "Sentinel" || enemyName === "Bulwark") && r < 0.32) return "guard"
        if (r < 0.22) return "charge"
        return "attack"
    }

    function newEnemy() {
        var e = enemyArchetype()
        enemyName = e.name; enemyMax = e.hp; enemyHp = e.hp; enemyPower = e.power; enemyArmor = e.armor
        enemyIntent = rollIntent(); energy = hasRelic("prism_battery") ? 4 : 3; block = 0; vulnerableTurns = 0
        hand = []; discard = []; drawPile = shuffle(deck); draw(5)
        choosingReward = false; rewardChoices = []
        message = e.boss ? "Boss floor · defeat the Void Warden" : ""
        GameEvents.emitEvent("rogue_floor", floor)
    }

    function dealDamage(raw) {
        var amount = raw + attackBonus()
        if (vulnerableTurns > 0) amount = Math.round(amount * 1.45)
        amount = Math.max(0, amount - enemyArmor)
        enemyHp -= amount
        return amount
    }

    function playCard(i) {
        if (choosingReward || i<0 || i>=hand.length || hp<=0 || enemyHp<=0) return
        var id = hand[i], c = library[id]
        if (!c || energy < c.cost) return
        energy -= c.cost

        if (c.kind === "attack") dealDamage(c.value)
        else if (c.kind === "block") block += c.value + blockBonus()
        else if (c.kind === "focus") { energy++; draw(1) }
        else if (c.kind === "heal") hp = Math.min(maxHp, hp+c.value)
        else if (c.kind === "leech") { dealDamage(c.value); hp=Math.min(maxHp,hp+4) }
        else if (c.kind === "multi") { dealDamage(c.value); dealDamage(c.value) }
        else if (c.kind === "bash") { dealDamage(c.value); vulnerableTurns=Math.max(vulnerableTurns,2) }
        else if (c.kind === "quick") { block += c.value + blockBonus(); draw(2) }
        else if (c.kind === "barrier") { block += c.value + blockBonus(); energy++ }
        else if (c.kind === "execute") { dealDamage(c.value + (enemyHp < enemyMax*0.35 ? 10 : 0)) }

        var h=hand.slice(); h.splice(i,1); hand=h
        var dc=discard.slice(); dc.push(id); discard=dc
        selectedCard = Math.max(0, Math.min(selectedCard, hand.length-1))
        Haptics.light(); GameStats.increment("cards_played")
        if (enemyHp <= 0) winCombat()
        persist()
    }

    function endTurn() {
        if (choosingReward || enemyHp<=0 || hp<=0) return
        var damage = 0
        if (enemyIntent === "attack") damage = enemyPower
        else if (enemyIntent === "charge") damage = enemyPower + 6
        else if (enemyIntent === "hex") { damage = Math.max(2, Math.floor(enemyPower*0.55)); energy=Math.max(0,energy-1) }
        else if (enemyIntent === "guard") enemyArmor = Math.min(14, enemyArmor+2)

        var taken = Math.max(0, damage-block); block=0; hp -= taken
        if (vulnerableTurns > 0) vulnerableTurns--
        enemyIntent = rollIntent(); energy = hasRelic("prism_battery") ? 4 : 3
        discard = discard.concat(hand); hand=[]; draw(5)
        if (hp<=0) {
            hp=0; message="Run ended on floor "+floor
            GameStats.submitHighScore(floor,"best_floor"); GameStats.submitHighScore(score); GameStats.increment("runs")
            Haptics.heavy()
        }
        persist()
    }

    function cardPool() { return ["heavy","fortify","leech","volley","focus","mend","bash","quickstep","barrier","execute"] }
    function makeRewardChoices() {
        var pool = shuffle(cardPool()), out=[]
        for (var i=0; i<3 && i<pool.length; ++i) out.push(pool[i])
        rewardChoices = out; choosingReward = true
    }
    function chooseReward(i) {
        if (!choosingReward || i<0 || i>=rewardChoices.length) return
        var id=rewardChoices[i]; deck=deck.concat([id]); message="Added "+library[id].name
        choosingReward=false; rewardChoices=[]; advanceFloor()
    }
    function skipReward() { if (choosingReward) { gold+=18; choosingReward=false; rewardChoices=[]; advanceFloor() } }

    function grantRelic() {
        var pool=["iron_sigil","ember_core","prism_battery","vital_seed"]
        var candidates=[]; for(var i=0;i<pool.length;i++) if(!hasRelic(pool[i])) candidates.push(pool[i])
        if(candidates.length===0){gold+=80;return}
        var relic=candidates[GameRandom.nextInt(0,candidates.length-1)]; relics=relics.concat([relic])
        if(relic==="vital_seed"){maxHp+=8;hp=Math.min(maxHp,hp+8)}
        Achievements.unlock("relic_"+relic); message="Relic acquired: "+relic.replace("_"," ")
    }

    function winCombat() {
        gold += 12+floor*3; score += 100+floor*20
        GameStats.submitHighScore(score)
        if (floor%5===0) { grantRelic(); hp=Math.min(maxHp,hp+14); Achievements.unlock("boss_"+floor) }
        makeRewardChoices()
        persist()
    }
    function advanceFloor() { floor++; GameStats.submitHighScore(floor,"best_floor"); newEnemy(); persist() }
    function rest() { if(gold<30||hp>=maxHp)return; gold-=30; hp=Math.min(maxHp,hp+18); persist() }
    function removeCard() { if(gold<55 || deck.length<=8)return; gold-=55; deck.splice(Math.max(0,deck.indexOf("strike")),1); deck=deck.slice(); persist() }
    function newRun() { floor=1;hp=58;maxHp=58;gold=0;score=0;relics=[];deck=freshDeck();newEnemy();persist() }

    function persist() {
        GameSave.set("floor",floor); GameSave.set("hp",hp); GameSave.set("maxHp",maxHp); GameSave.set("gold",gold); GameSave.set("score",score)
        GameSave.set("deck",deck); GameSave.set("relics",relics); GameSave.set("enemyHp",enemyHp); GameSave.set("enemyMax",enemyMax)
        GameSave.set("enemyName",enemyName); GameSave.set("enemyIntent",enemyIntent); GameSave.set("enemyPower",enemyPower); GameSave.set("enemyArmor",enemyArmor)
        GameSave.set("draw",drawPile); GameSave.set("discard",discard); GameSave.set("hand",hand); GameSave.set("energy",energy); GameSave.set("block",block)
        GameSave.set("vulnerable",vulnerableTurns); GameSave.set("choosingReward",choosingReward); GameSave.set("rewardChoices",rewardChoices)
        GameSave.save("autosave")
    }
    function loadGame() {
        if(GameSave.load("autosave")){
            floor=Number(GameSave.get("floor",1));hp=Number(GameSave.get("hp",58));maxHp=Number(GameSave.get("maxHp",58));gold=Number(GameSave.get("gold",0));score=Number(GameSave.get("score",0))
            deck=GameSave.get("deck",freshDeck());relics=GameSave.get("relics",[]);enemyHp=Number(GameSave.get("enemyHp",30));enemyMax=Number(GameSave.get("enemyMax",30))
            enemyName=String(GameSave.get("enemyName","Raider"));enemyIntent=String(GameSave.get("enemyIntent","attack"));enemyPower=Number(GameSave.get("enemyPower",6));enemyArmor=Number(GameSave.get("enemyArmor",0))
            drawPile=GameSave.get("draw",[]);discard=GameSave.get("discard",[]);hand=GameSave.get("hand",[]);energy=Number(GameSave.get("energy",3));block=Number(GameSave.get("block",0))
            vulnerableTurns=Number(GameSave.get("vulnerable",0));choosingReward=Boolean(GameSave.get("choosingReward",false));rewardChoices=GameSave.get("rewardChoices",[])
        } else { deck=freshDeck(); newEnemy() }
        if(deck.length===0)deck=freshDeck(); if(hand.length===0 && !choosingReward)draw(5)
    }

    Rectangle { anchors.fill: parent; color: GameTheme.color("color.background") }
    Connections { target: Lifecycle; function onSaveRequested(){persist()} function onBackgrounded(){persist()} }
    Keys.onPressed: function(e) {
        if (choosingReward && e.key>=Qt.Key_1 && e.key<=Qt.Key_3) { chooseReward(e.key-Qt.Key_1); e.accepted=true; return }
        if (!choosingReward && e.key>=Qt.Key_1 && e.key<=Qt.Key_5) { playCard(e.key-Qt.Key_1); e.accepted=true }
        else if(e.key===Qt.Key_Space){ if(choosingReward)skipReward(); else endTurn(); e.accepted=true }
        else if(e.key===Qt.Key_R){rest();e.accepted=true}
    }

    Column {
        anchors.fill: parent
        anchors.margins: GameTheme.number("alias.page.padding")
        spacing: GameTheme.number("alias.page.gap")

        UiPanel {
            width: parent.width
            implicitHeight: hud.implicitHeight + GameTheme.number("alias.card.padding")*2
            surfaceToken: "surface.panel"
            Flow {
                id: hud; anchors.fill:parent; anchors.margins:GameTheme.number("alias.card.padding"); spacing:GameTheme.number("alias.card.gap")
                UiText { text:tr("title","Rogue Deck");font.bold:true;sizeToken:"metric.font.lg" }
                HudChip { label:"Floor";value:String(floor) }
                HudChip { label:"HP";value:hp+"/"+maxHp;valueColorToken:hp>15?"color.success":"color.danger" }
                HudChip { label:"Block";value:String(block) }
                HudChip { label:tr("energy","Energy");value:String(energy) }
                HudChip { label:"Gold";value:String(gold) }
                HudChip { label:"Relics";value:String(relics.length) }
            }
        }

        UiPanel {
            width:parent.width
            height:GameTheme.number("metric.control.lg")*2.25
            surfaceToken:"surface.gameBoard"
            Column {
                anchors.centerIn:parent; spacing:GameTheme.number("metric.space.xs")
                UiText { anchors.horizontalCenter:parent.horizontalCenter; text:(floor%5===0?"BOSS · ":"")+enemyName+"   "+enemyHp+" / "+enemyMax; font.bold:true; sizeToken:"metric.font.xl"; colorToken:floor%5===0?"color.danger":"color.accent" }
                UiBar { width:Math.min(root.width*0.65,GameTheme.number("metric.unit.480"));height:GameTheme.number("metric.space.sm");value:enemyHp;to:enemyMax;fillToken:"color.danger" }
                UiText { anchors.horizontalCenter:parent.horizontalCenter; text:"Intent: "+enemyIntent+(enemyIntent==="attack"?" "+enemyPower:enemyIntent==="charge"?" "+(enemyPower+6):"")+" · Armor "+enemyArmor+(vulnerableTurns>0?" · Vulnerable":"");colorToken:"color.textMuted" }
            }
        }

        UiPanel {
            visible:choosingReward
            width:parent.width
            implicitHeight:rewardRow.implicitHeight+GameTheme.number("alias.card.padding")*2
            surfaceToken:"surface.card"
            Flow {
                id:rewardRow; anchors.fill:parent; anchors.margins:GameTheme.number("alias.card.padding"); spacing:GameTheme.number("alias.card.gap")
                UiText { text:"Choose a card reward";font.bold:true;colorToken:"color.accent" }
                Repeater {
                    model:rewardChoices
                    UiButton { required property int index; required property string modelData; text:(index+1)+" · "+root.library[modelData].name;primary:true;onActivated:root.chooseReward(index) }
                }
                UiButton { text:"Skip · +18 gold";shortcutText:"Space";onActivated:root.skipReward() }
            }
        }

        Flow {
            visible:!choosingReward
            width:parent.width
            spacing:GameTheme.number("alias.card.gap")
            Repeater {
                model:hand
                UiPanel {
                    required property int index
                    required property string modelData
                    width:Math.max(GameTheme.number("metric.card.md"),Math.min(GameTheme.number("metric.card.xl"),(root.width-GameTheme.number("alias.page.padding")*2-GameTheme.number("alias.card.gap")*4)/5))
                    height:GameTheme.number("metric.control.lg")*2.35
                    surfaceToken:"surface.card"
                    property var c:root.library[modelData]
                    Column {
                        anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("metric.space.xs")
                        UiText { text:(index+1)+" · "+parent.parent.c.name;font.bold:true;colorToken:parent.parent.c.color }
                        UiText { text:parent.parent.c.text;width:parent.width;colorToken:"color.textMuted";sizeToken:"metric.font.sm";wrapMode:Text.WordWrap }
                        UiText { text:"Cost "+parent.parent.c.cost;colorToken:"color.accent";font.bold:true }
                    }
                    TapHandler { onTapped:root.playCard(index) }
                }
            }
        }

        Flow {
            visible:!choosingReward
            width:parent.width;spacing:GameTheme.number("alias.button.gap")
            UiButton { text:tr("end_turn","End Turn");shortcutText:"Space";primary:true;onActivated:endTurn() }
            UiButton { text:"Rest +18 HP · 30g";shortcutText:"R";enabled:gold>=30&&hp<maxHp;onActivated:rest() }
            UiButton { text:"Remove Strike · 55g";enabled:gold>=55&&deck.length>8;onActivated:removeCard() }
            UiButton { text:tr("new_run","New Run");onActivated:newRun() }
        }
        UiText { width:parent.width;text:message+(showHints?" · Cards: 1–5/click. Space ends turn. Reward choices: 1–3. Boss every 5 floors.":"");colorToken:"color.textMuted";horizontalAlignment:Text.AlignHCenter;sizeToken:"metric.font.xs" }
    }

    Connections { target: GameInput; function onActionPressed(action,value) { if(action==="move_left")selectedCard=Math.max(0,selectedCard-1); else if(action==="move_right")selectedCard=Math.min(Math.max(0,hand.length-1),selectedCard+1); else if(action==="fire")playCard(selectedCard); else if(action==="pause")endTurn() } }

    Component.onCompleted: { GameRandom.seed("rogue-deck-v64"); loadGame(); forceActiveFocus() }
}
