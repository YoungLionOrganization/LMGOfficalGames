import QtQuick

FocusScope {
    id: root
    focus: true
    property int day: 1
    property int coins: 90
    property int mastery: 0
    property int workshopLevel: 1
    property int streak: 0
    property int selectedRecipe: 0
    property int selectedSource: 0
    property int cauldronLevel: 1
    property int storageLevel: 1
    property var recipeMastery: [0,0,0,0,0,0,0,0,0,0,0,0]
    property var inventory: ({herb:6,mushroom:4,crystal:2,ember:1,dew:3,root:2,moon:0,scale:0,salt:2,essence:0})
    property var order: ({recipe:0,amount:2,progress:0,reward:80})
    property string message: tr("welcome","Gather ingredients, choose a recipe, then brew it in the cauldron.")
    readonly property bool showHints:Boolean(GameSettings.value("showHints",true))
    readonly property var ingredients:[
        {id:"herb",name:"Herb",source:0,color:"color.success"},{id:"dew",name:"Star Dew",source:0,color:"color.info"},{id:"moon",name:"Moon Petal",source:0,color:"color.primary"},
        {id:"mushroom",name:"Mushroom",source:1,color:"color.accent"},{id:"root",name:"Ancient Root",source:1,color:"color.special"},{id:"scale",name:"Drake Scale",source:1,color:"color.danger"},
        {id:"crystal",name:"Crystal",source:2,color:"color.info"},{id:"ember",name:"Ember",source:2,color:"color.danger"},{id:"salt",name:"Arcane Salt",source:2,color:"color.text"},{id:"essence",name:"Void Essence",source:2,color:"color.accent"}
    ]
    readonly property var sources:[
        {name:"Herb Garden",desc:"Herbs, dew and moon petals",color:"color.success"},
        {name:"Whisper Forest",desc:"Mushrooms, roots and rare scales",color:"color.accent"},
        {name:"Crystal Mine",desc:"Crystals, embers and arcane minerals",color:"color.info"}
    ]
    readonly property var recipes:[
        {name:"Healing Tonic",need:{herb:2,dew:1},value:24,xp:4,unlock:1},
        {name:"Focus Elixir",need:{mushroom:2,crystal:1},value:32,xp:5,unlock:1},
        {name:"Fire Ward",need:{ember:1,root:1},value:42,xp:7,unlock:1},
        {name:"Miner's Luck",need:{crystal:2,herb:1,salt:1},value:50,xp:8,unlock:2},
        {name:"Moon Serum",need:{moon:1,dew:2,crystal:1},value:70,xp:11,unlock:2},
        {name:"Dragon Balm",need:{scale:1,ember:1,herb:2},value:86,xp:14,unlock:3},
        {name:"Royal Catalyst",need:{moon:1,scale:1,root:2},value:114,xp:18,unlock:4},
        {name:"Phoenix Draught",need:{ember:2,moon:2,crystal:2},value:146,xp:22,unlock:5},
        {name:"Dream Ink",need:{mushroom:2,moon:1,salt:2},value:92,xp:15,unlock:3},
        {name:"Stoneheart Oil",need:{root:2,crystal:2,salt:1},value:105,xp:17,unlock:4},
        {name:"Void Lens",need:{essence:1,crystal:3,moon:1},value:190,xp:28,unlock:6},
        {name:"Lion's Elixir",need:{scale:2,essence:1,ember:2,herb:2},value:260,xp:38,unlock:8}
    ]

    function tr(k,f){return GameI18n.text(k,f)}
    function clone(v){return JSON.parse(JSON.stringify(v))}
    function selected(){return recipes[Math.max(0,Math.min(recipes.length-1,selectedRecipe))]}
    function unlocked(r){return workshopLevel>=r.unlock}
    function sourceLabel(i){return sources[Math.max(0,Math.min(2,i))].name}
    function needText(r){var a=[];for(var k in r.need)a.push(k+" ×"+r.need[k]);return a.join(" · ")}
    function canCraft(r){if(!unlocked(r))return false;for(var k in r.need)if(Number(inventory[k]||0)<Number(r.need[k]))return false;return true}
    function ingredientCount(id){return Number(inventory[id]||0)}
    function qualityMultiplier(i){return 1+Math.min(0.95,cauldronLevel*0.04+Number(recipeMastery[i]||0)*0.012+streak*0.025)}

    function ingredientUnlocked(ing) {
        if (ing.id === "moon") return workshopLevel >= 2
        if (ing.id === "scale") return workshopLevel >= 3
        if (ing.id === "essence") return workshopLevel >= 5
        return true
    }
    function gather(sourceIndex){selectedSource=sourceIndex;var candidates=[];for(var i=0;i<ingredients.length;i++)if(ingredients[i].source===sourceIndex&&ingredientUnlocked(ingredients[i]))candidates.push(ingredients[i]);if(candidates.length===0){message="No ingredients unlocked in this area yet";return}var count=2+Math.floor(workshopLevel/3),inv=clone(inventory),found=[];for(var n=0;n<count;n++){var ing=candidates[GameRandom.nextInt(0,candidates.length-1)];var bonus=GameRandom.chance(0.15+workshopLevel*0.01)?2:1;inv[ing.id]=Number(inv[ing.id]||0)+bonus;found.push(ing.name+" +"+bonus)}inventory=inv;day++;if(day%4===0)newOrder();GameStats.increment("gather_runs");message=sourceLabel(sourceIndex)+": "+found.join(", ");Haptics.light();persist()}
    function craft(i){var r=recipes[i];selectedRecipe=i;if(!unlocked(r)){message="Workshop Lv "+r.unlock+" required";Haptics.light();return}if(!canCraft(r)){message=tr("missing_ingredients","Missing ingredients");Haptics.light();return}var inv=clone(inventory);for(var k in r.need)inv[k]=Number(inv[k]||0)-Number(r.need[k]);inventory=inv;var quality=qualityMultiplier(i),earned=Math.round(r.value*quality);coins+=earned;mastery+=r.xp;streak++;var rm=recipeMastery.slice();rm[i]=Number(rm[i]||0)+1;recipeMastery=rm;GameStats.increment("potions_crafted");GameStats.submitHighScore(streak,"craft_streak");orderCheck(i);levelCheck();message=r.name+" brewed · quality ×"+quality.toFixed(2)+" · +"+earned+" coins";Haptics.medium();persist()}
    function levelCheck(){var need=workshopLevel*45;while(mastery>=need){mastery-=need;workshopLevel++;coins+=50+workshopLevel*10;Achievements.unlock("alchemist_level_"+workshopLevel);Haptics.heavy();need=workshopLevel*45}}
    function orderCheck(recipeIndex){if(order.recipe!==recipeIndex)return;var o=clone(order);o.progress=Number(o.progress||0)+1;order=o;if(order.progress>=order.amount){coins+=order.reward;streak+=2;GameStats.increment("orders_completed");Achievements.unlock("guild_supplier");message=tr("order_complete","Guild order complete")+" · +"+order.reward+" coins";newOrder()}}
    function newOrder(){var available=[];for(var i=0;i<recipes.length;i++)if(unlocked(recipes[i]))available.push(i);var ri=available[GameRandom.nextInt(0,available.length-1)],amount=1+GameRandom.nextInt(0,Math.min(3,Math.floor(workshopLevel/3)));order={recipe:ri,amount:amount,progress:0,reward:Math.round(recipes[ri].value*amount*0.9+workshopLevel*10)}}
    function buyIngredient(i){var ing=ingredients[i],cost=7+i*3;if(coins<cost)return;coins-=cost;var inv=clone(inventory);inv[ing.id]=ingredientCount(ing.id)+1;inventory=inv;message="Bought "+ing.name;persist()}
    function upgradeWorkshop(){var cost=140+workshopLevel*100;if(coins<cost)return;coins-=cost;workshopLevel++;message="Workshop upgraded to Lv "+workshopLevel;persist()}
    function upgradeCauldron(){var cost=120+cauldronLevel*130;if(coins<cost)return;coins-=cost;cauldronLevel++;message="Cauldron quality improved";persist()}
    function upgradeStorage(){var cost=90+storageLevel*100;if(coins<cost)return;coins-=cost;storageLevel++;var inv=clone(inventory);inv.salt=ingredientCount("salt")+2;inventory=inv;message="Storage expanded · Arcane Salt +2";persist()}
    function moveRecipe(delta){var i=selectedRecipe;for(var guard=0;guard<recipes.length;guard++){i=(i+delta+recipes.length)%recipes.length;if(unlocked(recipes[i])){selectedRecipe=i;return}}}

    function persist(){GameSave.set("day",day);GameSave.set("coins",coins);GameSave.set("mastery",mastery);GameSave.set("workshopLevel",workshopLevel);GameSave.set("streak",streak);GameSave.set("selectedRecipe",selectedRecipe);GameSave.set("selectedSource",selectedSource);GameSave.set("cauldronLevel",cauldronLevel);GameSave.set("storageLevel",storageLevel);GameSave.set("recipeMastery",recipeMastery);GameSave.set("inventory",inventory);GameSave.set("order",order);GameSave.save("autosave")}
    function loadGame(){if(GameSave.load("autosave")){day=Number(GameSave.get("day",1));coins=Number(GameSave.get("coins",90));mastery=Number(GameSave.get("mastery",0));workshopLevel=Number(GameSave.get("workshopLevel",1));streak=Number(GameSave.get("streak",0));selectedRecipe=Number(GameSave.get("selectedRecipe",0));selectedSource=Number(GameSave.get("selectedSource",0));cauldronLevel=Number(GameSave.get("cauldronLevel",1));storageLevel=Number(GameSave.get("storageLevel",1));recipeMastery=GameSave.get("recipeMastery",recipeMastery);inventory=GameSave.get("inventory",inventory);order=GameSave.get("order",order)}if(!order||order.progress===undefined)newOrder()}

    Rectangle{anchors.fill:parent;color:GameTheme.color("color.background")}
    Connections{target:Lifecycle;function onSaveRequested(){persist()}function onBackgrounded(){persist()}}
    Keys.priority:Keys.BeforeItem
    Keys.onPressed:function(e){if(e.key>=Qt.Key_1&&e.key<=Qt.Key_3)gather(e.key-Qt.Key_1);else if(e.key===Qt.Key_Left||e.key===Qt.Key_A)moveRecipe(-1);else if(e.key===Qt.Key_Right||e.key===Qt.Key_D)moveRecipe(1);else if(e.key===Qt.Key_Return||e.key===Qt.Key_Enter||e.key===Qt.Key_Space)craft(selectedRecipe);else if(e.key===Qt.Key_U)upgradeWorkshop();else return;e.accepted=true}

    Flickable{anchors.fill:parent;contentWidth:width;contentHeight:body.implicitHeight+GameTheme.number("alias.page.padding")*2;clip:true
        Column{id:body;width:parent.width-GameTheme.number("alias.page.padding")*2;x:GameTheme.number("alias.page.padding");y:GameTheme.number("alias.page.padding");spacing:GameTheme.number("alias.page.gap")
            UiPanel{width:parent.width;implicitHeight:head.implicitHeight+GameTheme.number("alias.card.padding")*2;surfaceToken:"surface.panel"
                Flow{id:head;anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("alias.card.gap")
                    ThemedSvgIcon{width:GameTheme.number("metric.icon.lg");height:width;source:Qt.resolvedUrl("assets/alchemy/flask.svg");tint:GameTheme.color("color.primary")}
                    UiText{text:tr("title","Alchemy Workshop");font.bold:true;sizeToken:"metric.font.lg"} HudChip{label:tr("day","Day");value:String(day)} HudChip{label:tr("coins","Coins");value:String(coins)} HudChip{label:"Workshop";value:"Lv "+workshopLevel} HudChip{label:"Cauldron";value:"Lv "+cauldronLevel} HudChip{label:"Mastery";value:String(mastery)}
                }
            }
            UiPanel{width:parent.width;implicitHeight:step1.implicitHeight+GameTheme.number("alias.card.padding")*2
                Column{id:step1;anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("alias.card.gap")
                    UiText{text:"1 · Gather ingredients";font.bold:true;sizeToken:"metric.font.md"}
                    UiText{text:"Choose an expedition. It consumes no coins; one day passes and the workshop receives random materials.";colorToken:"color.textMuted";sizeToken:"metric.font.sm"}
                    Flow{width:parent.width;spacing:GameTheme.number("alias.button.gap");Repeater{model:sources.length;UiButton{required property int index;text:(index+1)+" · "+sources[index].name;primary:selectedSource===index;onActivated:gather(index)}}}
                }
            }
            UiPanel{width:parent.width;implicitHeight:shelf.implicitHeight+GameTheme.number("alias.card.padding")*2
                Flow{id:shelf;anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("alias.card.gap")
                    UiText{text:"Ingredient shelf";font.bold:true}
                    Repeater{model:ingredients.length;HudChip{required property int index;label:ingredients[index].name;value:String(root.ingredientCount(ingredients[index].id));valueColorToken:ingredients[index].color}}
                }
            }
            UiPanel{width:parent.width;implicitHeight:step2.implicitHeight+GameTheme.number("alias.card.padding")*2
                Column{id:step2;anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("alias.card.gap")
                    UiText{text:"2 · Choose a recipe";font.bold:true;sizeToken:"metric.font.md"}
                    Flow{width:parent.width;spacing:GameTheme.number("alias.card.gap")
                        Repeater{model:recipes.length
                            UiPanel{required property int index;width:Math.max(GameTheme.number("metric.card.sm"),Math.min(GameTheme.number("metric.card.lg"),(step2.width-GameTheme.number("alias.card.gap")*2)/3));height:GameTheme.number("metric.control.lg")*1.65;surfaceToken:"surface.card";opacity:root.unlocked(recipes[index])?1:0.48;border.width:root.selectedRecipe===index?2:1;border.color:root.selectedRecipe===index?GameTheme.color("color.primary"):GameTheme.color("color.border")
                                Column{anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("metric.space.xxxs")
                                    UiText{text:recipes[index].name;font.bold:true;colorToken:index===root.order.recipe?"color.accent":"color.text"}
                                    UiText{text:root.unlocked(recipes[index])?root.needText(recipes[index]):("Unlocks at Workshop Lv "+recipes[index].unlock);colorToken:"color.textMuted";sizeToken:"metric.font.xs"}
                                    UiText{text:"Value "+recipes[index].value+" · Mastery "+Number(root.recipeMastery[index]||0);colorToken:root.canCraft(recipes[index])?"color.success":"color.textMuted";sizeToken:"metric.font.sm"}
                                }
                                TapHandler{onTapped:{root.forceActiveFocus();root.selectedRecipe=index}}
                            }
                        }
                    }
                }
            }
            UiPanel{width:parent.width;implicitHeight:brew.implicitHeight+GameTheme.number("alias.card.padding")*2;surfaceToken:"surface.panel"
                Column{id:brew;anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("alias.card.gap")
                    UiText{text:"3 · Brew in the cauldron";font.bold:true;sizeToken:"metric.font.md"}
                    UiText{text:selected().name+" · "+needText(selected());font.bold:true;colorToken:"color.accent"}
                    UiText{text:"Expected value "+Math.round(selected().value*qualityMultiplier(selectedRecipe))+" coins · quality ×"+qualityMultiplier(selectedRecipe).toFixed(2);colorToken:"color.textMuted"}
                    Flow{width:parent.width;spacing:GameTheme.number("alias.button.gap")
                        UiButton{text:"BREW "+selected().name;shortcutText:"Enter";primary:true;enabled:canCraft(selected());onActivated:craft(selectedRecipe)}
                        UiButton{text:"Workshop +";shortcutText:"U";onActivated:upgradeWorkshop()} UiButton{text:"Cauldron +";onActivated:upgradeCauldron()} UiButton{text:"Storage +";onActivated:upgradeStorage()}
                    }
                }
            }
            UiPanel{width:parent.width;implicitHeight:guild.implicitHeight+GameTheme.number("alias.card.padding")*2
                Column{id:guild;anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("metric.space.xs")
                    UiText{text:"Guild Order";font.bold:true;sizeToken:"metric.font.md"}
                    UiText{text:recipes[order.recipe].name+" · "+order.progress+"/"+order.amount+" · reward "+order.reward+" coins";colorToken:"color.accent"}
                    UiBar{width:parent.width;height:GameTheme.number("metric.space.xs");value:order.progress;to:Math.max(1,order.amount);fillToken:"color.accent"}
                }
            }
            UiPanel{width:parent.width;implicitHeight:shop.implicitHeight+GameTheme.number("alias.card.padding")*2
                Flow{id:shop;anchors.fill:parent;anchors.margins:GameTheme.number("alias.card.padding");spacing:GameTheme.number("alias.button.gap")
                    UiText{text:"Supply Shop";font.bold:true}
                    Repeater{model:ingredients.length;UiButton{required property int index;text:"+ "+ingredients[index].name+" · "+(7+index*3);compact:true;onActivated:buyIngredient(index)}}
                }
            }
            UiText{width:parent.width;text:message+(showHints?" · Desktop: 1–3 gather, arrows/A-D choose recipe, Enter/Space brew, U workshop upgrade.":"");horizontalAlignment:Text.AlignHCenter;colorToken:"color.textMuted";sizeToken:"metric.font.xs"}
        }
    }
    Connections{target:GameInput;function onActionPressed(action,value){if(action==="move_left")moveRecipe(-1);else if(action==="move_right")moveRecipe(1);else if(action==="fire")craft(selectedRecipe);else if(action==="up")gather(selectedSource)}}
    Component.onCompleted:{GameRandom.seed("alchemy-workshop-v64");loadGame();forceActiveFocus()}
}
