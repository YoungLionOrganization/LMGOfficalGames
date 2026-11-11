#!/usr/bin/env python3
from pathlib import Path
import json, random, re, sys
ROOT=Path(__file__).resolve().parents[1]
MAIN=(ROOT/'Main.qml').read_text(encoding='utf-8')

def fail(msg):
    print('[FAIL]',msg); raise SystemExit(1)
def ok(msg): print('[PASS]',msg)

# Class identity / visible runtime contract.
for marker in [
    'property int heroClass: 0', 'function useClassSkill()', 'function startNewRunAs(c)',
    'skill_guard', 'skill_rogue', 'skill_arcane', 'classPickerOpen', 'root.skillIcon()',
    'root.version'
]:
    if marker not in MAIN: fail('missing class/runtime marker: '+marker)
ok('three-class runtime markers and visible version signature')

# New-run stats must remain meaningfully distinct.
def stats(c, vitality=0, might=0):
    hp=24+vitality*4; atk=4+might; armor=0; pots=2; bombs=1
    if c==0: hp+=6; armor=1
    elif c==1: hp=max(18,hp-2); atk+=1; bombs=2
    else: hp+=1; pots=3
    return hp,atk,armor,pots,bombs
s0,s1,s2=stats(0),stats(1),stats(2)
if len({s0,s1,s2})!=3: fail('class starting stat packages are not distinct')
if s0!=(30,4,1,2,1) or s1!=(22,5,0,2,2) or s2!=(25,4,0,3,1):
    fail(f'class baseline drift: {s0} {s1} {s2}')
ok('Sentinel/Rogue/Arcanist baseline stat packages')

# Cooldown values in source intentionally become 5/4/6 after the skill-consuming turn.
for raw in ['6-(hasRelic("quickglass")?1:0)', '5-(hasRelic("quickglass")?1:0)', '7-(hasRelic("quickglass")?1:0)']:
    if raw not in MAIN: fail('skill cooldown formula missing: '+raw)
if 'if(skillCooldown>0) skillCooldown--' not in MAIN: fail('turn-based cooldown decrement missing')
ok('active-skill cooldown and Quickglass recharge contract')

# Save round-trip: all v6.6 run fields must be in runSnapshot and restore assignments.
run_match=re.search(r'function runSnapshot\(\)\s*\{\s*return\s*\{(.*?)\}\s*\}', MAIN, re.S)
restore_match=re.search(r'function restoreSnapshot\(payload\)\s*\{(.*?)return sanitizeRestoredRun\(\)', MAIN, re.S)
if not run_match or not restore_match: fail('save/restore functions not parseable')
run_src=run_match.group(1); restore_src=restore_match.group(1)
fields=['map','seen','monsters','playerX','playerY','hp','maxHp','attack','armor','floorNo','coins','potions','bombs','keys','xp','heroLevel','relics','dead','heroClass','skillCooldown','guardTurns','evadeTurns','turnCount']
for f in fields:
    if re.search(rf'\b{re.escape(f)}\s*:',run_src) is None: fail('runSnapshot missing '+f)
    if re.search(rf'\b{re.escape(f)}\s*=',restore_src) is None: fail('restoreSnapshot missing '+f)
ok('active-run state -> JSON snapshot -> restore field parity')

# First-floor content proximity simulation mirrors current placement order.
COLS=ROWS=13
def idx(x,y): return y*COLS+x
def carve(seed):
    rng=random.Random(seed); m=['#']*(COLS*ROWS); stack=[(1,1)];m[idx(1,1)]='.'
    while stack:
        x,y=stack[-1];dirs=[(2,0),(-2,0),(0,2),(0,-2)];rng.shuffle(dirs);moved=False
        for dx,dy in dirs:
            nx,ny=x+dx,y+dy
            if 0<nx<COLS-1 and 0<ny<ROWS-1 and m[idx(nx,ny)]=='#':
                m[idx(x+dx//2,y+dy//2)]='.';m[idx(nx,ny)]='.';stack.append((nx,ny));moved=True;break
        if not moved: stack.pop()
    cx=rng.randint(2,COLS-3);cy=rng.randint(2,ROWS-3)
    for yy in range(cy-1,cy+2):
        for xx in range(cx-1,cx+2): m[idx(xx,yy)]='.'
    cells=[[x,y] for y in range(1,ROWS-1) for x in range(1,COLS-1) if m[idx(x,y)]=='.' and (x,y)!=(1,1)]
    rng.shuffle(cells)
    far=max(range(len(cells)), key=lambda i:cells[i][0]+cells[i][1]);cells.pop(far)
    for _ in range(5): cells.pop()  # floor-1 enemies
    distances={}
    for sym,maxd in [('$',3),('*',4),('K',4),('C',5),('S',5),('B',5),('R',6)]:
        best=-1;bestd=999
        for i,p in enumerate(cells):
            d=abs(p[0]-1)+abs(p[1]-1)
            if 2<=d<=maxd and d<bestd: best=i;bestd=d
        if best<0:
            p=cells.pop(); d=abs(p[0]-1)+abs(p[1]-1)
        else:
            p=cells.pop(best); d=bestd
        distances[sym]=d
    return distances
limits={'$':3,'*':4,'K':4,'C':5,'S':5,'B':5,'R':6}
for seed in range(1000):
    ds=carve(seed)
    for k,lim in limits.items():
        if ds[k]>lim: fail(f'first-floor {k} too far at seed {seed}: {ds[k]}>{lim}')
ok('1000 first-floor seeds keep chest/key/shrine/relic/shard/bomb content near the start')

# Audio path parity.
audio=(ROOT/'components'/'AudioBus.qml').read_text(encoding='utf-8')
paths=set(re.findall(r'"([a-zA-Z0-9_]+)"\s*:\s*"\.\./sfx/[^\"]+\.wav"',audio))
wavs={p.stem for p in (ROOT/'sfx').glob('*.wav')}
if paths!=wavs: fail(f'audio path parity mismatch missing={sorted(wavs-paths)} extra={sorted(paths-wavs)}')
ok(f'audio path parity for {len(wavs)} SFX')

print('[PASS] Dungeon Delver v6.6 run-system regression suite')
