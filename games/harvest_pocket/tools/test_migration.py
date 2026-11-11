#!/usr/bin/env python3
"""Pure invariant checks for Harvest Pocket legacy -> schema-v4 migration.

This does not replace a host GameSave runtime test. It mirrors the compatibility
rules that must remain true when old v6.4.x/v7.x slots are normalized by the
v7.4.2 runtime and compatibility mirrors are emitted.
"""
from __future__ import annotations

from copy import deepcopy

checks = 0
errors: list[str] = []

CROPS = [
    "turnip", "carrot", "potato", "berry", "corn", "tomato", "pepper", "sunflower",
    "pumpkin", "beet", "wheat", "onion", "crystal", "winterroot", "snowpea", "frostberry",
]
PRODUCTS = ["egg", "duck_egg", "milk", "goat_milk", "wool", "honey", "flour", "cornmeal",
            "berry_jam", "tomato_sauce", "cheese", "goat_cheese", "bread"]


def check(cond: bool, msg: str) -> None:
    global checks
    checks += 1
    if not cond:
        errors.append(msg)


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def default_inventory():
    out = {"feed": 4, "fertilizer": 2}
    for crop in CROPS:
        out[crop] = 0
        out[crop + "Seed"] = 8 if crop == "turnip" else 4 if crop == "carrot" else 0
    for product in PRODUCTS:
        out[product] = 0
    return out


def default_quality():
    return {crop: {"normal": 0, "fine": 0, "premium": 0, "perfect": 0} for crop in CROPS}


def migrate_v1(old: dict) -> dict:
    day = max(1, int(old.get("day", 1)))
    inv = default_inventory()
    for key, value in deepcopy(old.get("inventory", {})).items():
        try:
            inv[key] = max(0, float(value))
        except (TypeError, ValueError):
            inv[key] = 0

    quality = default_quality()
    for crop in CROPS:
        quality[crop]["normal"] = max(0, int(inv.get(crop, 0)))

    plots = deepcopy(old.get("plots", []))
    while len(plots) < 40:
        plots.append({"crop": "", "age": 0, "watered": False, "fertilized": False})
    plots = plots[:40]

    legacy_order = deepcopy(old.get("order"))
    orders = []
    if isinstance(legacy_order, dict) and legacy_order.get("item") and int(legacy_order.get("amount", 0)) > 0:
        orders = [{
            "item": str(legacy_order["item"]),
            "amount": max(1, int(legacy_order.get("amount", 1))),
            "reward": max(1, int(legacy_order.get("reward", 1))),
            "status": "accepted",
        }, None, None]

    mood = clamp(float(old.get("animalHappiness", 50)), 0, 100)
    return {
        "schema": 3,
        "day": day,
        "year": (day - 1) // 28 + 1,
        "coins": max(0, float(old.get("coins", 80))),
        "energy": max(0, float(old.get("energy", 16))),
        "maxEnergy": max(8, float(old.get("maxEnergy", 16))),
        "farmXp": max(0, float(old.get("farmXp", 0))),
        "farmLevel": max(1, int(old.get("farmLevel", 1))),
        "reputation": max(0, int(old.get("reputation", 0))),
        "wateringTier": clamp(int(old.get("wateringCanLevel", 1)), 1, 5),
        "sprinklerLevel": clamp(int(old.get("sprinklerLevel", 0)), 0, 5),
        "greenhouseLevel": clamp(int(old.get("greenhouseLevel", 0)), 0, 5),
        "landStage": 4,
        "coopLevel": clamp(int(old.get("coopLevel", 0)), 0, 5),
        "barnLevel": clamp(int(old.get("barnLevel", 0)), 0, 5),
        "apiaryLevel": 0,
        "legacyCropAccess": True,
        "plots": plots,
        "inventory": inv,
        "qualityInventory": quality,
        "animalCounts": {
            "chicken": max(0, int(old.get("chickens", 0))), "duck": 0,
            "cow": max(0, int(old.get("cows", 0))), "goat": 0, "sheep": 0, "bee": 0,
        },
        "animalMood": {"chicken": mood, "duck": 55, "cow": mood, "goat": 55, "sheep": 55, "bee": 65},
        "processingBuilt": {"mill": False, "feed_mixer": False, "preserver": False, "dairy": False, "kitchen": False},
        "projectLevels": {k: 0 for k in ["irrigation", "town_market", "bakery", "veterinary", "seed_lab", "railway", "festival", "research_center"]},
        "orders": orders,
        "orderRejectDay": day,
        "orderRejectsUsed": 0,
    }


legacy_plots = [
    {"crop": "turnip" if i == 0 else "carrot" if i == 39 else "", "age": 2 if i == 0 else 1,
     "watered": i % 2 == 0, "fertilized": i == 0}
    for i in range(40)
]
legacy = {
    "day": 58,
    "coins": 12345,
    "energy": 9,
    "maxEnergy": 27,
    "farmXp": 321,
    "farmLevel": 19,
    "reputation": 37,
    "plots": legacy_plots,
    "inventory": {"turnip": 13, "carrot": 7, "feed": 11, "fertilizer": 5, "egg": 4, "milk": 2},
    "wateringCanLevel": 99,
    "sprinklerLevel": 8,
    "greenhouseLevel": 6,
    "coopLevel": 3,
    "barnLevel": 2,
    "chickens": 9,
    "cows": 4,
    "animalHappiness": 83,
    "order": {"item": "egg", "amount": 3, "reward": 145},
}
new = migrate_v1(legacy)

check(new["schema"] == 3, "schema must become v3")
check(new["day"] == 58, "day must survive")
check(new["year"] == 3, "year must derive from 28-day calendar")
check(new["coins"] == 12345, "coins must survive")
check(new["energy"] == 9 and new["maxEnergy"] == 27, "energy state must survive")
check(new["farmXp"] == 321 and new["farmLevel"] == 19, "farm progression must survive")
check(new["reputation"] == 37, "reputation must survive")
check(len(new["plots"]) == 40, "legacy players must retain all 40 plots")
check(new["plots"][0]["crop"] == "turnip" and new["plots"][39]["crop"] == "carrot", "edge plot crops must survive")
check(new["plots"][0]["fertilized"] is True and new["plots"][2]["watered"] is True, "plot flags must survive")
check(new["landStage"] == 4, "legacy 40-plot farm maps to full land stage")
check(new["wateringTier"] == 5, "legacy watering level must clamp to meaningful tier 5")
check(new["sprinklerLevel"] == 5, "legacy sprinkler must clamp to tier 5")
check(new["greenhouseLevel"] == 5, "legacy greenhouse must clamp to tier 5")
check(new["coopLevel"] == 3 and new["barnLevel"] == 2, "legacy animal buildings must survive")
check(new["apiaryLevel"] == 0, "new apiary starts locked")
check(new["legacyCropAccess"] is True, "v6.4 migration must preserve access to the original six crops")
check(new["animalCounts"]["chicken"] == 9 and new["animalCounts"]["cow"] == 4, "legacy animals must survive")
check(new["animalCounts"]["duck"] == new["animalCounts"]["goat"] == new["animalCounts"]["sheep"] == new["animalCounts"]["bee"] == 0, "new animals start at zero")
check(new["animalMood"]["chicken"] == 83 and new["animalMood"]["cow"] == 83, "legacy happiness maps to existing animal moods")
check(new["inventory"]["turnip"] == 13 and new["inventory"]["carrot"] == 7, "legacy crop inventory survives")
check(new["inventory"]["feed"] == 11 and new["inventory"]["fertilizer"] == 5, "legacy consumables survive")
check(new["inventory"]["egg"] == 4 and new["inventory"]["milk"] == 2, "legacy animal products survive")
check(new["qualityInventory"]["turnip"]["normal"] == 13, "legacy turnips become Normal quality")
check(new["qualityInventory"]["carrot"]["normal"] == 7, "legacy carrots become Normal quality")
check(sum(new["qualityInventory"]["turnip"].values()) == new["inventory"]["turnip"], "turnip quality buckets must match total")
check(sum(new["qualityInventory"]["carrot"].values()) == new["inventory"]["carrot"], "carrot quality buckets must match total")
check(len(new["orders"]) == 3 and new["orders"][0]["status"] == "accepted", "legacy town order must be preserved as accepted")
check(new["orderRejectDay"] == 58 and new["orderRejectsUsed"] == 0, "v7.1 order refresh budget must start clean on migration")
check(new["orders"][0]["item"] == "egg" and new["orders"][0]["amount"] == 3 and new["orders"][0]["reward"] == 145, "legacy order payload must survive")
check(all(v is False for v in new["processingBuilt"].values()), "new processors must not auto-unlock")
check(all(v == 0 for v in new["projectLevels"].values()), "new community projects must not auto-complete")

# Adversarial normalization inputs.
neg = migrate_v1({"day": -10, "coins": -2, "wateringCanLevel": -3, "sprinklerLevel": -9,
                  "greenhouseLevel": 999, "chickens": -4, "cows": -1, "animalHappiness": 999})
check(neg["day"] == 1 and neg["year"] == 1, "negative day must normalize to day 1")
check(neg["coins"] == 0, "negative coins must clamp to zero")
check(neg["wateringTier"] == 1, "watering tier lower bound")
check(neg["sprinklerLevel"] == 0, "sprinkler lower bound")
check(neg["greenhouseLevel"] == 5, "greenhouse upper bound")
check(neg["animalCounts"]["chicken"] == 0 and neg["animalCounts"]["cow"] == 0, "negative animal counts clamp to zero")
check(neg["animalMood"]["chicken"] == 100 and neg["animalMood"]["cow"] == 100, "legacy happiness clamps to 100")
check(len(neg["plots"]) == 40, "missing plot list normalizes to 40")
check(neg["legacyCropAccess"] is True, "all legacy v1 slots retain original crop access")
check(neg["orders"] == [], "missing legacy order must not fabricate accepted progress")

# Fresh defaults must remain usable after sparse legacy inventories.
sparse = migrate_v1({"inventory": {"turnip": 2}})
check(sparse["inventory"]["turnip"] == 2, "sparse legacy turnip survives")
check(sparse["inventory"]["turnipSeed"] == 8, "new default turnip seeds remain available if absent in old inventory")
check(sparse["inventory"]["carrotSeed"] == 4, "new default carrot seeds remain available if absent in old inventory")
for crop in CROPS:
    check(crop in sparse["inventory"] and crop + "Seed" in sparse["inventory"], f"normalized inventory missing {crop}")
    check(set(sparse["qualityInventory"][crop]) == {"normal", "fine", "premium", "perfect"}, f"quality schema missing for {crop}")


# v7.0.x internal schema 2 -> v7.1 schema 3 compatibility. The runtime
# applies the old snapshot directly, defaults the new order-refresh fields,
# then immediately rewrites the canonical v3 snapshot while preserving the
# v2 compatibility mirror for downgrade safety.
def upgrade_v2_snapshot(old: dict) -> dict:
    out = deepcopy(old)
    out["schema"] = 3
    day = max(1, int(out.get("day", 1)))
    out["orderRejectDay"] = max(1, int(out.get("orderRejectDay", day)))
    out["orderRejectsUsed"] = max(0, min(3, int(out.get("orderRejectsUsed", 0))))
    return out

v2 = {
    "schema": 2, "day": 17, "coins": 912, "farmLevel": 8,
    "orders": [{"item":"turnip","amount":4,"reward":80,"status":"available"}, None, None],
    "legacyCropAccess": False,
}
v3 = upgrade_v2_snapshot(v2)
check(v3["schema"] == 3, "v2 snapshot must promote to schema 3")
check(v3["day"] == 17 and v3["coins"] == 912 and v3["farmLevel"] == 8, "v2 core progression must survive schema 3 promotion")
check(v3["orders"][0]["item"] == "turnip" and v3["orders"][0]["status"] == "available", "v2 town orders must survive schema 3 promotion")
check(v3["orderRejectDay"] == 17 and v3["orderRejectsUsed"] == 0, "new order refresh state must default to a clean current-day budget")

# v7.3 internal schema 3 -> v7.4 schema 4 Town Market migration.
def upgrade_v3_to_v4(old: dict) -> dict:
    out=deepcopy(old); out['schema']=4
    day=max(1,int(out.get('day',1)))
    out['orderRefreshDay']=max(1,int(out.get('orderRefreshDay',out.get('orderRejectDay',day))))
    out['orderRefreshesUsed']=max(0,min(3,int(out.get('orderRefreshesUsed',out.get('orderRejectsUsed',0)))))
    out['orderHistory']=deepcopy(out.get('orderHistory',[]))[:40]
    out['highestOrderReward']=max(0,int(out.get('highestOrderReward',0)))
    return out
legacy3={'schema':3,'day':22,'coins':1440,'orderRejectDay':22,'orderRejectsUsed':2,'orders':[{'item':'carrot','amount':4,'reward':90,'status':'accepted'},None,None]}
v4=upgrade_v3_to_v4(legacy3)
check(v4['schema']==4,'schema 3 snapshot must promote to schema 4')
check(v4['orderRefreshDay']==22 and v4['orderRefreshesUsed']==2,'legacy reject budget must migrate to board refresh budget')
check(v4['orders'][0]['status']=='accepted','accepted Town Order must survive v4 migration')
check(v4['orderHistory']==[] and v4['highestOrderReward']==0,'new Town Market history must default safely')

def compat_v3_order_status(status, day):
    if status in {'rejected','abandoned','completed','expired'}: return {'status':'cooldown','cooldownUntil':day+1}
    return {'status':status}
for terminal in ('rejected','abandoned','completed','expired'):
    c=compat_v3_order_status(terminal,22); check(c['status']=='cooldown' and c['cooldownUntil']==23,'terminal v4 order must downgrade safely to v3 cooldown')
check(compat_v3_order_status('accepted',22)['status']=='accepted','accepted order must remain accepted in v3 mirror')

# v7.4.2 interrupted-day recovery marker is additive inside schema v4. Old
# schema-v4 saves have no marker and must be eligible for one repair pass;
# freshly written/repaired saves persist revision 2 and stay idempotent.
def repair_partial_day(day, tracked_days, energy, max_energy, revision):
    changed=False
    if revision < 3 and day > 1 and tracked_days < day - 1:
        tracked_days=day-1; energy=max_energy; changed=True
    if revision < 3:
        revision=3; changed=True
    return tracked_days,energy,revision,changed

rd,re,rr,changed=repair_partial_day(7,5,3,22,0)
check(changed and rd==6 and re==22 and rr==3,'v7.4.0 partial-day save must restore energy/day counter once')
rd2,re2,rr2,changed2=repair_partial_day(7,rd,re,22,rr)
check(not changed2 and (rd2,re2,rr2)==(rd,re,rr),'interrupted-day recovery must be idempotent')
rd3,re3,rr3,changed3=repair_partial_day(9,7,2,24,2)
check(changed3 and rd3==8 and re3==24 and rr3==3,'v7.4.1 repair revision 2 save must be re-audited by v7.4.2')

if errors:
    print(f"MIGRATION REGRESSION FAIL: {len(errors)} errors after {checks} checks")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)
print(f"MIGRATION REGRESSION PASS: {checks}/{checks} checks")
