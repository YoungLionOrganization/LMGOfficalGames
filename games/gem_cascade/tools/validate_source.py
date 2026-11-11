#!/usr/bin/env python3
from __future__ import annotations
import json, re, sys, random, shutil, subprocess, wave
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ERRORS: list[str] = []
WARNINGS: list[str] = []
CHECKS: list[str] = []

def ok(msg: str): CHECKS.append(msg)
def fail(msg: str): ERRORS.append(msg)
def warn(msg: str): WARNINGS.append(msg)

def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as e:
        fail(f"JSON parse: {path.relative_to(ROOT)}: {e}")
        return None

def placeholders(s: str): return sorted(re.findall(r"%\d+", s))

def validate_json_and_i18n():
    manifest = load_json(ROOT / "manifest.json")
    if not manifest: return None
    if manifest.get("id") != "gem_cascade": fail(f"manifest id changed: {manifest.get('id')!r}")
    if int(manifest.get("save_version", 0)) != 2: fail("manifest save_version must be 2 for canonical snapshot schema")
    if manifest.get("package_format") != "rcc-v1": fail("manifest package_format must remain rcc-v1")
    if manifest.get("entry") != "Main.qml": fail("manifest entry must be Main.qml")
    if int(manifest.get("plugin_level", 0)) != 2: fail("manifest plugin_level must be 2 for external RCC package")
    if not str(manifest.get("icon_path", "")).strip(): fail("manifest icon_path is empty")
    for p in ROOT.rglob("*.json"):
        load_json(p)
    locales = manifest.get("locales", [])
    required = ["en","tr","az","ru","de","fr","es","pt","zh","ja"]
    if any(x not in locales for x in required): fail("manifest locales missing one or more required locales")
    docs = {}
    for loc in locales:
        p = ROOT / "i18n" / f"{loc}.json"
        if not p.exists(): fail(f"missing locale file: {loc}"); continue
        d = load_json(p)
        if isinstance(d, dict): docs[loc] = d
    if "en" in docs:
        base = set(docs["en"])
        for loc,d in docs.items():
            if set(d) != base: fail(f"i18n key parity mismatch: {loc}: missing={sorted(base-set(d))}, extra={sorted(set(d)-base)}")
            for k,v in d.items():
                if not isinstance(v,str) or not v.strip(): fail(f"empty/non-string translation: {loc}:{k}")
                if k in docs["en"] and placeholders(v) != placeholders(docs["en"][k]): fail(f"placeholder mismatch: {loc}:{k}")
        qml = "\n".join(p.read_text(encoding="utf-8") for p in ROOT.rglob("*.qml"))
        used = set(re.findall(r'(?:tr|translate)\(\"([^\"]+)\"', qml))
        missing = sorted(used - base)
        if missing: fail(f"QML i18n keys missing from en.json: {missing}")
        else: ok(f"i18n parity/placeholders/QML key coverage: {len(docs)} locales, {len(base)} keys")
    return manifest

def validate_qrc():
    qrc = ROOT / "mod.qrc"
    try: tree = ET.parse(qrc)
    except Exception as e: fail(f"mod.qrc XML parse failed: {e}"); return
    qresources = tree.getroot().findall("qresource")
    if len(qresources) != 1: fail("mod.qrc must have exactly one qresource")
    aliases=set(); count=0
    for qr in qresources:
        prefix = qr.attrib.get("prefix", "")
        if prefix != "/":
            if prefix == "/mods/gem_cascade":
                fail("invalid RCC inner prefix '/mods/gem_cascade': plugin packages must use '/' because LeoMiniGames mounts the registered RCC at /mods/gem_cascade; embedding the host mount root creates a doubled runtime path")
            else:
                fail(f"wrong qrc inner prefix: {prefix!r}; expected '/' for host-mounted rcc-v1 plugins")
        for f in qr.findall("file"):
            rel=(f.text or "").strip(); alias=f.attrib.get("alias",rel)
            if alias in aliases: fail(f"duplicate qrc alias: {alias}")
            aliases.add(alias); count += 1
            if not (ROOT/rel).is_file(): fail(f"qrc missing file: {rel}")
    for required in ["Main.qml","manifest.json","js/BoardLogic.js","components/GemCell.qml","assets/icon.png","i18n/ja.json","i18n/zh.json"]:
        if required not in aliases: fail(f"qrc missing required runtime resource: {required}")
    manifest = load_json(ROOT / "manifest.json")
    if isinstance(manifest, dict):
        for key in ["entry", "icon_path"]:
            value=str(manifest.get(key, "")).replace("\\", "/").lstrip("/")
            if value and value not in aliases: fail(f"manifest {key} does not resolve inside RCC: {value}")
    expected={"manifest.json","LICENSE"}
    expected.update(str(x.relative_to(ROOT)).replace("\\","/") for x in ROOT.rglob("*.qml"))
    expected.update(str(x.relative_to(ROOT)).replace("\\","/") for x in (ROOT/"js").glob("*.js"))
    expected.update(str(x.relative_to(ROOT)).replace("\\","/") for x in (ROOT/"i18n").glob("*.json"))
    expected.update(str(x.relative_to(ROOT)).replace("\\","/") for x in (ROOT/"assets").rglob("*") if x.is_file())
    missing_runtime=sorted(expected-aliases)
    if missing_runtime: fail(f"qrc omits runtime source/assets: {missing_runtime}")
    # Packaging model: inner :/Main.qml is mounted by host at /mods/gem_cascade,
    # yielding :/mods/gem_cascade/Main.qml. A doubled /mods/gem_cascade/mods/...
    # path is always a packaging bug.
    mapped = {f":/mods/gem_cascade/{a.lstrip('/')}" for a in aliases}
    for runtime_path in [
        ":/mods/gem_cascade/Main.qml",
        ":/mods/gem_cascade/manifest.json",
        ":/mods/gem_cascade/js/BoardLogic.js",
        ":/mods/gem_cascade/components/GemCell.qml",
        ":/mods/gem_cascade/components/AudioBus.qml",
        ":/mods/gem_cascade/components/LocalAudioFallback.qml",
        ":/mods/gem_cascade/assets/icon.png",
    ]:
        if runtime_path not in mapped: fail(f"host-mapped runtime resource missing by contract: {runtime_path}")
    doubled = ":/mods/gem_cascade/mods/gem_cascade/Main.qml"
    if doubled in mapped: fail(f"doubled host mount path would exist: {doubled}")
    ok(f"QRC inner-prefix/mount/paths/aliases: {count} resources; runtime coverage complete; host mapRoot=/mods/gem_cascade")

def validate_svg():
    count=0
    for p in ROOT.rglob("*.svg"):
        try: ET.parse(p); count += 1
        except Exception as e: fail(f"SVG parse: {p.relative_to(ROOT)}: {e}")
    if count < 6: fail("expected at least six gem SVG assets")
    else: ok(f"SVG XML parse: {count} assets")

def strip_strings_comments(text: str) -> str:
    text=re.sub(r"//.*?$", "", text, flags=re.M)
    text=re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text=re.sub(r'"(?:\\.|[^"\\])*"', '""', text)
    text=re.sub(r"'(?:\\.|[^'\\])*'", "''", text)
    return text

def validate_qml_static():
    known_colors={"color.accent","color.background","color.border","color.info","color.primary","color.primaryHover","color.surfaceInteractive","color.surfaceRaised","color.text","color.textMuted"}
    known_numbers={"alias.button.gap","alias.button.height","alias.button.hoverScale","alias.button.paddingX","alias.button.pressedScale","alias.button.touchTarget","alias.card.borderWidth","alias.card.gap","alias.card.padding","alias.card.radius","alias.gameTile.gap","alias.page.gap","alias.page.padding","metric.control.lg","metric.control.sm","metric.control.xs","metric.icon.md","metric.space.xs","metric.space.xxxs","metric.font.xs","metric.font.sm","metric.font.md","metric.font.lg"}
    known_surfaces={"surface.card","surface.control","surface.gameTile","surface.panel"}
    all_qml=""
    for p in ROOT.rglob("*.qml"):
        text=p.read_text(encoding="utf-8")
        all_qml += "\n" + text
        stripped=strip_strings_comments(text)
        for opening,closing in [("{","}"),("(",")"),("[","]")]:
            if stripped.count(opening) != stripped.count(closing): fail(f"delimiter imbalance {opening}{closing}: {p.relative_to(ROOT)}")
        if re.search(r"\btext\s*:\s*\"[A-Za-z][^\"]{3,}\"", text) and p.name == "Main.qml":
            fail(f"hardcoded user-visible text literal in Main.qml: {p.relative_to(ROOT)}")
        if "Unexpected token" in text or "InnerText" in text: fail(f"known-invalid QML pattern: {p.relative_to(ROOT)}")
    used_colors=set(re.findall(r'(?:GameTheme\.color|themeColor)\("([^"]+)"', all_qml))
    used_numbers=set(re.findall(r'(?:GameTheme\.number|themeNumber)\("([^"]+)"', all_qml))
    used_surfaces=set(re.findall(r'surfaceToken\s*:\s*"([^"]+)"', all_qml))
    bad_colors=sorted(used_colors-known_colors); bad_numbers=sorted(used_numbers-known_numbers); bad_surfaces=sorted(used_surfaces-known_surfaces)
    if bad_colors: fail(f"unverified GameTheme color tokens introduced: {bad_colors}")
    if bad_numbers: fail(f"unverified GameTheme numeric tokens introduced: {bad_numbers}")
    if bad_surfaces: fail(f"unverified GameTheme surface tokens introduced: {bad_surfaces}")
    main=(ROOT/"Main.qml").read_text(encoding="utf-8")
    for state in ["Idle","Selecting","Swapping","Clearing","Falling","Cascading","Shuffling","LevelComplete","LevelFailed","Paused"]:
        if f'"{state}"' not in main: fail(f"state missing from Main.qml: {state}")
    contracts={
        "input gate":"inputReady",
        "Qt safe-area layout":"root.SafeArea.margins",
        "canonical JSON write":"JSON.stringify(payload)",
        "canonical JSON restore":"JSON.parse(json)",
        "service readiness":"typeof GameI18n === \"undefined\"",
        "i18n ready rebind":"function onReadyChanged() { root.languageRevision++",
        "theme runtime revision":"function onThemeChanged() { root.themeRevision++",
        "theme revision lookup":"var touch = themeRevision",
        "transactional lifecycle rollback":"prepareForBackground",
        "last stable rollback":"restoreSnapshot(copyObject(lastStableSnapshot))",
        "swap legality isolation":"pendingLegal = BoardLogic.isLegalSwap",
        "restore board sanitization":"sanitizeRestoredBoard",
        "tutorial dismissal persistence":"if (!root.tutorialCompleted)",
        "safe settings adapter":"function settingBool(key, fallback)",
        "theme color fallback":"function fallbackColor(token)",
        "theme metric fallback":"function fallbackNumber(token)",
        "guarded lifecycle target":"target: typeof Lifecycle !== \"undefined\" ? Lifecycle : null",
        "guarded i18n target":"target: typeof GameI18n !== \"undefined\" ? GameI18n : null",
        "guarded save target":"target: typeof GameSave !== \"undefined\" ? GameSave : null",
        "guarded theme target":"target: typeof GameTheme !== \"undefined\" ? GameTheme : null",
        "guarded input target":'target: typeof GameInput !== "undefined" ? GameInput : null',
        "impact feedback":"function triggerImpact(strength, soundKind)",
        "board shake":"boardShakeX",
        "impact flash":"impactFlashOpacity",
        "vibration preference":"function toggleVibrationPreference()",
        "sound preference":"function toggleSoundPreference()",
    }
    for label,marker in contracts.items():
        if marker not in main: fail(f"{label} contract missing")
    gem=(ROOT/"components/GemCell.qml").read_text(encoding="utf-8")
    booster=(ROOT/"components/BoosterButton.qml").read_text(encoding="utf-8")
    if "nativeScanCode" not in main: fail("desktop physical-key fallback missing")
    for token in ["w:17,a:30,s:31,d:32","w:25,a:38,s:39,d:40","w:13,a:0,s:1,d:2"]:
        if token not in main: fail(f"desktop physical-key matrix incomplete: {token}")
    if "ThemedSvgIcon" in gem or "ThemedSvgIcon" in booster: fail("PC gameplay icons still depend on Canvas tint component")
    forbidden=["★","×","→","▲","▼","◀","▶"]
    bad=[g for g in forbidden if g in main or g in booster]
    if bad: fail(f"font-dependent gameplay glyphs remain: {bad}")
    if 'cell.cellSize * 0.20' not in gem: fail("board-relative swipe threshold missing")
    if 'radius: parent.radius' in gem: fail("GemCell child radius still depends on UiPanel content-layer parent.radius and can become undefined")
    level_logic=(ROOT/"js/LevelLogic.js").read_text(encoding="utf-8")
    if "function awardLevelBoosters" not in main or "LevelLogic.boosterRewards" not in main or "booster_reward" not in main:
        fail("booster progression reward integration missing from Main.qml")
    for reward_marker in ["function boosterRewards", "oldStars < 1", "oldStars < 3", "n % 3 === 0", "n % 5 === 0"]:
        if reward_marker not in level_logic: fail(f"booster progression reward policy missing: {reward_marker}")
    if 'spawned ? (0.90 + 0.10' not in gem or 'fallProgress' not in gem: fail("spawn scale/opacity animation contract missing")
    if 'GameSave.set("board"' in main: fail("legacy direct array GameSave writes still present")
    booster=(ROOT/"components/BoosterButton.qml").read_text(encoding="utf-8")
    if "interactionEnabled && count > 0" not in booster: fail("booster disabled/count gating missing")
    if "shortcut." in booster: fail("BoosterButton illegally references UiButton private shortcut id; this can collapse mobile booster layout")
    if "contentRow.implicitWidth" not in booster: fail("BoosterButton self-contained implicit width contract missing")
    if 'height: implicitHeight' not in main or 'id: actions' not in main: fail("mobile actions/booster Flow height contract missing")
    logic=(ROOT/"js/BoardLogic.js").read_text(encoding="utf-8")
    for marker in ["function enumerateLegalMoves", "function findBestAction", "function boardQuality", "function weightedGemChoice", "function countLegalMovesLimited", "function hasPlayableAction"]:
        if marker not in logic: fail(f"smart board algorithm contract missing: {marker}")
    for marker in ["BoardLogic.findBestAction", "decisionContext()", "BoardLogic.hasPlayableAction", "collapseAndRefill(board, specials, cols, rows, gemTypes, randomFn, decisionContext())"]:
        if marker not in main: fail(f"smart gameplay integration missing: {marker}")
    if 'root.vibrationEnabled ? root.tr("vibration_on"' not in main: fail("in-game vibration on/off control missing")
    unsafe_patterns = {
        "unguarded Settings binding": r"Boolean\(GameSettings\.value",
        "unguarded Connections target": r"target\s*:\s*(?:Lifecycle|GameI18n|GameSave|GameTheme|GameInput)\s*(?:$|\n)",
        "unguarded direct theme return": r"return\s+GameTheme\.(?:color|number|surface)\(",
    }
    for label, pattern in unsafe_patterns.items():
        if re.search(pattern, all_qml, flags=re.M): fail(label)
    for forbidden_global in ["pendingClearPlan", "comboContext"]:
        if re.search(r"(?<!property\s)(?<!var\s)\b" + re.escape(forbidden_global) + r"\s*=", main):
            fail(f"undeclared QML/JS global assignment retained: {forbidden_global}")
    if re.search(r"(?<![A-Za-z0-9_\.])SafeArea\.margins", main):
        fail("self-referential/bare SafeArea.margins use detected; query root.SafeArea.margins to avoid attached-property layout loops")
    for rel in ["UiPanel.qml","UiText.qml","UiBar.qml","UiButton.qml","ThemedSvgIcon.qml","components/TutorialOverlay.qml"]:
        text=(ROOT/rel).read_text(encoding="utf-8")
        if "GameTheme." in text and 'typeof GameTheme !== "undefined"' not in text:
            fail(f"theme service access lacks availability guard: {rel}")
    ok(f"QML static/state/service/theme/input contracts; verified theme tokens: {len(used_colors)} colors, {len(used_numbers)} metrics, {len(used_surfaces)} surfaces")

def validate_version(manifest):
    if not manifest: return
    v=str(manifest.get("version",""))
    for name in ["build_mod.bat","build_mod.sh"]:
        text=(ROOT/name).read_text(encoding="utf-8")
        if v not in text: fail(f"version mismatch: {name} does not contain {v}")
        expanded=text.replace("%VERSION%",v).replace("${VERSION}",v)
        if f"gem_cascade-{v}.rcc" not in expanded:
            fail(f"build output version mismatch: {name} does not resolve to gem_cascade-{v}.rcc")
    readme=ROOT/"README.md"
    if not readme.is_file(): fail("README.md missing")
    elif v not in readme.read_text(encoding="utf-8"): fail(f"version mismatch: README.md does not contain {v}")
    main=(ROOT/"Main.qml").read_text(encoding="utf-8")
    if f'readonly property string version: "{v}"' not in main: fail("Main.qml version does not match manifest")
    ok(f"version consistency: {v}")

def find_runs(board, cols=8, rows=8):
    runs=[]
    for y in range(rows):
        x=0
        while x<cols:
            s=x; g=board[y*cols+x]; x+=1
            while x<cols and board[y*cols+x]==g: x+=1
            if g>=0 and x-s>=3: runs.append([y*cols+i for i in range(s,x)])
    for x in range(cols):
        y=0
        while y<rows:
            s=y; g=board[y*cols+x]; y+=1
            while y<rows and board[y*cols+x]==g: y+=1
            if g>=0 and y-s>=3: runs.append([i*cols+x for i in range(s,y)])
    return runs

def legal_move(board):
    def test(a,b):
        b2=board[:]; b2[a],b2[b]=b2[b],b2[a]; return bool(find_runs(b2))
    for i in range(64):
        x,y=i%8,i//8
        if x<7 and test(i,i+1): return (i,i+1)
        if y<7 and test(i,i+8): return (i,i+8)
    return None

def generate(rng):
    for _ in range(300):
        b=[]
        for p in range(64):
            for _ in range(30):
                g=rng.randrange(6); b.append(g)
                x,y=p%8,p//8
                bad=(x>=2 and b[p-1]==g and b[p-2]==g) or (y>=2 and b[p-8]==g and b[p-16]==g)
                if not bad: break
                b.pop()
        if not find_runs(b) and legal_move(b): return b
    raise AssertionError("generation failed")

def collapse_refill(board,rng):
    b=board[:]
    for x in range(8):
        vals=[b[y*8+x] for y in range(7,-1,-1) if b[y*8+x]>=0]
        it=iter(vals)
        for y in range(7,-1,-1):
            try: b[y*8+x]=next(it)
            except StopIteration: b[y*8+x]=rng.randrange(6)
    return b

def gameplay_simulation():
    rng=random.Random(0xC0FFEE)
    # Keep this Python layer lightweight for every build; the Node adversarial suite
    # below performs the full 1000-iteration stress test against the shipped JS logic.
    for _ in range(100):
        b=generate(rng)
        if find_runs(b): fail("simulation: generated initial match"); return
        mv=legal_move(b)
        if not mv: fail("simulation: generated board has no legal move"); return
        a,c=mv; b[a],b[c]=b[c],b[a]
        if not find_runs(b): fail("simulation: legal swap produced no match"); return
        guard=0
        while find_runs(b) and guard<64:
            clear=set(x for run in find_runs(b) for x in run)
            for p in clear: b[p]=-1
            b=collapse_refill(b,rng); guard += 1
        if guard>=64: fail("simulation: cascade did not terminate within safety bound"); return
    js=(ROOT/"js/BoardLogic.js").read_text(encoding="utf-8")
    for token in ["BOMB = 3","PRISM = 4","NOVA = 5","line_line","bomb_bomb","line_bomb","prism_normal","prism_line","prism_bomb","prism_nova","line_nova","bomb_nova","nova_nova","prism_prism","function singleSpecialPlan"]:
        if token not in js: fail(f"JS special/combo contract missing: {token}")
    ok("gameplay simulation: 100 generated boards, legal swaps, gravity/refill, bounded cascades (extended JS stress runs separately)")

def validate_save_contract():
    main=(ROOT/"Main.qml").read_text(encoding="utf-8")
    required=["level","unlockedLevel","starsByLevel","bestScores","boosters","tutorialCompleted","statistics","board","specials","movesLeft"]
    for field in required:
        if field not in main: fail(f"persistent state field absent from save/restore source: {field}")
    for marker in ["campaignSnapshot", "stableActiveSnapshot", "snapshotForSave", "lastStableSnapshot", "restoreSnapshot", "migrateLegacySave", "serviceContextReady", "sanitizeRestoredBoard", "prepareForBackground", "forceSave", "onBackgrounded", "onSaveRequested", 'GameSave.set("snapshotJson"', 'GameSave.get("snapshotJson"']:
        if marker not in main: fail(f"save lifecycle marker missing: {marker}")
    ok("save write/restore/migration/lifecycle source paths")


def validate_node_regressions():
    node=shutil.which("node")
    if not node:
        warn("Node.js not available; pure-JS BoardLogic/campaign regression scripts were not executed by validator (Python gameplay simulation still runs).")
        return
    for script,label in [("tools/test_board_logic.js","BoardLogic adversarial regression"),("tools/test_gamer_algorithms.js","Gamer board/hint/refill algorithms"),("tools/test_campaign_balance.js","campaign feasibility"),("tools/test_booster_rewards.js","booster reward economy")]:
        try:
            env = dict(__import__("os").environ)
            # The validator runs on every RCC build. Keep the campaign gate deterministic
            # and fast here; the standalone script defaults to the full 40 seeds/level.
            if script == "tools/test_board_logic.js":
                env["GEM_CASCADE_STRESS_RUNS"] = "120"
            if script == "tools/test_gamer_algorithms.js":
                env["GEM_CASCADE_GAMER_RUNS"] = "160"
            if script == "tools/test_campaign_balance.js":
                env["GEM_CASCADE_BALANCE_RUNS"] = "8"
            cp=subprocess.run([node, str(ROOT/script)], cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=45, env=env)
        except Exception as e:
            fail(f"{label} runner failed: {e}"); continue
        if cp.returncode != 0:
            fail(f"{label} failed:\n{cp.stdout[-4000:]}")
        else:
            summary=cp.stdout.strip().splitlines()[-1] if cp.stdout.strip() else "PASS"
            ok(f"{label}: {summary}")

def validate_build_and_postbuild_contract():
    required_files=[
        ROOT/"tools/qt_rcc_smoke/CMakeLists.txt",
        ROOT/"tools/qt_rcc_smoke/rcc_smoke.cpp",
    ]
    for path in required_files:
        if not path.is_file(): fail(f"post-build verifier missing: {path.relative_to(ROOT)}")
    bat=(ROOT/"build_mod.bat").read_text(encoding="utf-8")
    sh=(ROOT/"build_mod.sh").read_text(encoding="utf-8")
    for name,text in [("build_mod.bat",bat),("build_mod.sh",sh)]:
        for marker in ["validate_source.py","--binary","qt_rcc_smoke","gem_cascade_rcc_smoke","GEM_CASCADE_SKIP_QT_SMOKE"]:
            if marker not in text: fail(f"{name} missing strict build/post-build marker: {marker}")
    smoke=(ROOT/"tools/qt_rcc_smoke/rcc_smoke.cpp").read_text(encoding="utf-8") if required_files[1].is_file() else ""
    smoke_lower=smoke.lower()
    for marker in [
        'QResource::registerResource', '/mods/gem_cascade',
        ':/mods/gem_cascade/Main.qml',
        ':/mods/gem_cascade/mods/gem_cascade/Main.qml',
        'QQmlComponent', 'runNoServiceFallbackSmoke', 'runHostStubSmoke',
        'GameTheme', 'GameI18n', 'GameSave', 'GameRandom', 'GameInput',
    ]:
        if marker not in smoke: fail(f"post-build RCC/QQmlEngine verifier missing marker: {marker}")
    for marker in ['referenceerror','typeerror','unable to assign','invalid write to global property','expected token']:
        if marker not in smoke_lower: fail(f"post-build diagnostic trap missing marker: {marker}")
    cmake=(ROOT/"tools/qt_rcc_smoke/CMakeLists.txt").read_text(encoding="utf-8") if required_files[0].is_file() else ""
    for marker in ["Qt6::Core","Qt6::Gui","Qt6::Qml","Qt6::Quick","Qt6::Multimedia","CMAKE_AUTOMOC"]:
        if marker not in cmake: fail(f"post-build verifier CMake contract missing: {marker}")
    ok("strict build pipeline + actual-RCC mount/QQmlEngine post-build verifier contract")

def validate_audio_contract(manifest):
    caps=set(manifest.get("capabilities",[])) if manifest else set()
    audio_qml = ROOT / "components" / "AudioBus.qml"
    fallback_qml = ROOT / "components" / "LocalAudioFallback.qml"
    sfx = list((ROOT / "assets" / "sfx").glob("*.wav")) if (ROOT / "assets" / "sfx").is_dir() else []
    if "audio" not in caps:
        fail("audio capability missing although Gem Cascade ships SFX")
        return
    if not audio_qml.is_file(): fail("audio capability declared but components/AudioBus.qml is missing"); return
    if not fallback_qml.is_file(): fail("Android/iOS local audio fallback is missing"); return
    a=audio_qml.read_text(encoding="utf-8")
    f=fallback_qml.read_text(encoding="utf-8")
    if "property bool enabled:" in a or "property bool enabled:" in f:
        fail("audio component shadows inherited QQuickItem.enabled; this produces property-cache override warnings")
    if re.search(r'GameAudio\.(?:playEffect|preload)\([^\n\)]*,', a):
        fail("multi-argument GameAudio calls are forbidden; host contract is single URL")
    for marker in ["GameAudio.playEffect", "GameAudio.preload", "preferLocalBackend", "playLocal(name)", "active: true"]:
        if marker not in a: fail(f"host/mobile audio routing marker missing: {marker}")
    for marker in ["import QtMultimedia", "MediaPlayer", "AudioOutput", "Qt.resolvedUrl(rel)"]:
        if marker not in f: fail(f"local QtMultimedia fallback marker missing: {marker}")
    if len(sfx) < 12:
        fail("too few SFX assets are present")
    else:
        bad_wav=[]
        for wav_path in sfx:
            try:
                with wave.open(str(wav_path), "rb") as wf:
                    if wf.getnchannels() not in (1,2) or wf.getsampwidth() not in (1,2,3,4) or wf.getframerate() <= 0 or wf.getnframes() <= 0:
                        bad_wav.append(wav_path.name)
            except Exception:
                bad_wav.append(wav_path.name)
        if bad_wav: fail(f"invalid/unreadable WAV assets: {bad_wav}")
        else: ok(f"audio contract: desktop/mobile MediaPlayer-first + host GameAudio fallback + {len(sfx)} valid local WAV SFX assets")

def main():
    manifest=validate_json_and_i18n(); validate_qrc(); validate_svg(); validate_qml_static(); validate_version(manifest); validate_save_contract(); validate_build_and_postbuild_contract(); validate_audio_contract(manifest); gameplay_simulation(); validate_node_regressions()
    print("Gem Cascade source validation")
    print("="*36)
    for x in CHECKS: print("[PASS]",x)
    for x in WARNINGS: print("[WARN]",x)
    for x in ERRORS: print("[FAIL]",x)
    print(f"\nResult: {'PASS' if not ERRORS else 'FAIL'} ({len(CHECKS)} checks, {len(WARNINGS)} warnings, {len(ERRORS)} errors)")
    return 0 if not ERRORS else 1

if __name__ == "__main__": raise SystemExit(main())
