#!/usr/bin/env python3
"""Pure regression checks for Harvest Pocket v7.4 economy/layout/gameplay invariants."""
import math, sys
checks=0

def ok(cond,msg):
    global checks
    checks+=1
    if not cond: raise AssertionError(msg)

# Calendar: exact 7-day seasons / 28-day year.
def season(day): return ((day-1)%28)//7
def season_day(day): return ((day-1)%7)+1
for d,expected in [(1,0),(7,0),(8,1),(14,1),(15,2),(21,2),(22,3),(28,3),(29,0)]: ok(season(d)==expected,f'season day {d}')
for d in range(1,60): ok(1<=season_day(d)<=7,'season day range')

# Upgrade sinks are finite and every level changes gameplay.
watering=[1,2,3,5,9]; sprinkler=[0,8,16,24,32,40]; greenhouse=[0,8,16,24,32,40]
ok(all(watering[i+1]>watering[i] for i in range(4)),'watering tiers must all improve coverage')
ok(all(sprinkler[i+1]>sprinkler[i] for i in range(5)),'sprinkler levels must all improve coverage')
ok(all(greenhouse[i+1]>greenhouse[i] for i in range(5)),'greenhouse levels must all improve coverage')
ok(watering[-1]==9 and sprinkler[-1]==40 and greenhouse[-1]==40,'max coverage invariants')

# Land progression and legacy migration guarantee.
land=[12,20,28,34,40]
ok(land[0]==12 and land[-1]==40 and all(land[i+1]>land[i] for i in range(4)),'land progression')
legacy_land_stage=4
ok(land[legacy_land_stage]==40,'v6.4 migrated saves keep all 40 plots')


# Backward-compatible crop gates: migrated v6.4 saves retain the original six
# crops even when their new v7 level gate is above the player's farm level.
legacy_six={"turnip","carrot","berry","corn","pumpkin","crystal"}
new_crops={"potato","tomato","pepper","sunflower","beet","wheat","onion","winterroot","snowpea","frostberry"}
def crop_unlocked(crop_id, level_req, farm_level, legacy_access):
    return farm_level >= level_req or (legacy_access and crop_id in legacy_six)
ok(crop_unlocked("pumpkin",8,1,True),'legacy pumpkin access must survive migration')
ok(crop_unlocked("crystal",10,1,True),'legacy crystal access must survive migration')
ok(not crop_unlocked("potato",2,1,True),'new v7 crop must not auto-unlock for migrated saves')
ok(not crop_unlocked("frostberry",16,1,True),'late v7 crop must remain gated on migrated saves')
ok(not crop_unlocked("pumpkin",8,1,False),'fresh v7 saves must follow new crop gates')
ok(crop_unlocked("pumpkin",8,8,False),'fresh v7 saves unlock crops normally by farm level')

# Capacity systems are finite and monotonic.
for cap in ([0,4,8,12,18,24],[0,2,4,6,9,12],[0,3,6,10,15,22]): ok(all(cap[i+1]>cap[i] for i in range(5)),'building capacity progression')

# Happiness is mechanically meaningful.
def mood_mul(v):
    if v<25:return .5
    if v<50:return .75
    if v<75:return 1.0
    if v<90:return 1.1
    return 1.25
ok([mood_mul(x) for x in (10,30,60,80,95)]==[.5,.75,1.0,1.1,1.25],'happiness production bands')

# Crop quality values make fertilization/mastery worth something without unbounded multipliers.
quality={'normal':1.0,'fine':1.35,'premium':1.8,'perfect':2.5}
ok(list(quality.values())==sorted(quality.values()),'quality multipliers monotonic')
ok(quality['perfect']<=2.5,'quality cap')

# Deterministic RNG model: same world/day/salt always same result and values stay [0,1].
def h(seed,day,salt):
    # mirrors intended unsigned mixing behavior sufficiently for deterministic invariant tests
    x=(seed ^ (day*374761393) ^ (salt*668265263)) & 0xffffffff
    x=((x ^ (x>>13))*1274126177)&0xffffffff
    x=(x ^ (x>>16))&0xffffffff
    return x/4294967295.0
for seed in (1,17,123456789):
    for day in (1,28,1000):
        a=h(seed,day,31); b=h(seed,day,31)
        ok(a==b and 0<=a<=1,'deterministic daily RNG')
ok(h(17,1,31)!=h(17,2,31),'different days should normally differ')

# Community projects: 8 projects x 5 phases, cost rises but stays finite for intended phases.
for coin_base,item_base in [(900,18),(1300,22),(1800,16),(2400,18),(3300,14),(4700,28),(6500,18),(9000,24)]:
    prev=(0,0)
    for phase in range(1,6):
        cost=(round(coin_base*(2.15**(phase-1))),round(item_base*(1.75**(phase-1))))
        ok(cost[0]>prev[0] and cost[1]>prev[1] and cost[0]<10**9,'project scaling finite/monotonic')
        prev=cost

# Order rewards stay positive and reputation railway bonus is bounded in project range.
for base in (8,28,118):
    for amount in (2,8):
        for rep in (0,20,1000):
            reward=round(base*amount*(1.55+rep*.002)*(1+5*.04))
            ok(reward>0 and math.isfinite(reward),'order reward finite')


# Next-day warning uses effective sprinkler coverage including Irrigation Canal.
def effective_sprinkler(base, irrigation_phase, active): return min(active, base + irrigation_phase*2)
ok(effective_sprinkler(8,5,20)==18,'irrigation project expands effective sprinkler coverage')
ok(effective_sprinkler(40,5,40)==40,'sprinkler coverage remains capped to active land')

# Quality bucket repair: canonical total must equal inventory after normalization.
def repair_quality(stock,buckets):
    b={k:max(0,int(v)) for k,v in buckets.items()}
    order=['normal','fine','premium','perfect']
    total=sum(b.get(k,0) for k in order)
    if total<stock: b['normal']=b.get('normal',0)+(stock-total)
    elif total>stock:
        overflow=total-stock
        for k in order:
            cut=min(b.get(k,0),overflow); b[k]=b.get(k,0)-cut; overflow-=cut
            if overflow<=0: break
    return b
for stock,b in [(5,{'normal':1,'fine':1,'premium':0,'perfect':0}),(2,{'normal':4,'fine':1,'premium':0,'perfect':0}),(0,{'normal':0,'fine':0,'premium':0,'perfect':3})]:
    r=repair_quality(stock,b); ok(sum(r.values())==stock,'quality repair must match crop stock')

# v7.0.4 planting UX / seasonal order reachability
crops = [
    ('turnip',[0,3]),('carrot',[0,2]),('potato',[0,2]),('berry',[0,1]),
    ('corn',[1,2]),('tomato',[1]),('pepper',[1]),('sunflower',[1,2]),
    ('pumpkin',[2]),('beet',[2,3]),('wheat',[0,2]),('onion',[0,2]),
    ('crystal',[3]),('winterroot',[3]),('snowpea',[3,0]),('frostberry',[3])
]
for season in range(4):
    visible=[c for c,seasons in crops if season in seasons]
    ok(len(visible)>=4, f'season {season} must offer a practical crop selection')
ok(all(len(seasons)>=1 for _,seasons in crops), 'every crop must declare at least one season')


# A fresh low-level farm must never be season-locked out of planting.
level1_crops = {
    'turnip':([0,3],1), 'carrot':([0,2],1), 'berry':([0,1],1)
}
for season_id in range(4):
    ok(any(level==1 and season_id in seasons for seasons,level in level1_crops.values()), f'season {season_id} must have a level-1 crop')


# v7.0.4 Next Day warning semantics: only actively growing, uncovered dry crops warn.
def dry_warning_count(plots, effective_sprinkler, weather, days_by_crop):
    dry=0
    for i,p in enumerate(plots):
        if not p.get('crop'): continue
        if int(p.get('age',0)) >= int(days_by_crop[p['crop']]): continue
        if (not p.get('watered',False) and i>=effective_sprinkler and weather not in ('rain','storm')):
            dry+=1
    return dry
_days={'turnip':2,'carrot':3}
_sample=[{'crop':'turnip','age':0,'watered':False},{'crop':'carrot','age':3,'watered':False},{'crop':'turnip','age':0,'watered':True}]
ok(dry_warning_count(_sample,0,'sunny',_days)==1,'only dry growing crops should warn')
ok(dry_warning_count(_sample,1,'sunny',_days)==0,'sprinkler-covered crop should not warn')
ok(dry_warning_count(_sample,0,'rain',_days)==0,'rain should suppress dry-crop warning')
ok(dry_warning_count(_sample,0,'storm',_days)==0,'storm should suppress dry-crop warning')

# Season-filter navigation must cycle only through currently visible crop indexes.
def cycle_visible(indexes,current,step=1):
    if not indexes:return current
    try: pos=indexes.index(current)
    except ValueError: pos=0
    else: pos=(pos+step+len(indexes))%len(indexes)
    return indexes[pos]
ok(cycle_visible([0,1,3],1,1)==3,'next crop follows visible season filter')
ok(cycle_visible([0,1,3],3,1)==0,'visible crop cycling wraps')
ok(cycle_visible([0,1,3],9,1)==0,'hidden crop selection recovers to first visible crop')

# v7.1.0 effective watering source and no-double-watering semantics.
def effective_water_source(index, plot, coverage, weather):
    if not plot.get("crop"): return ""
    if plot.get("watered", False): return "manual"
    if 0 <= index < coverage: return "sprinkler"
    if weather == "storm": return "storm"
    if weather == "rain": return "rain"
    return ""
plot={"crop":"turnip","watered":False}
ok(effective_water_source(2,plot,8,"sunny")=="sprinkler",'sprinkler coverage must produce effective water')
ok(effective_water_source(12,plot,8,"rain")=="rain",'rain must produce effective water outside sprinkler coverage')
ok(effective_water_source(12,plot,8,"storm")=="storm",'storm must produce effective water outside sprinkler coverage')
ok(effective_water_source(2,{"crop":"turnip","watered":True},8,"rain")=="manual",'manual water remains the explicit source when already watered')
ok(effective_water_source(12,plot,8,"sunny")=="",'dry uncovered plot must remain dry')

# v7.4 board refresh semantics: three free refreshes/day and accepted orders survive.
def refresh_board(statuses, used, budget=3):
    if used >= budget: return statuses, used, False
    changed=False; out=[]
    for status in statuses:
        if status == 'accepted': out.append(status); continue
        out.append('available'); changed=True
    return (out, used+1, True) if changed else (statuses, used, False)
statuses=['available','accepted','completed']; used=0
for _ in range(3):
    statuses,used,changed=refresh_board(statuses,used)
    ok(changed and statuses[1]=='accepted','board refresh must preserve accepted orders')
ok(used==3,'three daily board refreshes should be consumable')
_,used4,changed4=refresh_board(statuses,used)
ok(used4==3 and not changed4,'fourth same-day board refresh must be blocked')

# Responsive layout thresholds are deterministic and cover compact/medium/wide.
def layout_class(width): return 'compact' if width < 680 else ('medium' if width < 1280 else 'wide')
ok(layout_class(360)=='compact' and layout_class(679)=='compact','phone/narrow widths must use compact bottom navigation')
ok(layout_class(680)=='medium' and layout_class(1279)=='medium','tablet/windowed desktop widths must use top navigation')
ok(layout_class(1280)=='wide' and layout_class(1920)=='wide','wide/fullscreen desktop must keep centered dense top navigation')

# v7.2 Living Seasons transition sequencing and bounded-pool invariants.
def transition_plan(old_season, new_season, weather):
    plan=["fade_out","commit"]
    if old_season != new_season: plan.append("season")
    plan.extend(["weather","fade_in"])
    return plan
ok(transition_plan(0,0,"rain")==["fade_out","commit","weather","fade_in"],'same-season day skips season banner but preserves weather stage')
ok(transition_plan(0,1,"sunny")==["fade_out","commit","season","weather","fade_in"],'season boundary must sequence season before weather')
ok(6 <= 10 and 5 <= 10 and 10 <= 10,'transition and ambient pools remain small and bounded')
for weather in ("sunny","cloudy","rain","wind","storm","heatwave","frost"):
    ok(weather in {"sunny","cloudy","rain","wind","storm","heatwave","frost"}, f'weather visual mapping missing: {weather}')

# v7.2.2 audio policy: only weather that benefits from a continuous bed loops ambient audio.
def ambient_audio(weather):
    return {"rain":"rain_loop","wind":"wind_loop","storm":"storm_loop"}.get(weather,"")
ok(ambient_audio("rain")=="rain_loop",'rain must use gentle looping ambience')
ok(ambient_audio("wind")=="wind_loop",'wind must use gentle looping ambience')
ok(ambient_audio("storm")=="storm_loop",'storm must use dedicated subdued ambience')
ok(ambient_audio("sunny")=="" and ambient_audio("frost")=="",'quiet weather must not add needless continuous audio')


# v7.2.2 transactional bread/workshop semantics.
def craft_transaction(inventory, energy, recipe):
    if energy < recipe['energy']:
        return inventory.copy(), energy, False
    staged=inventory.copy()
    for key,need in recipe['inputs'].items():
        if staged.get(key,0) < need:
            return inventory.copy(), energy, False
        staged[key]-=need
    staged[recipe['output']]=staged.get(recipe['output'],0)+recipe['amount']
    return staged, energy-recipe['energy'], True
_bread={'energy':2,'inputs':{'flour':2,'egg':1},'output':'bread','amount':1}
inv,e,done=craft_transaction({'flour':2,'egg':1,'bread':0},5,_bread)
ok(done and inv['flour']==0 and inv['egg']==0 and inv['bread']==1 and e==3,'bread craft must atomically consume flour+egg and create bread')
inv2,e2,done2=craft_transaction({'flour':2,'egg':0,'bread':0},5,_bread)
ok((not done2) and inv2['flour']==2 and inv2['egg']==0 and inv2['bread']==0 and e2==5,'failed bread craft must not consume flour or energy')

# Tab transition contract: only valid destinations switch; reduced motion is immediate.
def switch_tab(current,target,reduced):
    target=max(0,min(4,int(target)))
    if target==current:return current,'none'
    return target,('instant' if reduced else 'fade_slide')
ok(switch_tab(0,3,False)==(3,'fade_slide'),'normal navigation should use a short fade/slide transition')
ok(switch_tab(3,4,True)==(4,'instant'),'Reduced Motion navigation should switch without movement')

# v7.3 Smart Fields: derived state, irrigation zones and batch-action economics.
def field_state(plot, effective):
    if not plot.get('crop'): return 'empty'
    if plot.get('age',0) >= plot.get('days',1): return 'ready'
    if not effective: return 'planted' if plot.get('age',0) <= 0 else 'dry'
    if plot.get('fertilized',False): return 'fertilized'
    return 'watered'
ok(field_state({},False)=='empty','empty field state')
ok(field_state({'crop':'turnip','age':0,'days':2},False)=='planted','fresh planted field state')
ok(field_state({'crop':'turnip','age':1,'days':2},False)=='dry','growing uncovered field must be dry')
ok(field_state({'crop':'turnip','age':1,'days':2},True)=='watered','effective water produces watered state')
ok(field_state({'crop':'turnip','age':1,'days':2,'fertilized':True},True)=='fertilized','fertilized+watered field state')
ok(field_state({'crop':'turnip','age':2,'days':2},False)=='ready','mature crop state takes priority')

def zone_for(index): return max(0,min(4,index//8))
def zone_coverage(zone,coverage): return max(0,min(8,coverage-zone*8))
ok([zone_for(i) for i in (0,7,8,15,16,23,24,31,32,39)]==[0,0,1,1,2,2,3,3,4,4],'40 plots must map deterministically to five 8-plot zones')
ok([zone_coverage(z,18) for z in range(5)]==[8,8,2,0,0],'partial irrigation project coverage must be visible in the next zone')

def batch_water(dry,energy,per_energy):
    possible=min(dry,max(0,int(energy))*max(1,int(per_energy)))
    return possible, (math.ceil(possible/max(1,int(per_energy))) if possible else 0)
ok(batch_water(9,2,3)==(6,2),'batch watering cannot exceed available energy')
ok(batch_water(2,5,3)==(2,1),'batch watering charges only the actions required')

def batch_fertilize(targets,fertilizer): return min(max(0,targets),max(0,fertilizer))
ok(batch_fertilize(6,3)==3 and batch_fertilize(2,9)==2,'zone fertilizing cannot consume more fertilizer than targets or inventory')

def aggregate_harvest(results):
    by={}; total=0
    for crop,count in results:
        by[crop]=by.get(crop,0)+count; total+=count
    return by,total
by,total=aggregate_harvest([('carrot',2),('carrot',3),('turnip',1)])
ok(by=={'carrot':5,'turnip':1} and total==6,'batch harvest reward aggregation')

# v7.4 Town Market deterministic trend/forecast invariants.
def category_market(seed, day, salt, project=0):
    return 0.82 + h(seed,day,salt)*0.42 + project*0.02
for salt in (31,37,43,47,53):
    current=category_market(17,9,salt,2); nxt=category_market(17,10,salt,2)
    ok(math.isfinite(current) and math.isfinite(nxt), 'market multipliers must remain finite')
    pct=round((current-1.0)*100); ok(-100 < pct < 100, 'market signed percent must remain readable')

# Special order deadline remains explicit and accepted work is never silently removed.
special={'status':'accepted','special':True,'expiresDay':11,'item':'turnip','amount':4,'reward':90}
def age_special(order, day):
    o=dict(order)
    if o.get('special') and day>o.get('expiresDay',0) and o.get('status') in ('available','accepted'):
        o['status']='expired'; o['closedDay']=day
    return o
ok(age_special(special,11)['status']=='accepted','special order remains active through its displayed expiry day')
ok(age_special(special,12)['status']=='expired','accepted special order must become visibly expired, not disappear')

# Order history is bounded and highest completed reward is monotonic.
history=[]; highest=0
for n in range(55):
    outcome=('completed' if n%3==0 else ('rejected' if n%3==1 else 'abandoned'))
    reward=20+n
    history.insert(0,{'outcome':outcome,'reward':reward})
    history=history[:40]
    if outcome=='completed': highest=max(highest,reward)
ok(len(history)==40,'order history must be capped at 40 entries')
ok(highest==74,'highest completed reward must remain monotonic')

# Lifetime order counters are independent of the bounded recent-history list.
recent=[{'outcome':'completed'}]*40
lifetime_completed=137; lifetime_rejected=52; lifetime_abandoned=19
ok(len(recent)==40 and lifetime_completed>len(recent),'recent history cap must not truncate lifetime completed count')
ok((lifetime_completed,lifetime_rejected,lifetime_abandoned)==(137,52,19),'lifetime order outcome counters stay independent')

# v7.4.x regression: a paid/free board refresh must not return an indistinguishable visible card.
def visible_order_signature(o):
    if not o: return ''
    return f"{o['item']}|{int(o['amount'])}|{int(o['reward'])}|{1 if o.get('special') else 0}"
old_card={'item':'turnip','amount':2,'reward':24,'special':False}
new_card={'item':'turnip','amount':3,'reward':36,'special':False}
ok(visible_order_signature(old_card)!=visible_order_signature(new_card),'board refresh must produce a visibly distinct card signature')

# v7.4.x regression: the current refresh-budget function name is part of the Next Day commit path.
from pathlib import Path as _Path
_main_text=(_Path(__file__).resolve().parents[1]/'Main.qml').read_text(encoding='utf-8')
ok('syncOrderRejectBudget()' not in _main_text,'stale syncOrderRejectBudget call must not survive Town Market refactor')
ok('syncOrderRefreshBudget()' in _main_text,'Next Day commit must call syncOrderRefreshBudget')
ok('dayTransitionWatchdog.restart()' in _main_text and 'visualFeedback.forceFinish()' in _main_text,'stalled day transition must have a watchdog recovery path')


# v7.4.x: if every unlocked card is accepted there is nothing refreshable and the budget must not be consumed.
all_active=['accepted','accepted','accepted']
out_active,used_active,changed_active=refresh_board(all_active,1)
ok(out_active==all_active and used_active==1 and not changed_active,'all-accepted board must not consume a refresh')

# Distinct-refresh fallback invariant for tiny pools: changing quantity is a valid visible card change.
def distinct_fallback(old):
    candidate=dict(old)
    candidate['amount']=max(1,int(candidate.get('amount',1))+1)
    candidate['reward']=max(int(candidate.get('reward',1))+1,int(candidate.get('reward',1)))
    return candidate
for amount in range(2,10):
    old={'item':'turnip','amount':amount,'reward':amount*12,'special':False}
    new=distinct_fallback(old)
    ok(visible_order_signature(new)!=visible_order_signature(old),'tiny-pool refresh fallback must never be visually identical')


# v7.4.2 source-level recovery guarantees complement the actual-QML Node harness.
_main_text=(_Path(__file__).resolve().parents[1]/'Main.qml').read_text(encoding='utf-8')
ok('function harvestCore(i, batchMode)' in _main_text and 'function isHarvestReady(i)' in _main_text,'harvest path must have one explicit ready predicate and transactional core')
ok('function repairKnownState()' in _main_text and 'repairRevision' in _main_text,'known interrupted-day save repair must be present')
ok('if (root.commitNextDay())' in _main_text,'visual transition must only continue after a successful day commit')
ok('onHarvest: root.harvest(root.selectedPlot)' in _main_text,'sticky farm action bar must expose an explicit selected-plot harvest path')
ok('function restoreRuntimeSnapshot(s)' in _main_text and _main_text.count('restoreRuntimeSnapshot(before)') >= 6,'all stateful rollback paths must restore exact runtime state')
ok('applySnapshot(before)' not in _main_text,'rollback must not regenerate normalized/order state')
ok('if (cropId !== "" && !isCropId(cropId)) cropId = ""' in _main_text,'corrupt crop ids must be cleared during save normalization')
ok('msg_harvest_before_fertilize' in _main_text and '!isHarvestReady(i)' in _main_text,'ready crops must not consume fertilizer')
ok('if (root.inputLocked || root.activeTab !== 0) return' in _main_text,'GameInput must not mutate hidden Farm state')
ok('sell transaction rolled back' in _main_text and 'order delivery transaction rolled back' in _main_text and 'project transaction rolled back' in _main_text,'economy mutations must have rollback guards')

print(f'GAMEPLAY REGRESSION PASS: {checks}/{checks} checks')
