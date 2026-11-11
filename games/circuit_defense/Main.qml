import QtQuick

FocusScope {
    id: root
    focus: true
    readonly property int lanes: 5
    readonly property int cells: 10
    property int selectedCell: 20
    property int selectedTower: 0
    property int credits: 220
    property int baseHp: 20
    property int baseShield: 6
    property int wave: 0
    property int score: 0
    property int tech: 0
    property int damageResearch: 0
    property int rangeResearch: 0
    property int economyResearch: 0
    property int abilityCooldown: 0
    property int orbitalCooldown: 0
    property int overclockTicks: 0
    property bool running: false
    property bool paused: false
    property int spawnLeft: 0
    property int spawnCooldown: 0
    property var towers: []
    property var enemies: []
    property string message: tr("ready","Build your circuit, then start the wave.")
    readonly property bool showHints:Boolean(GameSettings.value("showHints",true))
    readonly property var towerDefs:[
        {name:"Pulse",cost:50,damage:2.2,rate:4,range:4,color:"color.primary",desc:"Fast all-round pulse tower"},
        {name:"Cannon",cost:90,damage:7.0,rate:11,range:3,color:"color.accent",desc:"Heavy splash damage"},
        {name:"Frost",cost:78,damage:1.4,rate:6,range:4,color:"color.info",desc:"Slows enemies"},
        {name:"Laser",cost:115,damage:4.5,rate:5,range:6,color:"color.danger",desc:"Ignores most armor"},
        {name:"Tesla",cost:138,damage:5.2,rate:8,range:5,color:"color.success",desc:"Chains to nearby targets"},
        {name:"Rail",cost:185,damage:13.0,rate:15,range:8,color:"color.special",desc:"Long-range boss killer"}
    ]
    readonly property var enemyDefs:[
        {name:"Drone",hp:10,speed:0.060,armor:0,shield:0,reward:10,color:"color.accent"},
        {name:"Runner",hp:7,speed:0.095,armor:0,shield:0,reward:12,color:"color.special"},
        {name:"Armored",hp:20,speed:0.045,armor:2,shield:0,reward:18,color:"color.textMuted"},
        {name:"Shield",hp:15,speed:0.052,armor:0,shield:10,reward:20,color:"color.info"},
        {name:"Regenerator",hp:17,speed:0.050,armor:1,shield:0,reward:22,color:"color.success"},
        {name:"Boss",hp:95,speed:0.030,armor:3,shield:25,reward:90,color:"color.danger"}
    ]

    function tr(k,f){return GameI18n.text(k,f)}
    function clone(v){return JSON.parse(JSON.stringify(v))}
    function towerAt(lane,cell){for(var i=0;i<towers.length;i++)if(towers[i].lane===lane&&towers[i].cell===cell)return i;return -1}
    function selectedLane(){return Math.floor(selectedCell/cells)}
    function selectedGridCell(){return selectedCell%cells}
    function towerUpgradeCost(t){return 35+t.level*42}
    function towerDamage(t){return towerDefs[t.type].damage*t.level*(1+damageResearch*0.10)*(overclockTicks>0?1.5:1.0)}
    function towerRange(t){return towerDefs[t.type].range+rangeResearch*0.35+t.level*0.15}
    function place(lane,cell){root.forceActiveFocus();selectedCell=lane*cells+cell;var at=towerAt(lane,cell);if(at>=0){upgrade(at);return}var d=towerDefs[selectedTower];if(cell>=cells-1){message="Cannot build on the base gate";return}if(credits<d.cost){message="Need "+d.cost+" credits";return}credits-=d.cost;var n=clone(towers);n.push({lane:lane,cell:cell,type:selectedTower,level:1,cool:0});towers=n;message=d.name+" tower built";Haptics.light();persist()}
    function upgrade(i){if(i<0)return;var t=towers[i],cost=towerUpgradeCost(t);if(t.level>=5){message="Tower already max level";return}if(credits<cost){message="Need "+cost+" credits";return}credits-=cost;var n=clone(towers);n[i].level++;towers=n;message=towerDefs[t.type].name+" upgraded to Lv "+n[i].level;persist()}
    function sell(i){if(i<0)return;var t=towers[i],refund=Math.round(towerDefs[t.type].cost*(0.50+0.08*t.level));credits+=refund;var n=clone(towers);n.splice(i,1);towers=n;message="Tower sold · +"+refund;persist()}

    function waveEnemyType(slot,total){if(wave%5===0&&slot===total-1)return 5;var max=Math.min(4,Math.floor(wave/2));var roll=GameRandom.nextInt(0,max);if(wave<2)roll=0;return roll}
    function spawnEnemy(){var total=8+wave*2,type=waveEnemyType(total-spawnLeft,total),d=enemyDefs[type],lane=GameRandom.nextInt(0,lanes-1),scale=1+wave*0.115;var n=clone(enemies);n.push({lane:lane,x:cells+0.15,type:type,hp:Math.round(d.hp*scale),maxHp:Math.round(d.hp*scale),shield:Math.round(d.shield*scale),maxShield:Math.round(d.shield*scale),speed:d.speed*(1+wave*0.012),slow:0,regen:type===4,alive:true});enemies=n}
    function startWave(){if(baseHp<=0)return;if(running){paused=!paused;message=paused?"Wave paused":"Wave resumed";return}wave++;spawnLeft=8+wave*2;spawnCooldown=1;running=true;paused=false;message="Wave "+wave+" incoming";GameStats.increment("waves_started");persist()}

    function applyDamage(enemy,dmg,armorPierce){var left=dmg;if(enemy.shield>0){var absorbed=Math.min(enemy.shield,left);enemy.shield-=absorbed;left-=absorbed}if(left>0){var armor=armorPierce?Math.floor(enemyDefs[enemy.type].armor*0.2):enemyDefs[enemy.type].armor;enemy.hp-=Math.max(0.5,left-armor)}return enemy}
    function tick(){if(!running||paused)return;if(abilityCooldown>0)abilityCooldown--;if(orbitalCooldown>0)orbitalCooldown--;if(overclockTicks>0)overclockTicks--;if(spawnLeft>0){spawnCooldown--;if(spawnCooldown<=0){spawnEnemy();spawnLeft--;spawnCooldown=Math.max(2,9-Math.floor(wave/4))}}
        var es=clone(enemies),ts=clone(towers)
        for(var ti=0;ti<ts.length;ti++){var t=ts[ti];if(t.cool>0){t.cool--;continue}var d=towerDefs[t.type],best=-1,bx=999;for(var ei=0;ei<es.length;ei++){var e=es[ei];if(e.lane===t.lane&&e.x>=t.cell&&e.x-t.cell<=towerRange(t)&&e.x<bx){best=ei;bx=e.x}}if(best>=0){var dmg=towerDamage(t);es[best]=applyDamage(es[best],dmg,t.type===3||t.type===5);if(t.type===2)es[best].slow=Math.max(es[best].slow,24+t.level*5);if(t.type===1){for(var j=0;j<es.length;j++)if(j!==best&&es[j].lane===t.lane&&Math.abs(es[j].x-es[best].x)<1.4)es[j]=applyDamage(es[j],dmg*0.45,false)}if(t.type===4){var chained=0;for(var k=0;k<es.length&&chained<2;k++)if(k!==best&&Math.abs(es[k].lane-es[best].lane)<=1&&Math.abs(es[k].x-es[best].x)<2.0){es[k]=applyDamage(es[k],dmg*0.55,false);chained++}}t.cool=Math.max(1,d.rate-Math.floor(t.level/2)-(overclockTicks>0?2:0))}ts[ti]=t}
        var alive=[];for(var i=0;i<es.length;i++){var en=es[i];if(en.regen&&en.hp>0&&en.hp<en.maxHp)en.hp=Math.min(en.maxHp,en.hp+0.08);if(en.hp<=0){var reward=Math.round(enemyDefs[en.type].reward*(1+economyResearch*0.08));credits+=reward;score+=reward*3;if(en.type===5){tech+=2;Achievements.unlock("circuit_boss_"+wave);Haptics.heavy()}continue}var mul=en.slow>0?0.52:1;if(en.slow>0)en.slow--;en.x-=en.speed*mul;if(en.x<=-0.15){var leak=en.type===5?5:(en.type===2?2:1);if(baseShield>0){var absorb=Math.min(baseShield,leak);baseShield-=absorb;leak-=absorb}if(leak>0)baseHp-=leak;Haptics.medium()}else alive.push(en)}enemies=alive;towers=ts
        if(baseHp<=0){running=false;paused=false;message="Circuit core destroyed";GameStats.submitHighScore(score);persist()}else if(spawnLeft===0&&enemies.length===0){running=false;credits+=35+wave*6;tech+=wave%3===0?1:0;baseShield=Math.min(10,baseShield+2);message="Wave clear · tech "+tech;GameStats.submitHighScore(wave,"best_wave");persist()}}

    function emp(){if(abilityCooldown>0||credits<45)return;credits-=45;abilityCooldown=160;var es=clone(enemies);for(var i=0;i<es.length;i++){es[i].slow=Math.max(es[i].slow,100);es[i].shield=Math.max(0,es[i].shield-6)}enemies=es;message="EMP discharged";Haptics.heavy()}
    function orbital(){if(orbitalCooldown>0||credits<100)return;credits-=100;orbitalCooldown=300;var es=clone(enemies);for(var i=0;i<es.length;i++)es[i]=applyDamage(es[i],18+damageResearch*4,true);enemies=es;message="Orbital strike";Haptics.heavy()}
    function overclock(){if(overclockTicks>0||credits<70)return;credits-=70;overclockTicks=180;message="Grid overclocked";Haptics.medium()}
    function repair(){if(credits<60||baseHp>=20)return;credits-=60;baseHp=Math.min(20,baseHp+5);baseShield=Math.min(10,baseShield+2);message="Core repaired";persist()}
    function research(which){if(tech<=0)return;tech--;if(which===0)damageResearch++;else if(which===1)rangeResearch++;else economyResearch++;Achievements.unlock("circuit_researcher");persist()}
    function cursorMove(dx,dy){var x=selectedGridCell(),y=selectedLane();x=Math.max(0,Math.min(cells-1,x+dx));y=Math.max(0,Math.min(lanes-1,y+dy));selectedCell=y*cells+x}

    function persist(){GameSave.set("credits",credits);GameSave.set("baseHp",baseHp);GameSave.set("baseShield",baseShield);GameSave.set("wave",wave);GameSave.set("score",score);GameSave.set("tech",tech);GameSave.set("damageResearch",damageResearch);GameSave.set("rangeResearch",rangeResearch);GameSave.set("economyResearch",economyResearch);GameSave.set("towers",towers);GameSave.set("selectedTower",selectedTower);GameSave.save("autosave")}
    function loadGame(){if(GameSave.load("autosave")){credits=Number(GameSave.get("credits",220));baseHp=Number(GameSave.get("baseHp",20));baseShield=Number(GameSave.get("baseShield",6));wave=Number(GameSave.get("wave",0));score=Number(GameSave.get("score",0));tech=Number(GameSave.get("tech",0));damageResearch=Number(GameSave.get("damageResearch",0));rangeResearch=Number(GameSave.get("rangeResearch",0));economyResearch=Number(GameSave.get("economyResearch",0));towers=GameSave.get("towers",[]);selectedTower=Number(GameSave.get("selectedTower",0))}}

    Rectangle{anchors.fill:parent;color:GameTheme.color("color.background")}
    Timer{interval:50;running:true;repeat:true;onTriggered:tick()}
    Connections{target:Lifecycle;function onSaveRequested(){persist()}function onBackgrounded(){paused=true;persist()}}
    Keys.priority:Keys.BeforeItem
    Keys.onPressed:function(e){if(e.key===Qt.Key_Left||e.key===Qt.Key_A)cursorMove(-1,0);else if(e.key===Qt.Key_Right||e.key===Qt.Key_D)cursorMove(1,0);else if(e.key===Qt.Key_Up||e.key===Qt.Key_W)cursorMove(0,-1);else if(e.key===Qt.Key_Down||e.key===Qt.Key_S)cursorMove(0,1);else if(e.key===Qt.Key_Return||e.key===Qt.Key_Enter)place(selectedLane(),selectedGridCell());else if(e.key===Qt.Key_Delete) sell(towerAt(selectedLane(),selectedGridCell()));else if(e.key===Qt.Key_Space)startWave();else if(e.key===Qt.Key_E)emp();else if(e.key===Qt.Key_O)orbital();else if(e.key===Qt.Key_Q)overclock();else if(e.key>=Qt.Key_1&&e.key<=Qt.Key_6)selectedTower=e.key-Qt.Key_1;else return;e.accepted=true}

    Column{anchors.fill:parent;anchors.margins:GameTheme.number("alias.page.padding");spacing:GameTheme.number("alias.page.gap")
        UiPanel{width:parent.width;implicitHeight:head.implicitHeight+GameTheme.number("alias.card.padding")*2;surfaceToken:"surface.panel"
            Flow{id:head;anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("alias.card.gap")
                ThemedSvgIcon{width:GameTheme.number("metric.icon.lg");height:width;source:Qt.resolvedUrl("assets/defense/tower.svg");tint:GameTheme.color("color.primary")}
                UiText{text:tr("title","Circuit Defense");font.bold:true;sizeToken:"metric.font.lg"} HudChip{label:tr("wave","Wave");value:String(wave)} HudChip{label:"Core";value:baseHp+" HP";valueColorToken:baseHp>6?"color.success":"color.danger"} HudChip{label:"Shield";value:String(baseShield);valueColorToken:"color.info"} HudChip{label:tr("credits","Credits");value:String(credits)} HudChip{label:"Tech";value:String(tech)}
            }
        }
        Flow{width:parent.width;spacing:GameTheme.number("alias.button.gap")
            Repeater{model:towerDefs.length;UiButton{required property int index;text:(index+1)+" "+towerDefs[index].name+" $"+towerDefs[index].cost;compact:true;primary:selectedTower===index;onActivated:selectedTower=index}}
            UiButton{text:running?(paused?"Resume":"Pause"):tr("start_wave","Start Wave");shortcutText:"Space";primary:true;onActivated:startWave()} UiButton{text:"EMP $45";shortcutText:"E";enabled:abilityCooldown<=0&&credits>=45;onActivated:emp()} UiButton{text:"Orbital $100";shortcutText:"O";enabled:orbitalCooldown<=0&&credits>=100;onActivated:orbital()} UiButton{text:"Overclock $70";shortcutText:"Q";enabled:overclockTicks<=0&&credits>=70;onActivated:overclock()} UiButton{text:tr("repair","Repair");enabled:credits>=60;onActivated:repair()}
        }
        UiPanel{width:parent.width;implicitHeight:info.implicitHeight+GameTheme.number("alias.card.padding")*2
            Row{id:info;anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("alias.card.gap")
                ThemedSvgIcon{width:GameTheme.number("metric.icon.md");height:width;source:Qt.resolvedUrl("assets/defense/tower.svg");tint:GameTheme.color(towerDefs[selectedTower].color)}
                Column{width:parent.width-GameTheme.number("metric.icon.md")-GameTheme.number("alias.card.gap");spacing:GameTheme.number("metric.space.xxxs")
                    UiText{text:towerDefs[selectedTower].name+" · "+towerDefs[selectedTower].desc;font.bold:true;colorToken:towerDefs[selectedTower].color}
                    UiText{text:"Damage research "+damageResearch+" · Range "+rangeResearch+" · Economy "+economyResearch+" · right-click/Delete sells";colorToken:"color.textMuted";sizeToken:"metric.font.sm"}
                }
            }
        }
        Item{id:field;width:parent.width;height:Math.max(GameTheme.number("metric.control.lg")*4,Math.min(parent.height*0.52,GameTheme.number("metric.control.lg")*6.4))
            Repeater{model:lanes*cells
                UiPanel{required property int index;property int lane:Math.floor(index/cells);property int cell:index%cells;property int towerIndex:root.towerAt(lane,cell);x:cell*(field.width/cells);y:lane*(field.height/lanes);width:field.width/cells-GameTheme.number("alias.gameTile.gap");height:field.height/lanes-GameTheme.number("alias.gameTile.gap");surfaceToken:"surface.gameTile";border.width:index===selectedCell?2:1;border.color:index===selectedCell?GameTheme.color("color.primary"):GameTheme.color("color.border")
                    ThemedSvgIcon{visible:parent.towerIndex>=0;anchors.centerIn:parent;width:parent.width*0.50;height:width;source:Qt.resolvedUrl("assets/defense/tower.svg");tint:parent.towerIndex>=0?GameTheme.color(root.towerDefs[root.towers[parent.towerIndex].type].color):GameTheme.color("color.textMuted")}
                    UiText{visible:parent.towerIndex>=0;anchors.right:parent.right;anchors.bottom:parent.bottom;text:"L"+(parent.towerIndex>=0?root.towers[parent.towerIndex].level:0);sizeToken:"metric.font.xs";font.bold:true}
                    TapHandler{acceptedButtons:Qt.LeftButton|Qt.RightButton;onTapped:function(eventPoint,button){root.forceActiveFocus();root.selectedCell=index;if(button===Qt.RightButton)root.sell(parent.towerIndex);else root.place(lane,cell)}}
                }
            }
            Repeater{model:enemies
                UiPanel{required property var modelData;width:Math.max(12,field.width/cells*0.48);height:Math.max(12,field.height/lanes*0.38);radius:height/2;color:GameTheme.color(root.enemyDefs[modelData.type].color);x:modelData.x*(field.width/cells);y:modelData.lane*(field.height/lanes)+(field.height/lanes-height)/2;border.width:modelData.type===5?2:1;border.color:modelData.type===5?GameTheme.color("color.primary"):GameTheme.color("color.border")
                    UiBar{anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.bottom;anchors.topMargin:GameTheme.number("metric.space.xxxs");height:GameTheme.number("metric.space.xxs");value:modelData.hp;to:modelData.maxHp;fillToken:"color.success"}
                }
            }
        }
        Flow{width:parent.width;spacing:GameTheme.number("alias.button.gap")
            UiText{text:"Research:";font.bold:true} UiButton{text:"Damage +";compact:true;enabled:tech>0;onActivated:research(0)} UiButton{text:"Range +";compact:true;enabled:tech>0;onActivated:research(1)} UiButton{text:"Economy +";compact:true;enabled:tech>0;onActivated:research(2)}
        }
        UiText{width:parent.width;text:message+(showHints?" · Build/upgrade by click/tap. Right-click or Delete sells. Keyboard: WASD/arrows, Enter, 1–6, Space, E, O, Q.":"");horizontalAlignment:Text.AlignHCenter;colorToken:"color.textMuted";sizeToken:"metric.font.xs"}
    }
    Connections{target:GameInput;function onActionPressed(action,value){if(action==="move_left")cursorMove(-1,0);else if(action==="move_right")cursorMove(1,0);else if(action==="up")cursorMove(0,-1);else if(action==="down")cursorMove(0,1);else if(action==="fire")place(selectedLane(),selectedGridCell());else if(action==="pause")startWave();else if(action==="ability")emp()}}
    Component.onCompleted:{GameRandom.seed("circuit-defense-v64");loadGame();forceActiveFocus()}
}
