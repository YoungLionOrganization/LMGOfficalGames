import QtQuick

FocusScope {
    id: root
    focus: true
    readonly property int cols: 14
    readonly property int rows: 9
    property int px: 1
    property int py: 4
    property int fuel: 42
    property int maxFuel: 42
    property int hull: 14
    property int maxHull: 14
    property int shield: 4
    property int maxShield: 4
    property int credits: 100
    property int reputation: 0
    property int sector: 1
    property int engineLevel: 1
    property int cargoLevel: 1
    property int shieldLevel: 0
    property int weaponLevel: 1
    property int scannerLevel: 1
    property int deliveries: 0
    property int sectorDeliveries: 0
    property int turn: 0
    property var hazards: []
    property var stations: []
    property var pirates: []
    property var discovered: []
    property var offers: []
    property var contract: ({active:false,sx:0,sy:0,tx:0,ty:0,reward:0,cargo:"",size:0,picked:false,deadline:0})
    property string message: tr("ready","Dock at a station, accept a contract and deliver it across the sector.")
    readonly property bool showHints:Boolean(GameSettings.value("showHints",true))
    readonly property int cargoCapacity: 2+cargoLevel
    readonly property var cargoNames:["Medical Kit","Data Core","Fusion Cells","Research Samples","Nano Parts","Seeds","Cryo Medicine","Quantum Lens"]

    function tr(k,f){return GameI18n.text(k,f)}
    function idx(x,y){return y*cols+x}
    function inside(x,y){return x>=0&&y>=0&&x<cols&&y<rows}
    function clone(v){return JSON.parse(JSON.stringify(v))}
    function dist(x1,y1,x2,y2){return Math.abs(x1-x2)+Math.abs(y1-y2)}
    function hazardAt(x,y){for(var i=0;i<hazards.length;i++)if(hazards[i].x===x&&hazards[i].y===y)return hazards[i];return null}
    function stationAt(x,y){for(var i=0;i<stations.length;i++)if(stations[i].x===x&&stations[i].y===y)return stations[i];return null}
    function pirateAt(x,y){for(var i=0;i<pirates.length;i++)if(pirates[i].x===x&&pirates[i].y===y&&pirates[i].hp>0)return i;return -1}
    function gate(){return {x:cols-2,y:Math.floor(rows/2)}}
    function cellIcon(x,y,hz,st,pirateIndex){
        if(x===px&&y===py)return Qt.resolvedUrl("assets/space/ship.svg")
        if(st!==null)return Qt.resolvedUrl("assets/space/station.svg")
        if(pirateIndex>=0)return Qt.resolvedUrl("assets/space/pirate.svg")
        if(x===gate().x&&y===gate().y)return Qt.resolvedUrl("assets/space/gate.svg")
        return Qt.resolvedUrl("assets/space/meteor.svg")
    }
    function cellTint(x,y,hz,st,pirateIndex){
        if(x===px&&y===py)return GameTheme.color("color.primary")
        if(st!==null)return GameTheme.color("color.success")
        if(pirateIndex>=0)return GameTheme.color("color.danger")
        if(x===gate().x&&y===gate().y)return GameTheme.color("color.accent")
        if(hz&&hz.type==="salvage")return GameTheme.color("color.special")
        return GameTheme.color("color.textMuted")
    }
    function isDiscovered(x,y){return Boolean(discovered[idx(x,y)])}
    function reveal(radius){var d=discovered.slice();while(d.length<cols*rows)d.push(false);for(var y=Math.max(0,py-radius);y<=Math.min(rows-1,py+radius);y++)for(var x=Math.max(0,px-radius);x<=Math.min(cols-1,px+radius);x++)if(dist(px,py,x,y)<=radius+1)d[idx(x,y)]=true;discovered=d}

    function buildSector(){
        hazards=[];pirates=[];discovered=[];offers=[];contract={active:false,sx:0,sy:0,tx:0,ty:0,reward:0,cargo:"",size:0,picked:false,deadline:0}
        stations=[{x:1,y:1,name:"North Hub"},{x:1,y:rows-2,name:"South Hub"},{x:cols-4,y:1,name:"Relay"},{x:cols-4,y:rows-2,name:"Frontier"}]
        var h=[]
        for(var i=0;i<12+sector*2;i++){var x=GameRandom.nextInt(2,cols-3),y=GameRandom.nextInt(0,rows-1);if(stationAt(x,y)||dist(x,y,px,py)<2||(x===gate().x&&y===gate().y))continue;var duplicate=false;for(var j=0;j<h.length;j++)if(h[j].x===x&&h[j].y===y)duplicate=true;if(duplicate)continue;var roll=GameRandom.nextReal();h.push({x:x,y:y,type:roll<0.42?"meteor":(roll<0.74?"storm":"salvage"),spent:false})}hazards=h
        var ps=[];for(var p=0;p<Math.min(7,1+Math.floor(sector*1.4));p++){var px2=GameRandom.nextInt(4,cols-3),py2=GameRandom.nextInt(0,rows-1);if(hazardAt(px2,py2)||stationAt(px2,py2))continue;ps.push({x:px2,y:py2,hp:5+sector*3,maxHp:5+sector*3,level:sector,reward:16+sector*7})}pirates=ps
        sectorDeliveries=0;px=1;py=Math.floor(rows/2);fuel=maxFuel;shield=maxShield;reveal(2+scannerLevel);message="Sector "+sector+" ready · complete 3 deliveries to unlock the jump gate";generateOffers();persist()
    }

    function generateOffers(){var list=[];for(var n=0;n<3;n++){var a=stations[GameRandom.nextInt(0,stations.length-1)],b=stations[GameRandom.nextInt(0,stations.length-1)];var guard=0;while(b===a&&guard++<10)b=stations[GameRandom.nextInt(0,stations.length-1)];var size=1+GameRandom.nextInt(0,Math.min(2,cargoLevel)),cargo=cargoNames[GameRandom.nextInt(0,Math.min(cargoNames.length-1,3+sector))],distance=dist(a.x,a.y,b.x,b.y),deadline=turn+distance+7+engineLevel*2;list.push({sx:a.x,sy:a.y,tx:b.x,ty:b.y,reward:45+sector*15+distance*6+size*10,cargo:cargo,size:size,deadline:deadline})}offers=list}
    function acceptOffer(i){if(contract.active||i<0||i>=offers.length)return;var o=offers[i];if(o.size>cargoCapacity){message="Cargo hold too small · upgrade at a station";return}contract={active:true,sx:o.sx,sy:o.sy,tx:o.tx,ty:o.ty,reward:o.reward,cargo:o.cargo,size:o.size,picked:false,deadline:o.deadline};message="Contract accepted: pick up "+o.cargo;Haptics.light();persist()}

    function move(dx,dy){root.forceActiveFocus();var nx=px+dx,ny=py+dy;if(!inside(nx,ny)){message="Sector boundary";return}if(fuel<=0){message="Out of fuel · emergency tow available at 20 credits";return}var pirateIndex=pirateAt(nx,ny);if(pirateIndex>=0){message="Pirate blocks the route · use FIRE";Haptics.medium();return}var cost=Math.max(1,2-Math.floor(engineLevel/3));fuel=Math.max(0,fuel-cost);px=nx;py=ny;turn++;reveal(1+scannerLevel);resolveCell();pirateTurn();resolveContract();if(contract.active&&turn>contract.deadline){message="Contract expired · reputation -1";reputation=Math.max(0,reputation-1);contract.active=false;generateOffers()}persist()}
    function resolveCell(){var h=hazardAt(px,py);if(!h||h.spent)return;if(h.type==="salvage"){h.spent=true;credits+=12+sector*5;message="Salvage recovered · credits +"+(12+sector*5);Haptics.light();return}var raw=h.type==="storm"?2:3,damage=Math.max(0,raw-shieldLevel);if(shield>0){var absorb=Math.min(shield,damage);shield-=absorb;damage-=absorb}if(damage>0){hull-=damage;Haptics.medium()}if(h.type==="storm")fuel=Math.max(0,fuel-2);message=h.type==="storm"?"Ion storm drained ship systems":"Meteor impact";if(hull<=0)rescue()}
    function rescue(){credits=Math.max(0,credits-35);hull=maxHull;shield=Math.floor(maxShield/2);fuel=Math.floor(maxFuel/2);px=1;py=Math.floor(rows/2);contract.active=false;message="Rescue tug recovered the ship · 35 credit fee";GameStats.increment("rescues")}

    function pirateTurn(){var ps=clone(pirates);for(var i=0;i<ps.length;i++){var p=ps[i];if(p.hp<=0)continue;var d=dist(p.x,p.y,px,py);if(d===1){var damage=1+Math.floor(sector/3);if(shield>0){var a=Math.min(shield,damage);shield-=a;damage-=a}if(damage>0)hull-=damage;message="Pirate fire!";continue}if(d<=4){var dx=px===p.x?0:(px>p.x?1:-1),dy=py===p.y?0:(py>p.y?1:-1);var nx=p.x,ny=p.y;if(Math.abs(px-p.x)>=Math.abs(py-p.y))nx+=dx;else ny+=dy;if(inside(nx,ny)&&stationAt(nx,ny)===null&&pirateAt(nx,ny)<0&&!(nx===px&&ny===py)){p.x=nx;p.y=ny}}ps[i]=p}pirates=ps;if(hull<=0)rescue()}
    function fire(){var best=-1,bestDist=99;for(var i=0;i<pirates.length;i++){if(pirates[i].hp<=0)continue;var d=dist(px,py,pirates[i].x,pirates[i].y);if(d<=1+Math.floor(weaponLevel/2)&&d<bestDist){best=i;bestDist=d}}if(best<0){message="No pirate in weapon range";return}var ps=clone(pirates),damage=3+weaponLevel*2;ps[best].hp-=damage;if(ps[best].hp<=0){credits+=ps[best].reward;reputation++;GameStats.increment("pirates_defeated");message="Pirate disabled · +"+ps[best].reward+" credits";Haptics.heavy()}else{message="Laser hit · pirate HP "+ps[best].hp;Haptics.light()}pirates=ps;turn++;pirateTurn();persist()}
    function scan(){var cost=Math.max(1,4-scannerLevel);if(fuel<cost)return;fuel-=cost;reveal(3+scannerLevel);message="Scanner pulse revealed nearby routes";GameStats.increment("scans");persist()}

    function resolveContract(){if(!contract.active)return;if(px===contract.sx&&py===contract.sy&&!contract.picked){contract.picked=true;message="Cargo loaded: "+contract.cargo;Haptics.light()}else if(px===contract.tx&&py===contract.ty&&contract.picked){var bonus=turn<=contract.deadline?Math.round(contract.reward*0.20):0;credits+=contract.reward+bonus;deliveries++;sectorDeliveries++;reputation+=2;GameStats.increment("deliveries");GameStats.submitHighScore(credits,"credits");message="Delivery complete · +"+(contract.reward+bonus)+" credits";contract.active=false;generateOffers();if(sectorDeliveries>=3)Achievements.unlock("courier_sector_ready_"+sector);Haptics.heavy()}}
    function jumpSector(){var g=gate();if(px!==g.x||py!==g.y){message="Move to the jump gate first";return}if(sectorDeliveries<3){message="Complete "+(3-sectorDeliveries)+" more deliveries first";return}sector++;GameStats.submitHighScore(sector,"best_sector");Achievements.unlock("courier_sector_"+sector);buildSector()}

    function refuel(){if(!stationAt(px,py)){message="Dock at a station";return}var need=maxFuel-fuel,cost=Math.min(credits,need);credits-=cost;fuel+=cost;shield=maxShield;message="Refueled and shields recharged";persist()}
    function repair(){if(!stationAt(px,py))return;var need=maxHull-hull,points=Math.min(need,Math.floor(credits/3));credits-=points*3;hull+=points;message="Hull repaired +"+points;persist()}
    function upgrade(which){if(!stationAt(px,py)){message="Upgrades require a station";return}var total=engineLevel+cargoLevel+shieldLevel+weaponLevel+scannerLevel,cost=85+total*30;if(credits<cost){message="Need "+cost+" credits";return}credits-=cost;if(which===0){engineLevel++;maxFuel+=4;fuel=maxFuel}else if(which===1)cargoLevel++;else if(which===2){shieldLevel++;maxShield+=2;shield=maxShield;maxHull+=1;hull=maxHull}else if(which===3)weaponLevel++;else scannerLevel++;message="Ship system upgraded";persist()}

    function persist(){GameSave.set("px",px);GameSave.set("py",py);GameSave.set("fuel",fuel);GameSave.set("maxFuel",maxFuel);GameSave.set("hull",hull);GameSave.set("maxHull",maxHull);GameSave.set("shield",shield);GameSave.set("maxShield",maxShield);GameSave.set("credits",credits);GameSave.set("reputation",reputation);GameSave.set("sector",sector);GameSave.set("engineLevel",engineLevel);GameSave.set("cargoLevel",cargoLevel);GameSave.set("shieldLevel",shieldLevel);GameSave.set("weaponLevel",weaponLevel);GameSave.set("scannerLevel",scannerLevel);GameSave.set("deliveries",deliveries);GameSave.set("sectorDeliveries",sectorDeliveries);GameSave.set("turn",turn);GameSave.set("hazards",hazards);GameSave.set("stations",stations);GameSave.set("pirates",pirates);GameSave.set("discovered",discovered);GameSave.set("offers",offers);GameSave.set("contract",contract);GameSave.save("autosave")}
    function loadGame(){if(GameSave.load("autosave")){px=Number(GameSave.get("px",1));py=Number(GameSave.get("py",4));fuel=Number(GameSave.get("fuel",42));maxFuel=Number(GameSave.get("maxFuel",42));hull=Number(GameSave.get("hull",14));maxHull=Number(GameSave.get("maxHull",14));shield=Number(GameSave.get("shield",4));maxShield=Number(GameSave.get("maxShield",4));credits=Number(GameSave.get("credits",100));reputation=Number(GameSave.get("reputation",0));sector=Number(GameSave.get("sector",1));engineLevel=Number(GameSave.get("engineLevel",1));cargoLevel=Number(GameSave.get("cargoLevel",1));shieldLevel=Number(GameSave.get("shieldLevel",0));weaponLevel=Number(GameSave.get("weaponLevel",1));scannerLevel=Number(GameSave.get("scannerLevel",1));deliveries=Number(GameSave.get("deliveries",0));sectorDeliveries=Number(GameSave.get("sectorDeliveries",0));turn=Number(GameSave.get("turn",0));hazards=GameSave.get("hazards",[]);stations=GameSave.get("stations",[]);pirates=GameSave.get("pirates",[]);discovered=GameSave.get("discovered",[]);offers=GameSave.get("offers",[]);contract=GameSave.get("contract",contract)}if(stations.length===0)buildSector();reveal(1+scannerLevel);if(offers.length===0)generateOffers()}

    Rectangle{anchors.fill:parent;color:GameTheme.color("color.background")}
    Connections{target:Lifecycle;function onSaveRequested(){persist()}function onBackgrounded(){persist()}}
    Keys.priority:Keys.BeforeItem
    Keys.onPressed:function(e){if(e.key===Qt.Key_Left||e.key===Qt.Key_A)move(-1,0);else if(e.key===Qt.Key_Right||e.key===Qt.Key_D)move(1,0);else if(e.key===Qt.Key_Up||e.key===Qt.Key_W)move(0,-1);else if(e.key===Qt.Key_Down||e.key===Qt.Key_S)move(0,1);else if(e.key===Qt.Key_Space||e.key===Qt.Key_F)fire();else if(e.key===Qt.Key_E)scan();else if(e.key===Qt.Key_R)refuel();else if(e.key===Qt.Key_J)jumpSector();else return;e.accepted=true}

    Flickable{anchors.fill:parent;contentWidth:width;contentHeight:body.implicitHeight+GameTheme.number("alias.page.padding")*2;clip:true
        Column{id:body;width:parent.width-GameTheme.number("alias.page.padding")*2;x:GameTheme.number("alias.page.padding");y:GameTheme.number("alias.page.padding");spacing:GameTheme.number("alias.page.gap")
            UiPanel{width:parent.width;implicitHeight:head.implicitHeight+GameTheme.number("alias.card.padding")*2;surfaceToken:"surface.panel"
                Flow{id:head;anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("alias.card.gap")
                    ThemedSvgIcon{width:GameTheme.number("metric.icon.lg");height:width;source:Qt.resolvedUrl("assets/space/ship.svg");tint:GameTheme.color("color.primary")}
                    UiText{text:tr("title","Astro Courier");font.bold:true;sizeToken:"metric.font.lg"} HudChip{label:tr("sector","Sector");value:String(sector)} HudChip{label:tr("credits","Credits");value:String(credits)} HudChip{label:tr("fuel","Fuel");value:fuel+"/"+maxFuel;valueColorToken:fuel>8?"color.success":"color.danger"} HudChip{label:"Hull";value:hull+"/"+maxHull} HudChip{label:"Shield";value:shield+"/"+maxShield;valueColorToken:"color.info"} HudChip{label:"Rep";value:String(reputation)}
                }
            }
            UiPanel{width:parent.width;implicitHeight:contractCol.implicitHeight+GameTheme.number("alias.card.padding")*2
                Column{id:contractCol;anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("metric.space.xs")
                    UiText{text:contract.active?("ACTIVE · "+contract.cargo+" ×"+contract.size+" · "+(contract.picked?"Deliver":"Pick up")+" · "+contract.reward+" cr"):("CONTRACT BOARD · choose one while docked");font.bold:true;colorToken:contract.active?"color.accent":"color.text"}
                    UiText{visible:contract.active;text:"Route ("+contract.sx+","+contract.sy+") → ("+contract.tx+","+contract.ty+") · deadline turn "+contract.deadline+" · now "+turn;colorToken:"color.textMuted";sizeToken:"metric.font.sm"}
                    Flow{visible:!contract.active&&stationAt(px,py)!==null;width:parent.width;spacing:GameTheme.number("alias.button.gap");Repeater{model:offers.length;UiButton{required property int index;text:(index+1)+" "+offers[index].cargo+" · "+offers[index].reward+"cr";compact:true;enabled:offers[index].size<=cargoCapacity;onActivated:acceptOffer(index)}}}
                }
            }
            Item{id:map;width:parent.width;height:Math.max(GameTheme.number("metric.control.lg")*5,Math.min(root.height*0.52,GameTheme.number("metric.control.lg")*7.5))
                Repeater{model:cols*rows
                    UiPanel{required property int index;property int gx:index%cols;property int gy:Math.floor(index/cols);property bool seen:root.isDiscovered(gx,gy);property var hz:seen?root.hazardAt(gx,gy):null;property var st:seen?root.stationAt(gx,gy):null;property int pirateIndex:seen?root.pirateAt(gx,gy):-1;x:gx*(map.width/cols);y:gy*(map.height/rows);width:map.width/cols-GameTheme.number("alias.gameTile.gap");height:map.height/rows-GameTheme.number("alias.gameTile.gap");surfaceToken:"surface.gameTile";opacity:seen?1:0.35
                        ThemedSvgIcon{anchors.centerIn:parent;width:parent.width*0.58;height:width;visible:(gx===root.px&&gy===root.py)||parent.st!==null||parent.hz!==null||parent.pirateIndex>=0||(gx===root.gate().x&&gy===root.gate().y);source:root.cellIcon(gx,gy,parent.hz,parent.st,parent.pirateIndex);tint:root.cellTint(gx,gy,parent.hz,parent.st,parent.pirateIndex)}
                        TapHandler{onTapped:{root.forceActiveFocus();var dx=gx-root.px,dy=gy-root.py;if(Math.abs(dx)+Math.abs(dy)===1)root.move(dx,dy)}}
                    }
                }
            }
            Flow{width:parent.width;spacing:GameTheme.number("alias.button.gap")
                UiButton{text:"FIRE";shortcutText:"Space";primary:true;onActivated:fire()} UiButton{text:"SCAN";shortcutText:"E";onActivated:scan()} UiButton{text:"Refuel";shortcutText:"R";enabled:stationAt(px,py)!==null;onActivated:refuel()} UiButton{text:tr("repair","Repair");enabled:stationAt(px,py)!==null;onActivated:repair()} UiButton{text:"JUMP";shortcutText:"J";enabled:px===gate().x&&py===gate().y&&sectorDeliveries>=3;onActivated:jumpSector()}
            }
            UiPanel{width:parent.width;implicitHeight:shipFlow.implicitHeight+GameTheme.number("alias.card.padding")*2
                Flow{id:shipFlow;anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("alias.button.gap")
                    UiText{text:"Ship systems · Cargo "+cargoCapacity+" · Sector deliveries "+sectorDeliveries+"/3";font.bold:true}
                    UiButton{text:"Engine Lv "+engineLevel;compact:true;enabled:stationAt(px,py)!==null;onActivated:upgrade(0)} UiButton{text:"Cargo Lv "+cargoLevel;compact:true;enabled:stationAt(px,py)!==null;onActivated:upgrade(1)} UiButton{text:"Shield Lv "+shieldLevel;compact:true;enabled:stationAt(px,py)!==null;onActivated:upgrade(2)} UiButton{text:"Weapon Lv "+weaponLevel;compact:true;enabled:stationAt(px,py)!==null;onActivated:upgrade(3)} UiButton{text:"Scanner Lv "+scannerLevel;compact:true;enabled:stationAt(px,py)!==null;onActivated:upgrade(4)}
                }
            }
            UiText{width:parent.width;text:message+(showHints?" · WASD/arrows move. Space/F fires at nearby pirates. E scans. Dock to accept jobs, refuel and upgrade. Complete 3 deliveries, then reach the jump gate.":"");colorToken:"color.textMuted";horizontalAlignment:Text.AlignHCenter;sizeToken:"metric.font.xs"}
        }
    }
    Connections{target:GameInput;function onActionPressed(action,value){if(action==="move_left")move(-1,0);else if(action==="move_right")move(1,0);else if(action==="up")move(0,-1);else if(action==="down")move(0,1);else if(action==="fire")fire();else if(action==="ability")scan()}}
    Component.onCompleted:{GameRandom.seed("astro-courier-v64");loadGame();forceActiveFocus()}
}
