import QtQuick

Item {
    id: root
    property real coins: 100
    property real ore: 0
    property real parts: 0
    property real circuits: 0
    property real goods: 0
    property real robots: 0
    property int research: 0
    property int reputation: 0
    property int crowns: 0
    property int storageLevel: 1
    property int efficiencyLevel: 0
    property var lines: [{level:1,manager:false,progress:0},{level:1,manager:false,progress:0},{level:1,manager:false,progress:0},{level:1,manager:false,progress:0},{level:1,manager:false,progress:0},{level:1,manager:false,progress:0}]
    property var contract: ({kind:"goods",amount:10,progress:0,reward:120,research:2})
    property string message: ""
    property bool running: true
    property bool showHints: Boolean(GameSettings.value("showHints",true))
    property double lastPersistMs: 0

    readonly property var lineDefs: [
        {id:"mine",nameKey:"line_mine",name:"Ore Drill",icon:"◆"},
        {id:"smelter",nameKey:"line_smelter",name:"Smelter",icon:"▰"},
        {id:"circuit",nameKey:"line_circuit",name:"Circuit Lab",icon:"⌁"},
        {id:"assembly",nameKey:"line_assembly",name:"Assembly",icon:"▣"},
        {id:"robotics",nameKey:"line_robotics",name:"Robotics",icon:"♜"},
        {id:"export",nameKey:"line_export",name:"Export Dock",icon:"⇧"}
    ]

    function tr(k,f){return GameI18n.text(k,f)}
    function freshLines(){var a=[];for(var i=0;i<lineDefs.length;i++)a.push({level:1,manager:false,progress:0});return a}
    function storageCap(){return 50+storageLevel*75+crowns*25}
    function prestigeMultiplier(){return 1+crowns*0.20}
    function speedFor(i){return (0.18+lines[i].level*0.055)*(1+efficiencyLevel*0.08)*prestigeMultiplier()}
    function upgradeCost(i){return Math.round((40+i*50)*Math.pow(1.65,lines[i].level-1))}
    function managerCost(i){return Math.round(250*Math.pow(2.1,i)*(1+crowns*0.1))}
    function storageCost(){return Math.round(350*Math.pow(1.8,storageLevel-1))}
    function efficiencyCost(){return 5+efficiencyLevel*4}
    function fmt(v){if(v>=1000000)return (v/1000000).toFixed(1)+"M";if(v>=1000)return (v/1000).toFixed(1)+"K";return Math.floor(v).toString()}

    function hasInputs(i){
        if(i===0)return ore<storageCap()
        if(i===1)return ore>=2&&parts<storageCap()
        if(i===2)return ore>=2&&parts>=1&&circuits<storageCap()
        if(i===3)return parts>=2&&circuits>=1&&goods<storageCap()
        if(i===4)return goods>=2&&circuits>=2&&robots<storageCap()
        return robots>=1
    }
    function produce(i){
        if(!hasInputs(i))return false
        var yield=Math.max(1,Math.floor((1+(lines[i].level-1)*0.25)*prestigeMultiplier()))
        if(i===0)ore=Math.min(storageCap(),ore+yield)
        else if(i===1){ore-=2;parts=Math.min(storageCap(),parts+yield)}
        else if(i===2){ore-=2;parts-=1;circuits=Math.min(storageCap(),circuits+yield)}
        else if(i===3){parts-=2;circuits-=1;goods=Math.min(storageCap(),goods+yield);advanceContract("goods",yield)}
        else if(i===4){goods-=2;circuits-=2;robots=Math.min(storageCap(),robots+yield);advanceContract("robots",yield)}
        else {robots-=1;var income=(28+lines[i].level*7)*prestigeMultiplier();coins+=income;reputation++;advanceContract("exports",1);GameStats.increment("factory_exports")}
        if(i===1)advanceContract("parts",yield)
        return true
    }
    function manualRun(i){if(produce(i)){GameStats.increment("manual_cycles");Haptics.light();message=tr(lineDefs[i].nameKey,lineDefs[i].name)+" ✓";persist()}else{message="Missing input / storage full"}}
    function tick(){
        if(!running||!lines.length)return
        var a=lines.slice(),changed=false
        for(var i=0;i<a.length;i++)if(a[i].manager){var old=a[i],l={level:old.level,manager:old.manager,progress:old.progress};l.progress+=speedFor(i)*0.20;if(l.progress>=1){if(produce(i)){l.progress-=1;changed=true}else l.progress=0.95}a[i]=l}
        if(changed||a.length)lines=a
    }
    function upgradeLine(i){var c=upgradeCost(i);if(coins<c)return;coins-=c;var a=lines.slice(),old=a[i],l={level:old.level,manager:old.manager,progress:old.progress};l.level++;a[i]=l;lines=a;GameStats.increment("line_upgrades");if(l.level>=10)Achievements.unlock("industrial_line_10");Haptics.medium();persist()}
    function hireManager(i){var c=managerCost(i);if(lines[i].manager||coins<c)return;coins-=c;var a=lines.slice(),old=a[i],l={level:old.level,manager:old.manager,progress:old.progress};l.manager=true;a[i]=l;lines=a;GameStats.increment("managers_hired");if(i===5)Achievements.unlock("fully_automated");Haptics.medium();persist()}
    function upgradeStorage(){var c=storageCost();if(coins<c)return;coins-=c;storageLevel++;GameStats.increment("storage_upgrades");persist()}
    function researchEfficiency(){var c=efficiencyCost();if(research<c)return;research-=c;efficiencyLevel++;GameStats.increment("research_bought");persist()}

    function newContract(){
        var kinds=["goods","robots","parts","exports"],k=kinds[GameRandom.nextInt(0,kinds.length-1)],base=k==="robots"?4:k==="exports"?6:12
        var amount=base+GameRandom.nextInt(0,base)+Math.floor(reputation/12)
        contract={kind:k,amount:amount,progress:0,reward:Math.round(amount*(k==="robots"?55:k==="exports"?38:16)*prestigeMultiplier()),research:2+Math.floor(amount/8)}
        persist()
    }
    function advanceContract(kind,amount){
        if(contract.kind!==kind)return
        var c={kind:contract.kind,amount:contract.amount,progress:contract.progress,reward:contract.reward,research:contract.research};c.progress=Math.min(c.amount,c.progress+amount);contract=c
        if(c.progress>=c.amount){coins+=c.reward;research+=c.research;reputation+=3;GameStats.increment("contracts_completed");Achievements.unlock(GameStats.counter("contracts_completed")>=10?"contracts_10":"first_contract");message="Contract +"+c.reward;Haptics.heavy();newContract()}
    }
    function prestige(){
        var need=10000*Math.pow(2,crowns);if(coins<need)return
        crowns++;coins=100;ore=parts=circuits=goods=robots=0;research=0;storageLevel=1;efficiencyLevel=0;lines=freshLines();newContract();Achievements.unlock("first_crown");GameStats.increment("prestiges");message="Crown +1 · production multiplier "+prestigeMultiplier().toFixed(1)+"x";persist()
    }
    function applyOfflineIncome(savedMs){
        var now=Date.now(),elapsed=Math.max(0,Math.min(4*60*60*1000,now-savedMs));if(elapsed<60000||!lines.length)return
        var exportLine=lines[5];if(!exportLine.manager)return
        var mins=elapsed/60000,estimated=mins*(2+exportLine.level*0.7)*prestigeMultiplier();coins+=estimated;message="Offline +"+fmt(estimated)+" coins";GameStats.increment("offline_minutes",Math.floor(mins))
    }
    function persist(){
        lastPersistMs=Date.now();GameSave.set("coins",coins);GameSave.set("ore",ore);GameSave.set("parts",parts);GameSave.set("circuits",circuits);GameSave.set("goods",goods);GameSave.set("robots",robots);GameSave.set("research",research);GameSave.set("reputation",reputation);GameSave.set("crowns",crowns);GameSave.set("storageLevel",storageLevel);GameSave.set("efficiencyLevel",efficiencyLevel);GameSave.set("lines",lines);GameSave.set("contract",contract);GameSave.set("lastPersistMs",lastPersistMs);GameSave.save("autosave")
    }
    function loadGame(){
        if(GameSave.load("autosave")){
            coins=GameSave.get("coins",100);ore=GameSave.get("ore",0);parts=GameSave.get("parts",0);circuits=GameSave.get("circuits",0);goods=GameSave.get("goods",0);robots=GameSave.get("robots",0);research=GameSave.get("research",0);reputation=GameSave.get("reputation",0);crowns=GameSave.get("crowns",0);storageLevel=GameSave.get("storageLevel",1);efficiencyLevel=GameSave.get("efficiencyLevel",0);lines=GameSave.get("lines",[]);contract=GameSave.get("contract",contract);var saved=GameSave.get("lastPersistMs",Date.now());if(lines.length!==6)lines=freshLines();applyOfflineIncome(saved)
        } else {lines=freshLines();newContract()}
        persist()
    }

    Timer{interval:200;repeat:true;running:true;onTriggered:root.tick()}
    Timer{interval:10000;repeat:true;running:true;onTriggered:root.persist()}
    Rectangle{anchors.fill:parent;color:GameTheme.color("color.background")}
    Flickable{anchors.fill:parent;contentWidth:width;contentHeight:content.implicitHeight+GameTheme.number("alias.page.padding")*2;clip:true
        Column{id:content;width:parent.width-GameTheme.number("alias.page.padding")*2;x:GameTheme.number("alias.page.padding");y:x;spacing:GameTheme.number("alias.page.gap")
            Flow{width:parent.width;spacing:GameTheme.number("metric.space.md")
                UiText{text:tr("title","Pocket Factory");font.bold:true;sizeToken:"metric.font.lg"}
                UiText{text:tr("coins","Coins")+" "+root.fmt(root.coins);colorToken:"color.accent"}
                UiText{text:tr("research","Research")+" "+root.research;colorToken:"color.info"}
                UiText{text:"REP "+root.reputation}
                UiText{text:"Crown "+root.crowns+" · "+root.prestigeMultiplier().toFixed(1)+"x";colorToken:"color.primary"}
            }
            UiPanel{width:parent.width;implicitHeight:inventoryFlow.implicitHeight+GameTheme.number("alias.card.padding")*2
                Flow{id:inventoryFlow;anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("metric.space.md")
                    UiText{text:"Ore "+root.fmt(root.ore)} UiText{text:"Parts "+root.fmt(root.parts)} UiText{text:"Circuits "+root.fmt(root.circuits)} UiText{text:"Goods "+root.fmt(root.goods)} UiText{text:"Robots "+root.fmt(root.robots)} UiText{text:"Cap "+root.storageCap();colorToken:"color.textMuted"}
                }
            }
            UiPanel{width:parent.width;implicitHeight:contractCol.implicitHeight+GameTheme.number("alias.card.padding")*2;surfaceToken:"surface.panel"
                Column{id:contractCol;anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("metric.space.xs")
                    Row{spacing:GameTheme.number("metric.space.md");UiText{text:tr("contracts","Contracts");font.bold:true}UiText{text:root.contract.kind.toUpperCase()+" "+Math.floor(root.contract.progress)+"/"+root.contract.amount;colorToken:"color.primary"}UiText{text:"Reward "+root.contract.reward+" +"+root.contract.research+"R";colorToken:"color.accent"}}
                    UiBar{width:parent.width;value:root.contract.progress;maximum:root.contract.amount;colorToken:"color.primary"}
                }
            }
            Repeater{model:root.lineDefs
                UiPanel{required property var modelData;required property int index;width:content.width;implicitHeight:lineCol.implicitHeight+GameTheme.number("alias.card.padding")*2
                    Column{id:lineCol;anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("metric.space.xs")
                        Flow{width:parent.width;spacing:GameTheme.number("metric.space.md")
                            UiText{text:modelData.icon+"  "+root.tr(modelData.nameKey,modelData.name);font.bold:true;sizeToken:"metric.font.md"}
                            UiText{text:"Lv "+root.lines[index].level;colorToken:"color.accent"}
                            UiText{text:root.lines[index].manager?"MANAGER ✓":"Manual";colorToken:root.lines[index].manager?"color.success":"color.textMuted"}
                            UiText{text:"Speed "+root.speedFor(index).toFixed(2)+"/s";colorToken:"color.info"}
                        }
                        UiBar{visible:root.lines[index].manager;width:parent.width;value:root.lines[index].progress;maximum:1;colorToken:"color.primary"}
                        Flow{width:parent.width;spacing:GameTheme.number("metric.space.sm")
                            UiButton{text:root.tr("run","Run");enabled:root.hasInputs(index);onActivated:root.manualRun(index)}
                            UiButton{text:tr("upgrade","Upgrade")+" "+root.upgradeCost(index);enabled:root.coins>=root.upgradeCost(index);onActivated:root.upgradeLine(index)}
                            UiButton{text:root.lines[index].manager?tr("active","Active"):tr("manager","Manager")+" "+root.managerCost(index);enabled:!root.lines[index].manager&&root.coins>=root.managerCost(index);onActivated:root.hireManager(index)}
                        }
                    }
                }
            }
            UiPanel{width:parent.width;implicitHeight:researchCol.implicitHeight+GameTheme.number("alias.card.padding")*2
                Column{id:researchCol;anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("metric.space.sm")
                    UiText{text:tr("research","Research")+" & Infrastructure";font.bold:true}
                    Flow{width:parent.width;spacing:GameTheme.number("metric.space.sm")
                        UiButton{text:"Storage Lv"+root.storageLevel+" · "+root.storageCost();enabled:root.coins>=root.storageCost();onActivated:root.upgradeStorage()}
                        UiButton{text:"Efficiency +8% · "+root.efficiencyCost()+"R";enabled:root.research>=root.efficiencyCost();onActivated:root.researchEfficiency()}
                        UiButton{text:"Prestige Crown · "+root.fmt(10000*Math.pow(2,root.crowns));enabled:root.coins>=10000*Math.pow(2,root.crowns);primary:true;onActivated:root.prestige()}
                    }
                }
            }
            UiText{width:parent.width;text:root.message;colorToken:"color.textMuted";horizontalAlignment:Text.AlignHCenter}
            UiText{visible:root.showHints;width:parent.width;text:tr("controls_hint","Build a chain: Ore → Parts → Circuits → Goods → Robots → Export. Managers automate lines; research and Crowns multiply long-term output.");colorToken:"color.textMuted";horizontalAlignment:Text.AlignHCenter}
        }
    }
    Keys.onPressed: function(e) {
        if (e.key >= Qt.Key_1 && e.key <= Qt.Key_6) { manualRun(e.key - Qt.Key_1); e.accepted = true }
        else if (e.key === Qt.Key_S) { upgradeStorage(); e.accepted = true }
        else if (e.key === Qt.Key_R && research >= efficiencyCost()) { researchEfficiency(); e.accepted = true }
    }

    Component.onCompleted:{GameRandom.seed("pocket-factory-v3");loadGame()}
    Component.onDestruction:persist()
}
