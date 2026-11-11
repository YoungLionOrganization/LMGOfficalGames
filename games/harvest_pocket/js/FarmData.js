.pragma library

var crops = [
    {id:"turnip", key:"crop_turnip", seedCost:3, sell:8, days:2, seasons:[0,3], level:1, category:"vegetable"},
    {id:"carrot", key:"crop_carrot", seedCost:5, sell:13, days:3, seasons:[0,2], level:1, category:"vegetable"},
    {id:"potato", key:"crop_potato", seedCost:6, sell:15, days:3, seasons:[0,2], level:2, category:"vegetable"},
    {id:"berry", key:"crop_berry", seedCost:8, sell:18, days:3, seasons:[0,1], level:1, category:"fruit"},
    {id:"corn", key:"crop_corn", seedCost:10, sell:24, days:4, seasons:[1,2], level:4, category:"grain"},
    {id:"tomato", key:"crop_tomato", seedCost:12, sell:28, days:4, seasons:[1], level:5, category:"vegetable"},
    {id:"pepper", key:"crop_pepper", seedCost:14, sell:34, days:4, seasons:[1], level:6, category:"vegetable"},
    {id:"sunflower", key:"crop_sunflower", seedCost:15, sell:38, days:5, seasons:[1,2], level:7, category:"flower"},
    {id:"pumpkin", key:"crop_pumpkin", seedCost:18, sell:46, days:5, seasons:[2], level:8, category:"vegetable"},
    {id:"beet", key:"crop_beet", seedCost:16, sell:40, days:4, seasons:[2,3], level:9, category:"vegetable"},
    {id:"wheat", key:"crop_wheat", seedCost:14, sell:32, days:4, seasons:[0,2], level:7, category:"grain"},
    {id:"onion", key:"crop_onion", seedCost:17, sell:43, days:5, seasons:[0,2], level:10, category:"vegetable"},
    {id:"crystal", key:"crop_crystal", seedCost:24, sell:62, days:5, seasons:[3], level:10, category:"rare"},
    {id:"winterroot", key:"crop_winterroot", seedCost:26, sell:70, days:5, seasons:[3], level:12, category:"rare"},
    {id:"snowpea", key:"crop_snowpea", seedCost:28, sell:76, days:4, seasons:[3,0], level:14, category:"vegetable"},
    {id:"frostberry", key:"crop_frostberry", seedCost:34, sell:94, days:6, seasons:[3], level:16, category:"rare"}
]

var animals = [
    {id:"chicken", key:"animal_chicken", product:"egg", productKey:"product_egg", building:"coop", buildingKey:"building_coop", buildingLevel:1, level:5, feed:1, buyBase:110, buyStep:55, productBase:16},
    {id:"duck", key:"animal_duck", product:"duck_egg", productKey:"product_duck_egg", building:"coop", buildingKey:"building_coop", buildingLevel:2, level:7, feed:1, buyBase:170, buyStep:70, productBase:22},
    {id:"cow", key:"animal_cow", product:"milk", productKey:"product_milk", building:"barn", buildingKey:"building_barn", buildingLevel:1, level:8, feed:2, buyBase:260, buyStep:90, productBase:28},
    {id:"goat", key:"animal_goat", product:"goat_milk", productKey:"product_goat_milk", building:"barn", buildingKey:"building_barn", buildingLevel:2, level:10, feed:1, buyBase:300, buyStep:100, productBase:34},
    {id:"sheep", key:"animal_sheep", product:"wool", productKey:"product_wool", building:"barn", buildingKey:"building_barn", buildingLevel:3, level:12, feed:1, buyBase:360, buyStep:120, productBase:42},
    {id:"bee", key:"animal_bee", product:"honey", productKey:"product_honey", building:"apiary", buildingKey:"building_apiary", buildingLevel:1, level:12, feed:0, buyBase:220, buyStep:85, productBase:38}
]

var recipes = [
    {id:"flour", key:"product_flour", building:"mill", buildingKey:"building_mill", level:7, energy:1, inputs:{wheat:3}, output:"flour", amount:2, base:24},
    {id:"cornmeal", key:"product_cornmeal", building:"mill", buildingKey:"building_mill", level:7, energy:1, inputs:{corn:3}, output:"cornmeal", amount:2, base:28},
    {id:"berry_jam", key:"product_berry_jam", building:"preserver", buildingKey:"building_preserver", level:9, energy:1, inputs:{berry:3}, output:"berry_jam", amount:1, base:72},
    {id:"tomato_sauce", key:"product_tomato_sauce", building:"preserver", buildingKey:"building_preserver", level:9, energy:1, inputs:{tomato:3}, output:"tomato_sauce", amount:1, base:82},
    {id:"cheese", key:"product_cheese", building:"dairy", buildingKey:"building_dairy", level:10, energy:1, inputs:{milk:2}, output:"cheese", amount:1, base:78},
    {id:"goat_cheese", key:"product_goat_cheese", building:"dairy", buildingKey:"building_dairy", level:11, energy:1, inputs:{goat_milk:2}, output:"goat_cheese", amount:1, base:92},
    {id:"feed", key:"product_feed", building:"feed_mixer", buildingKey:"building_feed_mixer", level:8, energy:1, inputs:{corn:2,wheat:1}, output:"feed", amount:5, base:0},
    {id:"bread", key:"product_bread", building:"kitchen", buildingKey:"building_kitchen", level:12, energy:2, inputs:{flour:2,egg:1}, output:"bread", amount:1, base:118}
]

var processingBuildings = [
    {id:"mill", key:"building_mill", level:7, cost:750},
    {id:"feed_mixer", key:"building_feed_mixer", level:8, cost:920},
    {id:"preserver", key:"building_preserver", level:9, cost:1250},
    {id:"dairy", key:"building_dairy", level:10, cost:1650},
    {id:"kitchen", key:"building_kitchen", level:12, cost:2350}
]

var projects = [
    {id:"irrigation", key:"project_irrigation", icon:"irrigation", item:"carrot", itemKey:"crop_carrot", coinBase:900, itemBase:18, unlockRep:10},
    {id:"town_market", key:"project_town_market", icon:"town_market", item:"corn", itemKey:"crop_corn", coinBase:1300, itemBase:22, unlockRep:18},
    {id:"bakery", key:"project_bakery", icon:"bakery", item:"flour", itemKey:"product_flour", coinBase:1800, itemBase:16, unlockRep:26},
    {id:"veterinary", key:"project_veterinary", icon:"veterinary", item:"milk", itemKey:"product_milk", coinBase:2400, itemBase:18, unlockRep:34},
    {id:"seed_lab", key:"project_seed_lab", icon:"seed_lab", item:"crystal", itemKey:"crop_crystal", coinBase:3300, itemBase:14, unlockRep:44},
    {id:"railway", key:"project_railway", icon:"railway", item:"pumpkin", itemKey:"crop_pumpkin", coinBase:4700, itemBase:28, unlockRep:56},
    {id:"festival", key:"project_festival", icon:"festival", item:"berry_jam", itemKey:"product_berry_jam", coinBase:6500, itemBase:18, unlockRep:72},
    {id:"research_center", key:"project_research_center", icon:"research_center", item:"honey", itemKey:"product_honey", coinBase:9000, itemBase:24, unlockRep:90}
]

var qualities = ["normal","fine","premium","perfect"]
var masteryThresholds = [0, 25, 100, 400, 1500]
var landCounts = [12,20,28,34,40]
var landCosts = [0,250,1000,3500,9000]
var landLevels = [1,4,8,12,16]
var wateringCounts = [1,2,3,5,9]
var toolCosts = [0,180,620,1850,5200]
var sprinklerCoverage = [0,8,16,24,32,40]
var sprinklerCosts = [0,520,1250,2900,6400,14000]
var greenhouseCoverage = [0,8,16,24,32,40]
var greenhouseCosts = [0,900,2200,5200,12000,27000]
var buildingCapacity = [0,4,8,12,18,24]
var buildingCosts = [0,240,620,1450,3200,6800]
var barnCapacity = [0,2,4,6,9,12]
var barnCosts = [0,520,1400,3200,7000,14500]
var apiaryCapacity = [0,3,6,10,15,22]
var apiaryCosts = [0,900,2100,4700,9800,19500]

function cropById(id) {
    for (var i=0;i<crops.length;i++) if (crops[i].id===id) return crops[i]
    return crops[0]
}
function animalById(id) {
    for (var i=0;i<animals.length;i++) if (animals[i].id===id) return animals[i]
    return animals[0]
}
function productBase(id) {
    for (var i=0;i<crops.length;i++) if (crops[i].id===id) return crops[i].sell
    for (var j=0;j<animals.length;j++) if (animals[j].product===id) return animals[j].productBase
    for (var k=0;k<recipes.length;k++) if (recipes[k].output===id) return recipes[k].base
    return id==="feed" ? 4 : 10
}
function itemKey(id) {
    for (var i=0;i<crops.length;i++) if (crops[i].id===id) return crops[i].key
    for (var j=0;j<animals.length;j++) if (animals[j].product===id) return animals[j].productKey
    for (var k=0;k<recipes.length;k++) if (recipes[k].output===id) return recipes[k].key
    return "product_"+id
}
function hash01(seed, day, salt) {
    var x = (Number(seed)||1) ^ ((Number(day)||1)*374761393) ^ ((Number(salt)||0)*668265263)
    x = (x ^ (x >>> 13)) * 1274126177
    x = x ^ (x >>> 16)
    return (x >>> 0) / 4294967295.0
}
function clamp(v,a,b){ return Math.max(a,Math.min(b,v)) }
