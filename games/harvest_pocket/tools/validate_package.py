#!/usr/bin/env python3
from pathlib import Path
import json, re, sys, unicodedata, xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
errors=[]; checks=0

def check(cond,msg):
    global checks
    checks+=1
    if not cond: errors.append(msg)

def load_json(p):
    global checks
    checks+=1
    try: return json.loads(p.read_text(encoding='utf-8'))
    except Exception as e:
        errors.append(f'JSON parse failed {p.relative_to(ROOT)}: {e}')
        return {}

manifest=load_json(ROOT/'manifest.json')
check(manifest.get('id')=='harvest_pocket','manifest id mismatch')
check(manifest.get('version')=='7.4.2','manifest version must be 7.4.2')
check(manifest.get('save_version')==1,'host save_version must remain 1 for v6.4 slot compatibility; internal schema is v4')
check(manifest.get('package_format')=='rcc-v1','package_format mismatch')
check(manifest.get('entry')=='Main.qml','entry mismatch')
check(manifest.get('icon_path')=='assets/icon.svg','market icon must be SVG')
check(manifest.get('plugin_level')==2,'market RCC must stay Level 2; native companion is not required for this low-overhead turn-based game')
expected_locales=['en','tr','az','ru','de','fr','es','pt','zh','ja']
check(manifest.get('locales')==expected_locales,'locale list/order mismatch')
check('reducedMotion' in manifest.get('settings_schema',{}),'reducedMotion setting missing')

# QRC
try:
    qtree=ET.parse(ROOT/'mod.qrc')
    qres=qtree.getroot().find('qresource')
    check(qres is not None and qres.attrib.get('prefix')=='/','QRC prefix must be /')
    qrc_files=[n.text for n in qres.findall('file')]
except Exception as e:
    errors.append(f'QRC parse failed: {e}'); qrc_files=[]
for rel in qrc_files:
    check((ROOT/rel).is_file(),f'QRC missing file: {rel}')
check(len(qrc_files)==len(set(qrc_files)),'duplicate QRC file entries')

# Every runtime resource should be packaged.
excluded={'build.bat','build_mod.bat','build_mod.sh','README.md','BUG_HUNTER_AUDIT.md','GAMER_AUDIT.md','VALIDATION_REPORT.md','SAVE_AUDIT.md'}
expected=[]
for p in ROOT.rglob('*'):
    if not p.is_file(): continue
    rel=p.relative_to(ROOT).as_posix()
    if rel.startswith('tools/') or rel.startswith('dist/') or rel.startswith('release/') or rel in excluded or p.suffix.lower() in {'.py','.pyc'}: continue
    expected.append(rel)
for rel in expected:
    check(rel in qrc_files,f'runtime resource absent from QRC: {rel}')

# SVG/XML integrity and no embedded raster data.
svgs=list((ROOT/'assets').rglob('*.svg'))
check(len(svgs)>=200,f'expected at least 200 SVG assets, got {len(svgs)}')
for p in svgs:
    try:
        tree=ET.parse(p); root=tree.getroot()
        check(root.tag.endswith('svg'),f'not SVG root: {p.relative_to(ROOT)}')
        check('viewBox' in root.attrib,f'SVG missing viewBox: {p.relative_to(ROOT)}')
        txt=p.read_text(encoding='utf-8').lower()
        check('data:image/' not in txt,f'embedded raster in SVG: {p.relative_to(ROOT)}')
    except Exception as e:
        errors.append(f'SVG parse failed {p.relative_to(ROOT)}: {e}')
# no raster gameplay assets
for p in (ROOT/'assets').rglob('*'):
    if p.is_file(): check(p.suffix.lower() not in {'.png','.jpg','.jpeg','.webp','.gif'},f'raster gameplay asset forbidden: {p.relative_to(ROOT)}')

# Required content counts.
for crop in ['turnip','carrot','potato','berry','corn','tomato','pepper','sunflower','pumpkin','beet','wheat','onion','crystal','winterroot','snowpea','frostberry']:
    for stage in range(1,6): check((ROOT/f'assets/crops/stages/{crop}_{stage}.svg').is_file(),f'missing crop stage {crop}_{stage}')
for animal in ['chicken','duck','cow','goat','sheep','bee']:
    for state in ['idle','happy','sleep']: check((ROOT/f'assets/animals/{animal}_{state}.svg').is_file(),f'missing animal state {animal}_{state}')
for building in ['coop','barn','apiary','mill','feed_mixer','preserver','dairy','kitchen']:
    check((ROOT/f'assets/buildings/{building}.svg').is_file(),f'missing building SVG {building}')
for weather in ['sunny','cloudy','rain','wind','storm','heatwave','frost']:
    check((ROOT/f'assets/weather/{weather}.svg').is_file(),f'missing weather SVG {weather}')

for product in ['turnip','carrot','potato','berry','corn','tomato','pepper','sunflower','pumpkin','beet','wheat','onion','crystal','winterroot','snowpea','frostberry','egg','duck_egg','milk','goat_milk','wool','honey','flour','cornmeal','berry_jam','tomato_sauce','cheese','goat_cheese','feed','bread']:
    check((ROOT/f'assets/products/{product}.svg').is_file(),f'missing product SVG {product}')
for project in ['irrigation','town_market','bakery','veterinary','seed_lab','railway','festival','research_center']:
    check((ROOT/f'assets/projects/{project}.svg').is_file(),f'missing project SVG {project}')
for tool in ['hoe','watering_basic','watering_copper','watering_steel','watering_gold','watering_master','fertilizer_bag','basket','sprinkler','feed_bag','pail','shears']:
    check((ROOT/f'assets/tools/{tool}.svg').is_file(),f'missing tool SVG {tool}')
for field in ['soil_dry','soil_wet','soil_fertile','soil_winter','greenhouse_overlay','sprinkler_overlay']:
    check((ROOT/f'assets/field/{field}.svg').is_file(),f'missing field SVG {field}')
for ui in ['farm','animals','market','workshop','journal','water','fertilizer','locked','xp','order','coin','energy','reputation','seed','quality','next_day','warning']:
    check((ROOT/f'assets/ui/{ui}.svg').is_file(),f'missing UI SVG {ui}')

# v7.3.0 verified host-audio assets. PCM WAV is used for broad QSoundEffect support.
import wave
audio_names=['plant','water','sprinkler','harvest','sell','craft','animal','day','purchase','order_accept','order_deliver','order_reject','animal_buy','workshop','upgrade','tab','fertilize','rain_loop','wind_loop','storm_loop']
for audio_name in audio_names:
    rel=f'assets/audio/{audio_name}.wav'
    ap=ROOT/rel
    check(ap.is_file(),f'missing audio asset: {rel}')
    check(rel in qrc_files,f'audio asset absent from QRC: {rel}')
    if ap.is_file():
        try:
            with wave.open(str(ap),'rb') as wf:
                check(wf.getnchannels()==1,f'audio must remain mono/low-overhead: {rel}')
                check(wf.getsampwidth()==2,f'audio must remain 16-bit PCM: {rel}')
                check(wf.getframerate() in (22050,44100),f'unexpected sample rate: {rel}')
                check(wf.getnframes()>0,f'empty audio asset: {rel}')
        except Exception as e:
            errors.append(f'WAV parse failed {rel}: {e}')

# i18n parity / blanks / placeholders / copied long English fallbacks.
locale_data={code:load_json(ROOT/f'i18n/{code}.json') for code in expected_locales}
en=locale_data['en']; en_keys=set(en)
check(len(en_keys)>=170,f'expected >=170 translation keys, got {len(en_keys)}')
ph=re.compile(r'%\d+')
copy_whitelist={'quality_premium'}
for code,data in locale_data.items():
    check(set(data)==en_keys,f'i18n key parity failed for {code}')
    for key in en_keys:
        val=data.get(key)
        check(isinstance(val,str) and val.strip()!='',f'empty translation {code}:{key}')
        check(set(ph.findall(val or ''))==set(ph.findall(en[key])),f'placeholder mismatch {code}:{key}')
        if isinstance(val,str):
            check('\ufffd' not in val,f'Unicode replacement/mojibake marker in {code}:{key}')
            check(unicodedata.normalize('NFC',val)==val,f'non-NFC translation encoding in {code}:{key}')
            check(all(ord(c)>=32 or c in '\n\t' for c in val),f'control character in {code}:{key}')
        if code!='en' and key not in copy_whitelist and len(en[key])>=18 and ' ' in en[key]:
            check(val != en[key],f'English fallback copy in {code}:{key}')
    if code!='en':
        copied=sum(1 for key,val in data.items() if key not in copy_whitelist and val==en.get(key) and len(str(val))>=8)
        check(copied <= 15,f'too many untranslated English copies in {code}: {copied}')

# QML / JS source structural and performance policy checks.
qml_files=list(ROOT.glob('*.qml'))
js_files=list((ROOT/'js').glob('*.js'))
for p in qml_files+js_files:
    text=p.read_text(encoding='utf-8')
    # User requested no Unicode/emoji icon characters in gameplay source. i18n is excluded by design.
    check(all(ord(c)<128 for c in text),f'non-ASCII visual/source symbol found in {p.name}')
    check('MultiEffect' not in text,f'MultiEffect forbidden in low-end target: {p.name}')
    check('ShaderEffect' not in text,f'ShaderEffect forbidden in low-end target: {p.name}')
    check('ParticleSystem' not in text,f'ParticleSystem forbidden in low-end target: {p.name}')
    check('Canvas {' not in text,f'Canvas forbidden in optimized gameplay path: {p.name}')
    # QML child object declarations are not JavaScript statements. A semicolon
    # after a closing child object (for example `UiText { ... }; UiText { ... }`)
    # is accepted by rcc as plain resource data but rejected by the QML parser.
    # This exact failure class previously surfaced as `Unexpected token ';'`.
    child_object_separator = re.compile(r'}\s*;\s*[A-Z][A-Za-z0-9_]*\s*{')
    check(child_object_separator.search(text) is None,
          f'QML parser-risk child-object semicolon separator found in {p.name}')
    # Lightweight delimiter scanner ignoring strings and comments.
    stack=[]; pairs={')':'(',']':'[','}':'{'}; quote=None; esc=False; line_comment=False; block_comment=False
    i=0
    while i < len(text):
        ch=text[i]; nxt=text[i+1] if i+1 < len(text) else ''
        if line_comment:
            if ch=='\n': line_comment=False
            i+=1; continue
        if block_comment:
            if ch=='*' and nxt=='/': block_comment=False; i+=2; continue
            i+=1; continue
        if quote:
            if esc: esc=False
            elif ch=='\\': esc=True
            elif ch==quote: quote=None
            i+=1; continue
        if ch=='/' and nxt=='/': line_comment=True; i+=2; continue
        if ch=='/' and nxt=='*': block_comment=True; i+=2; continue
        if ch in "'\"": quote=ch; i+=1; continue
        if ch in '([{': stack.append(ch)
        elif ch in ')]}':
            if not stack or stack[-1]!=pairs[ch]:
                errors.append(f'delimiter mismatch in {p.name}'); break
            stack.pop()
        i+=1
    check(not stack,f'unclosed delimiter in {p.name}')

main=(ROOT/'Main.qml').read_text(encoding='utf-8')
check(main.count('Timer {')==4,f'Main.qml must contain exactly 4 shared timers (startup retry + save debounce + visual pulse + transition watchdog), got {main.count("Timer {")}')
check('function saveServiceReady()' in main and 'function ensureInitialized()' in main,'host service readiness gate missing')
check('typeof GameSave.load === "function"' in main and 'typeof GameSave.get === "function"' in main and 'typeof GameSave.set === "function"' in main and 'typeof GameSave.save === "function"' in main,'startup readiness must use verified GameSave methods')
check('GameSave.gameId' not in main and 'GameSave.ready' not in main,'unverified GameSave readiness properties must not be guessed')
check('GameI18n.gameId' not in main and 'GameI18n.language' not in main,'unverified GameI18n scope/language properties must not be guessed')
check('readonly property int saveSchema: 4' in main,'internal canonical save schema must be v4')
check('GameSave.registerMigration' not in main,'unverified GameSave.registerMigration API must not be guessed')
check('Qt.callLater(root.ensureInitialized)' in main,'deferred service-safe initialization missing')
check('id: initializationRetry' in main and 'running: !root.initializationDone' in main,'startup service retry timer missing')
check('target: typeof Lifecycle !== "undefined" ? Lifecycle : null' in main,'lifecycle save fallback missing')
check(main.count('ignoreUnknownSignals: true') >= 2,'verified host Connections should tolerate version-specific signals')
check('Viewport.' not in main,'unverified host Viewport API must not be guessed; host owns the game viewport')
check('audio' in manifest.get('capabilities',[]),'verified audio capability declaration missing')
check('function audioUrl(name)' in main and 'function playSfx(name, gain)' in main and 'function preloadAudio()' in main,'audio adapter/preload helpers missing')
check('typeof GameAudio !== "undefined"' in main and 'GameAudio.playEffect(source, level, "sfx")' in main,'modern GameAudio SFX path missing')
check('typeof Audio !== "undefined"' in main and 'Audio.playUrl(source, level)' in main,'legacy Audio.playUrl fallback missing')
check('GameAudio.playMusic(audioUrl(desired), true, "ambient")' in main and 'GameAudio.stopMusic()' in main,'ambient GameAudio loop/stop path missing')
check('GameAudio.pauseAll()' in main and 'GameAudio.resumeAll()' in main,'audio lifecycle pause/resume integration missing')
check('function switchTab(index)' in main and 'id: tabSwitchAnimation' in main and 'root.switchTab(index)' in main,'menu transition director missing')
check('root.reducedMotion' in main.split('function switchTab(index)',1)[1].split('SequentialAnimation',1)[0],'menu transition must bypass motion under Reduced Motion')
for action_sound in ['purchase','order_accept','order_deliver','order_reject','animal_buy','workshop','upgrade','fertilize','tab']:
    check(f'playSfx(\"{action_sound}\"' in main, f'action audio hook missing: {action_sound}')
check('Build the complete transaction before mutating live state' in main and 'qualityInventory = qi' in main,'transactional multi-ingredient crafting fix missing')
check('function settingBool(key, fallback)' in main and 'typeof GameSettings === "undefined"' in main,'GameSettings capability fallback missing')
check('target: typeof GameInput !== "undefined" ? GameInput : null' in main,'GameInput capability fallback missing')
check('function haptic(level)' in main and 'typeof Haptics === "undefined"' in main,'Haptics capability fallback missing')
for component_name in ["UiButton.qml", "IconButton.qml"]:
    component_text=(ROOT/component_name).read_text(encoding="utf-8")
    check('function pulseHaptic()' in component_text and 'typeof Haptics !== "undefined"' in component_text, f'{component_name} Haptics fallback missing')
    for line_no,line in enumerate(component_text.splitlines(),1):
        if ('onTapped' in line or 'Keys.onPressed' in line) and 'Haptics.' in line:
            errors.append(f'unguarded direct Haptics call in {component_name}:{line_no}')
haptic_body=main.split('function haptic(level)',1)[1].split('function tr(key)',1)[0] if 'function haptic(level)' in main and 'function tr(key)' in main else ''
check('root.haptic(' not in haptic_body,'haptic helper must not recursively call itself')
check('property real coins:' in main,'coins must use QML real to avoid 32-bit late-game overflow')
check('effectiveSprinkler' in main,'Next Day warning must include irrigation-project sprinkler coverage')
check('bucketTotal < totalStock' in main and 'bucketTotal > totalStock' in main,'quality inventory repair invariant missing')
for p in qml_files:
    if p.name!='Main.qml': check('Timer {' not in p.read_text(encoding='utf-8'),f'per-component Timer forbidden: {p.name}')
check('GameSave.set("snapshot_v4"' in main,'canonical snapshot_v4 write missing')
check('function compatibilitySnapshotV3()' in main and 'GameSave.set("snapshot_v3"' in main,'downgrade-safe v3 compatibility mirror missing')
check('GameSave.set("snapshot_v2"' in main,'downgrade-safe snapshot_v2 compatibility mirror missing')
check('function migrateLegacyV1()' in main,'v1 -> v3 migration missing')
check('landStage = 4' in main,'legacy 40-plot preservation missing')
check('property bool legacyCropAccess: false' in main,'legacy crop-access compatibility flag missing')
check('legacyCropAccess = true' in main,'legacy migration must enable original crop compatibility')
check('legacyCropAccess: legacyCropAccess' in main,'legacy crop-access flag must persist in canonical snapshot')
check('crop.id === "pumpkin"' in main and 'crop.id === "crystal"' in main,'legacy six-crop compatibility gate missing')
check('GameSave.set("plots"' not in main,'direct nested plot GameSave write must not be used')
check('function consumeItem(' in main,'canonical inventory consume path missing')
check('function triggerVisualAction(' in main,'handling animation trigger missing')
farmplot=(ROOT/'FarmPlot.qml').read_text(encoding='utf-8')
check('reducedMotion' in main and 'reducedMotion' in farmplot,'reduced motion behavior missing')
check('swayBucket' in farmplot and '% 6' in farmplot,'selective crop idle-animation bucketing missing')
animal_sprite=(ROOT/'AnimalSprite.qml').read_text(encoding='utf-8')
check('activityBucket' in animal_sprite and '% 4' in animal_sprite and 'activeMove' in animal_sprite,'selective animal idle-animation bucketing missing')
check('property int animalCount:' in main and 'property int displayAnimalCount:' in main,'animal population delegate must use explicit non-shadowing count properties')
check('model: animalCard.displayAnimalCount' in main,'representative animal sprite cap missing')
check('model: Math.min(6, count)' not in main,'nested Repeater must not bind model to its own shadowed count property')
check('visible:o&&' not in main and 'visible: o&&' not in main,'nullable order objects must be coerced to bool before visible bindings')
check('visible: !!orderCard.o && orderCard.o.status === "accepted"' in main and 'visible: !!orderCard.o && orderCard.o.status === "available"' in main,'order visibility bool guards missing')
check('!!processingBuilt[building.id]' in main and '!!processingBuilt[recipe.building]' in main,'processing visibility must not assign undefined map entries to bool')
check('visible: !!root.plotData' in farmplot,'FarmPlot nullable plotData visibility must be bool-safe')
uipanel=(ROOT/'UiPanel.qml').read_text(encoding='utf-8')
check('visible: !!root.spec' in uipanel,'UiPanel theme texture visibility must be bool-safe')
check('orderSlotUnlocked' in main and 'deliverOrder' in main,'3-slot explicit order lifecycle missing')
check('projectLevels' in main and 'FarmData.projects.length' in main,'Community Projects missing')
check('FarmData.hash01' in main,'deterministic daily RNG missing')
check('GameRandom.next' not in main,'session RNG must not drive market/weather/orders')

# Hardcoded user-facing Text literals in main should be translation expressions.
for lineno,line in enumerate(main.splitlines(),1):
    m=re.search(r'\btext\s*:\s*"([^"\\]*)"',line)
    if m and m.group(1).strip():
        errors.append(f'hardcoded Text literal Main.qml:{lineno}: {m.group(1)!r}')

# Definitions count via stable IDs in FarmData.js.
data=(ROOT/'js/FarmData.js').read_text(encoding='utf-8')
check(data.count('category:"')==16,'FarmData must define 16 crops')
check(data.count('productKey:"')==6,'FarmData must define 6 animal species')
check(data.count('output:"')==8,'FarmData must define 8 processing recipes')
check(data.count('unlockRep:')==8,'FarmData must define 8 community projects')
check('var landCounts = [12,20,28,34,40]' in data,'land progression mismatch')
check('var sprinklerCoverage = [0,8,16,24,32,40]' in data,'sprinkler progression mismatch')
check('var greenhouseCoverage = [0,8,16,24,32,40]' in data,'greenhouse progression mismatch')
check('var wateringCounts = [1,2,3,5,9]' in data,'watering tool progression mismatch')

# v7.0.3 runtime/visual regression gates.
for crop_id in ['turnip','carrot','potato','berry','corn','tomato','pepper','sunflower','pumpkin','beet','wheat','onion','crystal','winterroot','snowpea','frostberry']:
    mature=(ROOT/f'assets/crops/stages/{crop_id}_5.svg').read_text(encoding='utf-8')
    check(len(mature) >= 350, f'mature crop SVG too visually sparse: {crop_id}')
for animal_id in ['chicken','duck','cow','goat','sheep','bee']:
    idle=(ROOT/f'assets/animals/{animal_id}_idle.svg').read_text(encoding='utf-8')
    happy=(ROOT/f'assets/animals/{animal_id}_happy.svg').read_text(encoding='utf-8')
    sleep=(ROOT/f'assets/animals/{animal_id}_sleep.svg').read_text(encoding='utf-8')
    check(idle != happy and idle != sleep, f'animal visual states must be distinct: {animal_id}')
for soil in ['soil_dry','soil_wet','soil_fertile','soil_winter']:
    txt=(ROOT/f'assets/field/{soil}.svg').read_text(encoding='utf-8')
    check('filter=' not in txt and '<image' not in txt, f'field texture must remain lightweight vector-only: {soil}')

# v7.0.4 i18n / Next Day feedback regression gates.
check('property int i18nRevision: 0' in main,'runtime i18n revision property missing')
check('function onLanguageChanged() { root.i18nRevision++; root.message = "" }' in main and 'function onChanged() { root.i18nRevision++; root.message = "" }' in main,'runtime language-change refresh hooks missing')
check('var _languageRevision = i18nRevision' in main,'translation bindings must depend on i18n revision')
check('function dryOutdoorCropCount()' in main and 'function triggerNextDayWarning()' in main and 'function commitNextDay()' in main,'two-stage Next Day flow missing')
check('id: warningShake' in main and 'warningShakeOffset' in main,'Next Day screen-shake feedback missing')
check('id: warningEdge' in main and 'warningEdgeOpacity' in main,'Next Day danger-edge feedback missing')
check('VisualFeedbackLayer {' in main and 'onCommitRequested:' in main, 'central day transition director must own blackout commit')
check('id: shade' in (ROOT/'DayTransition.qml').read_text(encoding='utf-8') and 'color: "#000000"' in (ROOT/'DayTransition.qml').read_text(encoding='utf-8'), 'day darkening overlay missing from DayTransition.qml')
check('next_day_confirm' in en and 'next_day_warning_short' in en and 'day_transition' in en,'Next Day i18n keys missing')
icon_button=(ROOT/'IconButton.qml').read_text(encoding='utf-8')
check('maximumLineCount: 2' in icon_button and 'elide: Text.ElideRight' in icon_button,'localized IconButton text must wrap/elide safely')
ui_text=(ROOT/'UiText.qml').read_text(encoding='utf-8')
check('textFormat: Text.PlainText' in ui_text,'localized UI text must render as plain text')
check('AdaptiveNavigation {' in main and 'id: bottomNavigation' in main and 'id: topNavigation' in main, 'adaptive sticky navigation must provide compact bottom plus medium/wide top modes')
check('id: sideNavigation' not in main,'fullscreen desktop must not force an oversized left navigation rail')
check('Flow{id:buildingRow' in main and 'Flow{id:recipeRow' in main, 'Workshop rows must wrap instead of overflowing narrow viewports')
check('Flow{id:projectRow' in main, 'Journal project action row must wrap instead of overflowing narrow viewports')
check('root.width - root.iconSize - 8 - 16' in icon_button, 'IconButton text column must adapt when an explicit narrow width is assigned')

for required in ['AdaptiveNavigation.qml','ContextActionBar.qml','RewardFeedbackLayer.qml','StickyHud.qml','build.bat','build_mod.bat','build_mod.sh','README.md','SAVE_AUDIT.md','BUG_HUNTER_AUDIT.md','GAMER_AUDIT.md','VALIDATION_REPORT.md','tools/build_harvest_pocket.ps1','tools/package_source.py','tools/test_migration.py','tools/meta_audit.py']:
    check((ROOT/required).is_file(),f'required release file missing: {required}')

# v7.0.5 release/package hotfix gates.
check(not (ROOT/'ThemedSvgIcon.qml').exists(),'unused Canvas-based ThemedSvgIcon.qml must not ship')
check(not (ROOT/'assets/icon.png').exists(),'raster market icon fallback must not ship in vector-only package')
for rel in ['assets/ui/chicken.svg','assets/ui/cow.svg','assets/ui/rain.svg','assets/ui/sprout.svg']:
    check(rel in qrc_files,f'v7.0.5 QRC fix missing: {rel}')

# Windows PowerShell 5.1 native-process regression gates. Qt tools may write
# non-fatal warnings to stderr; piping native stderr through `2>&1` while
# ErrorActionPreference=Stop can turn those warnings into NativeCommandError.
build_ps1=(ROOT/'tools'/'build_harvest_pocket.ps1').read_text(encoding='utf-8')
check('function Invoke-NativeCaptured' in build_ps1, 'Windows-safe native process capture helper missing')
check('-RedirectStandardOutput $stdoutPath' in build_ps1 and '-RedirectStandardError $stderrPath' in build_ps1, 'Qt native stdout/stderr must be captured outside the PowerShell error stream')
check("Invoke-NativeCaptured -FilePath $QmlLintPath" in build_ps1, 'qmllint must use Windows-safe native process capture')
check("Invoke-NativeCaptured -FilePath $RccPath" in build_ps1, 'rcc must use Windows-safe native process capture')
check("$QmlLintPath '--max-warnings' '-1' $qmlFile.FullName 2>&1" not in build_ps1, 'qmllint must not redirect native stderr through PowerShell 2>&1')

# v7.1.0 Responsive Farm feature gates.
check('readonly property string layoutClass: width < 680 ? "compact" : (width < 1280 ? "medium" : "wide")' in main, 'Compact/Medium/Wide layout classification missing')
check('readonly property int contentMaxWidth: wideLayout ? 1180 : (mediumLayout ? 920 : 640)' in main,'responsive content max-width policy missing')
check('visible: !root.compactLayout' in main and 'dense: root.wideLayout' in main and 'root.wideLayout ? 760 : 900' in main,'medium/wide centered navigation scaling missing')
check('StickyHud {' in main and 'id: stickyHud' in main, 'sticky HUD missing')
check('ContextActionBar {' in main and 'id: farmActionBar' in main, 'sticky farm context action bar missing')
check('anchors.topMargin: stickyHud.height' in main and 'anchors.bottomMargin: (farmActionBar.visible ? farmActionBar.height' in main, 'scroll viewport must reserve sticky chrome space')
check('RewardFeedbackLayer {' in main and 'id: rewardLayer' in main, 'pooled reward feedback layer missing')
reward_layer=(ROOT/'RewardFeedbackLayer.qml').read_text(encoding='utf-8')
check('model: 3' in reward_layer and 'pool.itemAt(cursor)' in reward_layer, 'reward feedback must use a fixed reusable pool')
check('function waterSourceForPlot(index, plot)' in main and 'function effectiveWatered(index, plot)' in main, 'derived effective water state missing')
check('if (p.crop !== "" && !effectiveWatered(idx, p)) result.push(idx)' in main, 'manual watering must skip already-effective rain/sprinkler plots')
check('soilSource: root.soilSource(p, index)' in main and 'waterSource: root.waterSourceForPlot(index, p)' in main, 'plot visual state must receive effective water source')
check('property string waterSource: ""' in farmplot and 'assets/weather/rain.svg' in farmplot and 'assets/tools/sprinkler.svg' in farmplot, 'FarmPlot water-source indicators missing')
check('border.width: root.ready ? 3' in farmplot and 'assets/tools/basket.svg' in farmplot, 'harvest-ready border/indicator missing')
check('root.compactLayout?buildingRow.width:implicitWidth' in main and 'root.compactLayout?recipeRow.width:implicitWidth' in main, 'Workshop compact cards must place actions on their own responsive row')

# v7.3.0 Living Seasons polish/audio feature gates.
for required in ['VisualFeedbackLayer.qml','DayTransition.qml','SeasonTransition.qml','WeatherTransition.qml','AmbientWeatherLayer.qml']:
    check((ROOT/required).is_file(), f'v7.2 transition component missing: {required}')
for rel in ['assets/effects/petal.svg','assets/effects/pollen.svg','assets/effects/autumn_leaf.svg','assets/effects/snowflake.svg','assets/effects/rain_streak.svg','assets/effects/wind_streak.svg','assets/effects/heat_line.svg','assets/effects/frost_crystal.svg','assets/effects/cloud.svg','assets/effects/sun_ray.svg','assets/effects/lightning.svg']:
    check((ROOT/rel).is_file() and rel in qrc_files, f'v7.2 effect asset missing from package: {rel}')
feedback=(ROOT/'VisualFeedbackLayer.qml').read_text(encoding='utf-8')
day_transition=(ROOT/'DayTransition.qml').read_text(encoding='utf-8')
season_transition=(ROOT/'SeasonTransition.qml').read_text(encoding='utf-8')
weather_transition=(ROOT/'WeatherTransition.qml').read_text(encoding='utf-8')
ambient_weather=(ROOT/'AmbientWeatherLayer.qml').read_text(encoding='utf-8')
check('function beginDay(fromSeason, fromWeather)' in feedback and 'signal commitRequested()' in feedback and 'function commitApplied(newSeason, newWeather' in feedback, 'central transition director pipeline missing')
check('onBlackoutReached: root.commitRequested()' in feedback, 'day state commit must be requested only at blackout')
check('onFinished: weatherTransition.play' in feedback and 'onFinished: dayTransition.reveal()' in feedback, 'season -> weather -> reveal transition ordering missing')
check('to: 1' in day_transition and 'id: card' in day_transition,'day transition must reach a true blackout and use a compact themed presentation card')
check('model: root.reducedMotion ? 3 : 6' in season_transition and 'model: root.reducedMotion ? 2 : 5' in weather_transition and 'function poolSize()' in ambient_weather and 'return 10' in ambient_weather, 'Living Seasons polish must use smaller bounded effect pools')
combined_effects=feedback + season_transition + weather_transition + ambient_weather
check('ParticleSystem' not in combined_effects and 'ShaderEffect' not in combined_effects and 'MultiEffect' not in combined_effects, 'Living Seasons must remain particle/shader/effect free')
check('running: root.ambientEnabled && root.visible && !root.reducedMotion' in ambient_weather, 'ambient animation must stop off-tab/background/reduced-motion')
check('ambientEnabled' not in feedback,'transition director must not paint persistent ambient effects over global HUD/navigation')
check('root.reducedMotion ?' in day_transition and 'root.reducedMotion ?' in season_transition and 'root.reducedMotion ?' in weather_transition, 'Reduced Motion transition path missing')
check('visualFeedback.beginDay(root.seasonIndex, root.weather)' in main and 'onCommitRequested:' in main and 'visualFeedback.commitApplied' in main, 'Main.qml is not wired to the centralized transition director')
check('id: dayShade' not in main and re.search(r'\bid\s*:\s*dayTransition\b', main) is None, 'legacy inline day transition must be removed after v7.2 director migration')
check('swayAmount: root.weather==="wind" ? 2.4 : (root.weather==="storm" ? 3.0 : 0.75)' in main, 'wind/storm crop sway feedback missing')

# v7.3.0 Smart Fields gates.
check((ROOT/'IrrigationZoneChip.qml').is_file() and 'IrrigationZoneChip.qml' in qrc_files, 'Smart Fields irrigation-zone component missing from QRC')
check('function fieldStateFor(index, plot)' in main and 'function fieldStateKey(state)' in main, 'derived field-state model missing')
check('return "empty"' in main and 'return "ready"' in main and 'return "planted"' in main and 'return "dry"' in main and 'return "fertilized"' in main and 'return "watered"' in main, 'Smart Fields state vocabulary incomplete')
check('function irrigationZoneCoverage(zone)' in main and 'model: 5' in main and 'IrrigationZoneChip {' in main, 'five-zone irrigation visualization missing')
check('visible: root.unlocked && root.sprinklerCovered' in farmplot, 'partial irrigation zones must not visually mark uncovered plots')
check('reducedMotion: root.reducedMotion' in main and 'property bool reducedMotion: false' in (ROOT/'IrrigationZoneChip.qml').read_text(encoding='utf-8'), 'irrigation zone hover must respect Reduced Motion')
check('function batchWaterAllDry()' in main and 'function batchHarvestAllReady()' in main and 'function batchFertilizeSelectedZone()' in main, 'progression-gated batch actions missing')
check('readonly property bool batchWaterUnlocked: wateringTier >= 3' in main and 'readonly property bool batchFertilizeUnlocked: farmLevel >= 8' in main and 'readonly property bool batchHarvestUnlocked: farmLevel >= 10' in main, 'batch actions must remain progression-gated')
check('harvestCore(candidates[h], true)' in main and 'if (!batchMode)' in main and 'cropIds.length === 1' in main, 'batch harvest must use the transactional core, suppress per-plot popups and aggregate reward feedback')
check('var possible = Math.min(candidates.length, Math.max(0, Math.floor(energy)) * perEnergy)' in main and 'var energyCost = Math.ceil(possible / perEnergy)' in main, 'batch watering must preserve watering-tool energy economics')
check('var zone = selectedIrrigationZone' in main and 'var end = Math.min(activePlotCount, start + 8)' in main, 'batch fertilization must be constrained to the selected 8-plot zone')
check('fieldState: root.fieldStateFor(index, p)' in main and 'zoneCoverage: root.irrigationZoneCoverage' in main, 'FarmPlot must receive derived Smart Fields state')
for key in ['smart_fields','field_state_empty','field_state_planted','field_state_dry','field_state_watered','field_state_fertilized','field_state_ready','water_all_dry','harvest_all_ready','fertilize_zone','water_source','water_source_none','water_source_manual','water_source_sprinkler','water_source_rain','water_source_storm']:
    check(key in en, f'v7.3 i18n key missing: {key}')

# package hygiene
for p in ROOT.rglob('*'):
    if p.is_file(): check(p.suffix.lower() not in {'.bak','.orig','.tmp','.pyc'},f'temporary file in source: {p.relative_to(ROOT)}')
check(not any(p.name=='__pycache__' for p in ROOT.rglob('*') if p.is_dir()),'__pycache__ present')
# dist/ is an output directory and must never be interpreted as RCC input on repeat builds.
check("rel.startswith('dist/')" in Path(__file__).read_text(encoding='utf-8') and "rel.startswith('release/')" in Path(__file__).read_text(encoding='utf-8'), 'validator must explicitly exclude dist/release build outputs')

# v7.0.3 planting/season UX regression gates.
main_text=(ROOT/'Main.qml').read_text(encoding='utf-8')
check('function cycleSeedSelection(step)' in main_text and 'function selectCropShortcut(slot)' in main_text, 'season-aware keyboard/gamepad crop selection helpers missing')
check('root.cycleSeedSelection(1)' in main_text, 'GameInput next action must respect visible season filter')
check('selectCropShortcut(event.key - Qt.Key_1)' in main_text, 'numeric crop shortcuts must respect visible season filter')
check('Number(p.age || 0) >= Number(def.days || 1)' in main_text, 'Next Day dry warning must ignore harvest-ready crops')
check('SeasonCropButton' in main_text, 'planting chooser must use season-aware crop cards')
check('showAllCrops' in main_text and 'cropChooserIndexes' in main_text, 'planting chooser season filter missing')
check('cropSeasonText' in main_text and 'cropPlantStatusKey' in main_text, 'crop season/status helpers missing')
check('stocked || seasonReachable' in main_text, 'orders may request unreachable out-of-season crops')
for season in ('spring','summer','autumn','winter'):
    check((ROOT/'assets'/'seasons'/f'{season}.svg').is_file(), f'missing season SVG: {season}')
check((ROOT/'SeasonCropButton.qml').is_file(), 'missing SeasonCropButton.qml')

check('ensureSeasonSelection' in main_text, 'season changes must keep planting selection usable')
check('{id:"berry", key:"crop_berry", seedCost:8, sell:18, days:3, seasons:[0,1], level:1' in (ROOT/'js'/'FarmData.js').read_text(encoding='utf-8'), 'Summer must retain a level-1 crop')


# v7.4.x Town Market gates.
check((ROOT/'MarketTrendChip.qml').is_file() and 'MarketTrendChip.qml' in qrc_files, 'Town Market trend component missing from QRC')
for rel in ['assets/ui/trend_flat.svg','assets/ui/refresh.svg','assets/ui/clock.svg']:
    check((ROOT/rel).is_file() and rel in qrc_files, f'Town Market SVG missing from QRC: {rel}')
check('readonly property int orderRefreshBudget: 3' in main and 'function refreshOrderBoard()' in main, 'three-per-day board refresh contract missing')
check('if (o && o.status === "accepted") continue' in main, 'board refresh must preserve accepted orders')
check('function recordOrderHistory(outcome, o)' in main and 'history.length > 40' in main, 'bounded persistent order history missing')
check('status:"completed"' in main or 'status = "completed"' in main, 'explicit completed order state missing')
for state in ['rejected','abandoned','expired']:
    check(f'"{state}"' in main, f'explicit order state missing: {state}')
check('special:special' in main and 'expiresDay:special ? day + 2 : 0' in main and 'orderExpiryText' in main, 'timed special order expiry contract missing')
check('marketPercentDelta' in main and 'marketForecast()' in main and 'marketForecastText()' in main, 'market trend/forecast model missing')
check('arrow_up.svg' in main and 'arrow_down.svg' in main and 'trend_flat.svg' in main, 'SVG market trend indicators missing')
check('orderHistory: orderHistory' in main and 'highestOrderReward: highestOrderReward' in main, 'Town Market history must persist in canonical save')
check('compatibilitySnapshotV3' in main and 'compatOrders[i] = {status:"cooldown", cooldownUntil:day + 1}' in main, 'v4 terminal order states need downgrade-safe v3 mapping')
for key in ['refresh_board','market_forecast','special_order','expires_today','order_status_completed','order_status_expired','order_history','highest_reward']:
    check(key in en, f'v7.4 i18n key missing: {key}')

check('ordersRejected:0' in main and 'ordersAbandoned:0' in main and 'ordersExpired:0' in main, 'Town Market lifetime outcome counters missing')
check('syncOrderRejectBudget()' not in main, 'stale v7.1 syncOrderRejectBudget call would lock Next Day transition')
check('syncOrderRefreshBudget()' in main, 'Next Day must reset the current board refresh budget')
check('function orderVisibleSignature(o)' in main and 'generateOrder(i, orderVisibleSignature(o))' in main, 'board refresh must avoid visually identical replacement orders')
check('refreshableOrderCount' in main and 'root.refreshableOrderCount>0' in main, 'board refresh control must disable when every unlocked card is accepted')
check('dayTransitionWatchdog.restart()' in main and 'visualFeedback.forceFinish()' in main, 'Next Day transition watchdog/fail-safe missing')
check('function forceFinish()' in (ROOT/'VisualFeedbackLayer.qml').read_text(encoding='utf-8'), 'VisualFeedbackLayer force-finish recovery API missing')
check('addStat("ordersRejected", 1)' in main and 'addStat("ordersAbandoned", 1)' in main, 'reject/abandon lifetime counters missing')

# v7.4.2 recovery / harvest transaction gates.
check('function isHarvestReady(i)' in main and 'function harvestCore(i, batchMode)' in main, 'explicit harvest-ready/core contract missing')
check('var before = clone(snapshot())' in main and 'msg_harvest_failed' in main, 'harvest transaction rollback guard missing')
check('function repairKnownState()' in main and 'msg_partial_day_recovered' in main and 'repairRevision' in main, 'v7.4.0 interrupted-day save repair missing')
check('function commitNextDay()' in main and 'return true' in main and 'msg_day_commit_failed' in main, 'Next Day commit must be transactional and report success/failure')
check('if (root.commitNextDay())' in main and 'visualFeedback.forceFinish()' in main, 'transition director must stop cleanly when day commit rolls back')
context_bar=(ROOT/'ContextActionBar.qml').read_text(encoding='utf-8')
check('signal harvest()' in context_bar and 'harvestVisible' in context_bar and 'assets/tools/basket.svg' in context_bar, 'explicit selected-field Harvest action missing')
check('onHarvest: root.harvest(root.selectedPlot)' in main and 'harvestVisible: root.selectedPlotReady' in main, 'Harvest action is not wired to selected ready plot')
check((ROOT/'tools'/'test_runtime_logic.js').is_file(), 'actual-QML runtime logic regression harness missing')
check('function restoreRuntimeSnapshot(s)' in main and main.count('restoreRuntimeSnapshot(before)') >= 6, 'transaction rollback must restore the exact runtime snapshot without regeneration')
check('applySnapshot(before)' not in main, 'transaction rollback must not pass through save normalization/order regeneration')
check('if (cropId !== "" && !isCropId(cropId)) cropId = ""' in main, 'unknown persisted crop ids must be cleared instead of aliasing to FarmData.crops[0]')
check('finiteNumber(sq[c].normal, 0)' in main and 'finiteNumber(sls[s], 0)' in main, 'malformed nested numeric save fields must be finite-normalized')
check('if (isHarvestReady(i))' in main and 'msg_harvest_before_fertilize' in main, 'ready crops must reject fertilizer instead of wasting consumables')
check('function sellItem(id)' in main and 'sell transaction rolled back' in main, 'selling must be rollback-safe')
check('function deliverOrder(slot)' in main and 'order delivery transaction rolled back' in main, 'order delivery must be rollback-safe')
check('function advanceProject(project)' in main and 'project transaction rolled back' in main, 'community project purchase must be rollback-safe')
check('readonly property bool inputLocked:' in main and 'if (root.inputLocked || root.activeTab !== 0) return' in main, 'gameplay input must be locked during transitions and off the Farm tab')
for key in ['harvest_selected','ready_to_harvest','msg_harvest_not_ready','msg_harvest_failed','msg_day_commit_failed','msg_partial_day_recovered','msg_harvest_before_fertilize','msg_transaction_failed']:
    check(key in en, f'v7.4.2 recovery i18n key missing: {key}')


if errors:
    print(f'VALIDATION FAIL: {len(errors)} errors after {checks} checks')
    for e in errors: print(' -',e)
    sys.exit(1)
print(f'VALIDATION PASS: {checks}/{checks} checks')
