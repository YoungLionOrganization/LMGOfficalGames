#!/usr/bin/env python3
"""Release-tree hygiene audit for Harvest Pocket."""
from pathlib import Path
import json, os, re, shutil, subprocess, sys, xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
errors=[]; checks=0

def check(cond,msg):
    global checks
    checks+=1
    if not cond: errors.append(msg)

# Parse every JSON and XML/SVG source file.
for p in ROOT.rglob('*.json'):
    try: json.loads(p.read_text(encoding='utf-8')); check(True,f'json {p.name}')
    except Exception as e: check(False,f'JSON parse failed {p.relative_to(ROOT)}: {e}')
for p in [ROOT/'mod.qrc', *ROOT.rglob('*.svg')]:
    try: ET.parse(p); check(True,f'xml {p.name}')
    except Exception as e: check(False,f'XML parse failed {p.relative_to(ROOT)}: {e}')

manifest=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'))
version=str(manifest.get('version',''))
check(version=='7.4.2',f'manifest version expected 7.4.2, got {version}')
for p in [ROOT/'build_mod.sh',ROOT/'build_mod.bat',ROOT/'build.bat',ROOT/'tools'/'build_harvest_pocket.ps1']:
    check(p.is_file(),f'release script missing: {p.relative_to(ROOT)}')
shell_script = ROOT / 'build_mod.sh'
shell_text = shell_script.read_text(encoding='utf-8') if shell_script.is_file() else ''

# Windows builds must not require Bash/WSL/Git Bash just to audit a Linux/macOS
# helper script.  On POSIX, validate the executable bit and use bash -n when
# a real Bash is available.  Otherwise perform deterministic static checks.
if os.name != 'nt':
    check(os.access(shell_script, os.X_OK), 'build_mod.sh must be executable on POSIX')

check(shell_text.startswith('#!/usr/bin/env bash'), 'build_mod.sh must use the bash env shebang')
check('set -euo pipefail' in shell_text, 'build_mod.sh must enable set -euo pipefail')

if os.name != 'nt':
    bash = shutil.which('bash')
    if bash:
        try:
            r = subprocess.run([bash, '-n', str(shell_script)], capture_output=True, text=True)
            detail = (r.stderr or r.stdout or '').strip()
            check(r.returncode == 0, 'build_mod.sh shell syntax failed' + (': ' + detail if detail else ''))
        except OSError as e:
            # Missing/unlaunchable Bash is an environment limitation, not a source-package error.
            print(f'[WARN] Bash syntax check skipped: {e}')
    else:
        print('[WARN] Bash syntax check skipped: bash is not installed.')
else:
    print('[INFO] Windows audit: build_mod.sh checked statically; Bash/WSL is not required.')

# Smart Fields release must carry its dedicated component and source-level gates.
check((ROOT/'IrrigationZoneChip.qml').is_file(), 'IrrigationZoneChip.qml missing')
main_text=(ROOT/'Main.qml').read_text(encoding='utf-8')
check('function batchWaterAllDry()' in main_text and 'function batchHarvestAllReady()' in main_text and 'function batchFertilizeSelectedZone()' in main_text, 'Smart Fields batch actions missing')

# Release-visible documents must identify the same release.
for rel in ['README.md','BUG_HUNTER_AUDIT.md','GAMER_AUDIT.md','SAVE_AUDIT.md','VALIDATION_REPORT.md']:
    text=(ROOT/rel).read_text(encoding='utf-8')
    check(version in text,f'{rel} does not reference release version {version}')

# No local-machine absolute paths, editor debris, caches, or generated RCC in source tree.
win_abs=re.compile(r'(?i)[A-Z]:\\\\(?:Users|Qt|Program Files|Desktop)\\\\')
for p in ROOT.rglob('*'):
    if not p.is_file(): continue
    rel=p.relative_to(ROOT).as_posix()
    check(p.suffix.lower() not in {'.bak','.orig','.tmp','.pyc'},f'temporary file: {rel}')
    if rel.startswith('dist/') or rel.startswith('release/'):
        continue
    if p.suffix.lower() in {'.qml','.js','.json','.md','.bat','.sh','.py','.qrc','.txt'} or p.name in {'LICENSE'}:
        try: text=p.read_text(encoding='utf-8')
        except UnicodeDecodeError: continue
        check(win_abs.search(text) is None,f'local Windows path leaked into {rel}')
check(not any(p.name=='__pycache__' for p in ROOT.rglob('*') if p.is_dir()),'__pycache__ present')
# dist/ and release/ are intentional build-output directories and are ignored so repeat builds stay idempotent.

# Town Market release gates.
check((ROOT/'MarketTrendChip.qml').is_file(), 'Town Market trend component missing')
check((ROOT/'assets/ui/refresh.svg').is_file() and (ROOT/'assets/ui/clock.svg').is_file(), 'Town Market SVG controls missing')
check('function refreshOrderBoard()' in main_text and 'function marketForecast()' in main_text, 'Town Market board/forecast logic missing')
check('orderHistory' in main_text and 'highestOrderReward' in main_text, 'Town Market order history state missing')
check('syncOrderRejectBudget()' not in main_text and 'dayTransitionWatchdog' in main_text, 'v7.4.x Next Day deadlock fix missing')
check('orderVisibleSignature' in main_text and 'refreshableOrderCount' in main_text, 'v7.4.x board refresh no-op fix missing')

# v7.4.2 runtime-logic harness. Node is optional for end-user builds, but when
# available it executes the actual JS function bodies extracted from Main.qml.
runtime_logic = ROOT/'tools'/'test_runtime_logic.js'
check(runtime_logic.is_file(), 'tools/test_runtime_logic.js missing')
node = shutil.which('node')
if node and runtime_logic.is_file():
    try:
        run = subprocess.run([node, str(runtime_logic)], cwd=str(ROOT), capture_output=True, text=True, timeout=30)
        detail = (run.stdout or '') + (run.stderr or '')
        check(run.returncode == 0 and 'RUNTIME LOGIC PASS:' in detail, 'actual-QML runtime logic harness failed' + (': ' + detail.strip()[-1200:] if detail.strip() else ''))
    except Exception as e:
        check(False, f'actual-QML runtime logic harness could not run: {e}')
else:
    print('[WARN] Node.js unavailable; actual-QML runtime logic harness skipped (Python/static gates still run).')
check('function harvestCore(i, batchMode)' in main_text and 'function repairKnownState()' in main_text, 'v7.4.2 harvest/state-repair functions missing')
check('if (root.commitNextDay())' in main_text and 'msg_day_commit_failed' in main_text, 'v7.4.2 transactional Next Day guard missing')
check('function restoreRuntimeSnapshot(s)' in main_text and main_text.count('restoreRuntimeSnapshot(before)') >= 6, 'v7.4.2 exact transaction rollback missing')
check('applySnapshot(before)' not in main_text, 'rollback must not invoke save normalization')
check('if (cropId !== "" && !isCropId(cropId)) cropId = ""' in main_text, 'corrupt crop-id normalization missing')
check('msg_harvest_before_fertilize' in main_text, 'ready-crop fertilizer guard missing')
check('if (root.inputLocked || root.activeTab !== 0) return' in main_text, 'off-tab/transition GameInput lock missing')


if errors:
    print(f'META AUDIT FAIL: {len(errors)} errors after {checks} checks')
    for e in errors: print(' -',e)
    sys.exit(1)
print(f'META AUDIT PASS: {checks}/{checks} checks')
