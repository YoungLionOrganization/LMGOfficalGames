#!/usr/bin/env python3
from __future__ import annotations
import json, re, sys, random, wave, subprocess
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
PASS=[]; WARN=[]; FAIL=[]
def ok(x): PASS.append(x)
def warn(x): WARN.append(x)
def fail(x): FAIL.append(x)

def load_json(p):
    try:return json.loads(p.read_text(encoding='utf-8'))
    except Exception as e: fail(f'JSON parse {p.relative_to(ROOT)}: {e}'); return None

def placeholders(s): return sorted(re.findall(r'%\d+',s))

def validate_manifest_i18n():
    m=load_json(ROOT/'manifest.json')
    if not isinstance(m,dict): return None
    if m.get('id')!='dungeon_delver': fail('manifest id must remain dungeon_delver')
    if m.get('version')!='6.6.3': fail('manifest version must be 6.6.3')
    if m.get('package_format')!='rcc-v1': fail('package_format must remain rcc-v1')
    if m.get('entry')!='Main.qml': fail('entry must be Main.qml')
    if int(m.get('save_version',0))!=2: fail('save_version must be 2')
    if int(m.get('plugin_level',0))!=2: fail('plugin_level must be 2')
    caps=set(m.get('capabilities',[]))
    for cap in ['theme','save','settings','i18n','input','lifecycle','audio','stats','achievements','haptics','random']:
        if cap not in caps: fail(f'manifest missing capability: {cap}')
    locales=m.get('locales',[]); required=['en','tr','az','ru','de','fr','es','pt','zh','ja']
    if locales!=required: fail(f'locale list/order mismatch: {locales}')
    docs={}
    for loc in required:
        p=ROOT/'i18n'/f'{loc}.json'
        if not p.is_file(): fail(f'missing locale: {loc}'); continue
        d=load_json(p)
        if isinstance(d,dict): docs[loc]=d
    if 'en' in docs:
        base=set(docs['en'])
        for loc,d in docs.items():
            if set(d)!=base: fail(f'i18n parity {loc}: missing={sorted(base-set(d))} extra={sorted(set(d)-base)}')
            for k,v in d.items():
                if not isinstance(v,str) or not v.strip(): fail(f'empty translation {loc}:{k}')
                if k in docs['en'] and placeholders(v)!=placeholders(docs['en'][k]): fail(f'placeholder mismatch {loc}:{k}')
        qml='\n'.join(p.read_text(encoding='utf-8') for p in ROOT.rglob('*.qml'))
        used=set(re.findall(r'tr\("([^"]+)"',qml))
        missing=sorted(used-base)
        if missing: fail(f'QML translation keys missing: {missing}')
        else: ok(f'i18n parity/placeholders/QML coverage: {len(docs)} locales, {len(base)} keys')
    return m

def validate_qrc(manifest):
    try: tree=ET.parse(ROOT/'mod.qrc')
    except Exception as e: fail(f'mod.qrc parse: {e}'); return
    qrs=tree.getroot().findall('qresource')
    if len(qrs)!=1: fail('mod.qrc must contain exactly one qresource')
    aliases=set();count=0
    for qr in qrs:
        prefix=qr.attrib.get('prefix','')
        if prefix!='/': fail(f'invalid RCC inner prefix {prefix!r}; host-mounted plugins must use /')
        for f in qr.findall('file'):
            rel=(f.text or '').strip(); alias=f.attrib.get('alias',rel)
            if alias in aliases: fail(f'duplicate QRC alias: {alias}')
            aliases.add(alias);count+=1
            if not (ROOT/rel).is_file(): fail(f'QRC references missing file: {rel}')
    expected={'Main.qml','manifest.json','GameButton.qml','ThemedSvgIcon.qml','components/DungeonCell.qml','components/AudioBus.qml','assets/icon.png','assets/characters/hero_knight.svg','assets/enemies/guardian.svg','assets/items/shard.svg','assets/environment/wall_keep.svg'}
    expected.update(str(p.relative_to(ROOT)).replace('\\','/') for p in (ROOT/'i18n').glob('*.json'))
    expected.update(str(p.relative_to(ROOT)).replace('\\','/') for p in (ROOT/'sfx').glob('*.wav'))
    missing=sorted(expected-aliases)
    if missing: fail(f'QRC missing runtime resources: {missing}')
    if manifest:
        for k in ['entry','icon_path']:
            v=str(manifest.get(k,'')).lstrip('/')
            if v not in aliases: fail(f'manifest {k} not present in QRC: {v}')
    mapped={f':/mods/dungeon_delver/{a.lstrip("/")}' for a in aliases}
    if ':/mods/dungeon_delver/Main.qml' not in mapped: fail('host-mounted entry path missing')
    if ':/mods/dungeon_delver/mods/dungeon_delver/Main.qml' in mapped: fail('doubled host mount path detected')
    ok(f'QRC prefix/mount/aliases/resources: {count} resources')

def validate_assets():
    svgs=list((ROOT/'assets').rglob('*.svg'))
    if len(svgs)<20: fail(f'expected >=20 SVG gameplay assets, found {len(svgs)}')
    for p in svgs:
        try: ET.parse(p)
        except Exception as e: fail(f'SVG parse {p.relative_to(ROOT)}: {e}')
    # Player/enemy art must be real multicolor SVG art, not the old monochrome stencil placeholders.
    for art in list((ROOT/'assets'/'characters').glob('*.svg')) + list((ROOT/'assets'/'enemies').glob('*.svg')):
        txt=art.read_text(encoding='utf-8')
        fills={c.lower() for c in re.findall(r'fill="(#[0-9a-fA-F]{6})"',txt)}
        if len(fills)<2: fail(f'monochrome/stencil actor SVG remains: {art.relative_to(ROOT)}')
    wavs=list((ROOT/'sfx').glob('*.wav'))
    if len(wavs)<20: fail(f'expected >=20 SFX assets, found {len(wavs)}')
    audio_bus=(ROOT/'components'/'AudioBus.qml').read_text(encoding='utf-8') if (ROOT/'components'/'AudioBus.qml').is_file() else ''
    local_audio=(ROOT/'components'/'LocalAudioFallback.qml').read_text(encoding='utf-8') if (ROOT/'components'/'LocalAudioFallback.qml').is_file() else ''
    if 'property bool enabled:' in audio_bus or 'property bool enabled:' in local_audio:
        fail('audio QML shadows inherited QQuickItem.enabled and would emit property-cache override warnings')
    if re.search(r'GameAudio\.(?:playEffect|preload)\([^\n\)]*,', audio_bus): fail('multi-argument GameAudio host calls are forbidden; host contract is single URL')
    bus_names=set(re.findall(r'"([a-zA-Z0-9_]+)"\s*:\s*"\.\./sfx/[^"]+\.wav"',audio_bus))
    wav_names={p.stem for p in wavs}
    if wav_names-bus_names: fail(f'SFX not included in AudioBus path table: {sorted(wav_names-bus_names)}')
    if bus_names-wav_names: fail(f'AudioBus references missing SFX: {sorted(bus_names-wav_names)}')
    for p in wavs:
        try:
            with wave.open(str(p),'rb') as w:
                if w.getnchannels()!=1: warn(f'{p.name}: non-mono SFX')
                if w.getsampwidth()!=2: fail(f'{p.name}: expected 16-bit PCM')
                if w.getframerate()<16000: fail(f'{p.name}: sample rate too low')
                if w.getnframes()<=0: fail(f'{p.name}: empty WAV')
        except Exception as e: fail(f'WAV parse {p.name}: {e}')
    ok(f'asset validation: {len(svgs)} SVGs, {len(wavs)} WAV SFX')

def strip_strings_comments(t):
    t=re.sub(r'//.*?$','',t,flags=re.M); t=re.sub(r'/\*.*?\*/','',t,flags=re.S)
    t=re.sub(r'"(?:\\.|[^"\\])*"','""',t); t=re.sub(r"'(?:\\.|[^'\\])*'","''",t)
    return t

def validate_qml_static():
    main=(ROOT/'Main.qml').read_text(encoding='utf-8'); allqml='\n'.join(p.read_text(encoding='utf-8') for p in ROOT.rglob('*.qml'))
    for p in ROOT.rglob('*.qml'):
        t=p.read_text(encoding='utf-8'); s=strip_strings_comments(t)
        for a,b in [('{','}'),('(',')'),('[',']')]:
            if s.count(a)!=s.count(b): fail(f'delimiter imbalance {a}{b}: {p.relative_to(ROOT)}')
        if 'InnerText' in t: fail(f'known invalid property InnerText: {p.relative_to(ROOT)}')
    markers={
      'desktop arrows':'Qt.Key_Left','desktop WASD':'Qt.Key_A','mobile board swipe':'onReleased:function(mouse)','large D-pad SVG':'assets/ui/arrow_up.svg','physical keyboard fallback':'nativeScanCode',
      'canonical JSON save':'GameSave.set("snapshotJson",JSON.stringify(snapshotForSave()))','canonical restore':'JSON.parse(json)',
      'service readiness':'function serviceContextReady()','legacy migration':'function migrateLegacy()','lifecycle save':'function onBackgrounded(){root.forceSave()}',
      'theme runtime rebind':'function onThemeChanged(){root.themeRevision++','i18n runtime rebind':'function onLocaleChanged(){root.languageRevision++',
      'audio bus route':'audioLoader.item.play(name)','haptics gate':'if (!vibrationEnabled) return',
      'Soul Shards':'property int soulShards','meta upgrades':'property var upgrades','shop':'function buySupply','legacy shop':'function buyUpgrade',
      'boss content':'guardianTemplate','relic content':'function relicFound','three art styles':'property int artStyle','playable classes':'property int heroClass','active class skill':'function useClassSkill()','class picker':'property bool classPickerOpen','first-floor near-content':'placeNearStart(cells,"*",4)','version signature':'root.version','sound test':'tr("test_sound"','safe area':'root.SafeArea.margins'
    }
    for label,marker in markers.items():
        if marker not in main: fail(f'missing QML contract: {label}')
    for label,marker in {'audio host backend':'GameAudio.playEffect(url)','audio local MediaPlayer':'MediaPlayer {'}.items():
        if marker not in allqml: fail(f'missing QML contract: {label}')
    for enemy in ['slime','goblin','skeleton','bat','cultist','ogre','wraith','guardian']:
        if f'"{enemy}"' not in main: fail(f'enemy content missing: {enemy}')
    for item in ['"$"','"!"','"K"','"C"','"^"','"S"','"B"','"R"','"*"']:
        if item not in main: fail(f'loot/event tile missing: {item}')
    cell=(ROOT/'components'/'DungeonCell.qml').read_text(encoding='utf-8')
    for marker in ['property int heroClass', 'Image {', '../assets/characters/hero_knight.svg', '../assets/enemies/guardian.svg']:
        if marker not in cell: fail(f'DungeonCell visual runtime contract missing: {marker}')
    if 'ThemedSvgIcon' in cell: fail('DungeonCell still tints gameplay SVGs through ThemedSvgIcon; multicolor actor/item art would be flattened')
    unsafe=[('unguarded lifecycle target',r'target\s*:\s*Lifecycle\b'),('unguarded i18n target',r'target\s*:\s*GameI18n\b'),('unguarded input target',r'target\s*:\s*GameInput\b')]
    for label,pat in unsafe:
        if re.search(pat,main): fail(label)
    if re.search(r'(?<![A-Za-z0-9_\.])SafeArea\.margins',main): fail('bare/self SafeArea margins risk detected')
    ok('QML static/save/input/theme/i18n/audio/content contracts')

def validate_save_contract():
    main=(ROOT/'Main.qml').read_text(encoding='utf-8')
    fields=['map','seen','monsters','playerX','playerY','hp','maxHp','attack','armor','floorNo','coins','potions','bombs','keys','xp','heroLevel','relics','soulShards','upgrades','bestFloor','totalKills','soundEnabled','vibrationEnabled','artStyle','heroClass','skillCooldown','guardTurns','evadeTurns','turnCount']
    for f in fields:
        if f+':' not in main and f+'=' not in main: fail(f'save field not found in snapshot/restore source: {f}')
    for marker in ['campaignSnapshot','runSnapshot','snapshotForSave','restoreSnapshot','migrateLegacy','forceSave','GameSave.save("autosave")']:
        if marker not in main: fail(f'save marker missing: {marker}')
    ok('canonical campaign + active-run save/restore/migration contract')

def validate_version(manifest):
    if not manifest:return
    v=str(manifest.get('version',''))
    main=(ROOT/'Main.qml').read_text(encoding='utf-8')
    if f'readonly property string version: "{v}"' not in main: fail('Main.qml version mismatch')
    for name in ['build_mod.bat','build_mod.sh']:
        t=(ROOT/name).read_text(encoding='utf-8')
        if v not in t: fail(f'{name} version mismatch')
        if 'dungeon_delver' not in t: fail(f'{name} output id mismatch')
    smoke=(ROOT/'tools/qt_rcc_smoke/rcc_smoke.cpp').read_text(encoding='utf-8')
    if v not in smoke or '/mods/dungeon_delver' not in smoke: fail('Qt smoke version/mount mismatch')
    readme=ROOT/'README.md'
    if not readme.is_file(): fail('README.md missing')
    elif v not in readme.read_text(encoding='utf-8'): fail('README version mismatch')
    ok(f'version consistency: {v}')

def carve(seed,floor_no):
    rng=random.Random(seed); cols=rows=13
    m=['#']*(cols*rows); idx=lambda x,y:y*cols+x
    stack=[(1,1)];m[idx(1,1)]='.'
    while stack:
        x,y=stack[-1];dirs=[(2,0),(-2,0),(0,2),(0,-2)];rng.shuffle(dirs);moved=False
        for dx,dy in dirs:
            nx,ny=x+dx,y+dy
            if 0<nx<cols-1 and 0<ny<rows-1 and m[idx(nx,ny)]=='#':
                m[idx(x+dx//2,y+dy//2)]='.';m[idx(nx,ny)]='.';stack.append((nx,ny));moved=True;break
        if not moved:stack.pop()
    for _ in range(min(5,1+floor_no//3)):
        cx=rng.randint(2,cols-3);cy=rng.randint(2,rows-3)
        for yy in range(cy-1,cy+2):
            for xx in range(cx-1,cx+2):m[idx(xx,yy)]='.'
    return m

def validate_generation():
    cols=rows=13; idx=lambda x,y:y*cols+x
    for seed in range(250):
        floor_no=1+seed%30;m=carve(seed,floor_no)
        if m[idx(1,1)]!='.': fail('generation start not floor');return
        q=[(1,1)];seen={(1,1)}
        while q:
            x,y=q.pop(0)
            for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]:
                nx,ny=x+dx,y+dy
                if 0<=nx<cols and 0<=ny<rows and (nx,ny) not in seen and m[idx(nx,ny)]!='#':seen.add((nx,ny));q.append((nx,ny))
        floors=sum(1 for v in m if v=='.')
        if len(seen)!=floors: fail(f'generation disconnected at seed {seed}');return
        if floors<45: fail(f'generation too sparse at seed {seed}: {floors}');return
        enemy_count=min(17,4+floor_no+floor_no//3)
        if floor_no==1:
            # 3 coins + potion + key + chest + shrine + bomb + relic + Soul Shard
            item_count=10
        else:
            item_count=min(6,3+floor_no//3)+(1+(1 if floor_no%3==0 else 0))+min(2,1+floor_no//8)+min(2,1+floor_no//6)+min(4,floor_no//2)+1+1+(1 if floor_no%2==0 else 0)+1
        required=1+enemy_count+item_count+(1 if floor_no%5==0 else 0)
        if floors-1<required: fail(f'generation lacks placement capacity at seed {seed}: free={floors-1}, required={required}');return
    ok('procedural generation simulation: 250 connected 13x13 floors with content-placement capacity')

def validate_build_contract():
    for p in [ROOT/'tools/qt_rcc_smoke/CMakeLists.txt',ROOT/'tools/qt_rcc_smoke/rcc_smoke.cpp']:
        if not p.is_file(): fail(f'missing post-build verifier: {p.relative_to(ROOT)}')
    for name in ['build_mod.bat','build_mod.sh']:
        t=(ROOT/name).read_text(encoding='utf-8')
        for marker in ['validate_source.py','--binary','qt_rcc_smoke','dungeon_delver_rcc_smoke','DUNGEON_DELVER_SKIP_QT_SMOKE']:
            if marker not in t: fail(f'{name} missing build gate marker: {marker}')
    smoke=(ROOT/'tools/qt_rcc_smoke/rcc_smoke.cpp').read_text(encoding='utf-8').lower()
    for marker in ['qresource::registerresource','/mods/dungeon_delver','qqmlcomponent','referenceerror','typeerror','unable to assign','expected token']:
        if marker not in smoke: fail(f'post-build verifier missing marker: {marker}')
    ok('strict RCC build + mounted QQmlEngine smoke verifier contract')


def validate_run_systems():
    script=ROOT/'tools'/'test_run_systems.py'
    if not script.is_file():
        fail('missing run-system regression script')
        return
    try:
        cp=subprocess.run([sys.executable,str(script)],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=30)
    except Exception as e:
        fail(f'run-system regression runner failed: {e}')
        return
    if cp.returncode!=0:
        fail('run-system regression failed:\n'+cp.stdout[-4000:])
    else:
        lines=[x for x in cp.stdout.splitlines() if x.strip()]
        ok('run-system regression: '+(lines[-1] if lines else 'PASS'))

def main():
    manifest=validate_manifest_i18n();validate_qrc(manifest);validate_assets();validate_qml_static();validate_save_contract();validate_build_contract();validate_generation();validate_run_systems();validate_version(manifest)
    print('Dungeon Delver source validation');print('='*40)
    for x in PASS:print('[PASS]',x)
    for x in WARN:print('[WARN]',x)
    for x in FAIL:print('[FAIL]',x)
    print(f'\nResult: {"PASS" if not FAIL else "FAIL"} ({len(PASS)} checks, {len(WARN)} warnings, {len(FAIL)} errors)')
    return 0 if not FAIL else 1
if __name__=='__main__': raise SystemExit(main())
