#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"

VERSION="6.7.0"
OUTPUT="$PWD/gem_cascade-${VERSION}.rcc"
SMOKE_BUILD="$PWD/.build/qt_rcc_smoke"
RCC_INPUT="${1:-rcc}"

if command -v python3 >/dev/null 2>&1; then PYTHON=python3
elif command -v python >/dev/null 2>&1; then PYTHON=python
else echo "[ERROR] Python 3 is required for source validation." >&2; exit 1
fi

if [ -x "$RCC_INPUT" ] || [ -f "$RCC_INPUT" ]; then
    RCC_EXE=$(cd "$(dirname "$RCC_INPUT")" && pwd)/$(basename "$RCC_INPUT")
elif command -v "$RCC_INPUT" >/dev/null 2>&1; then
    RCC_EXE=$(command -v "$RCC_INPUT")
else
    echo "[ERROR] rcc executable not found: $RCC_INPUT" >&2
    echo "Usage: ./build_mod.sh /path/to/rcc" >&2
    exit 1
fi

QT_BIN=$(cd "$(dirname "$RCC_EXE")" && pwd)
QT_ROOT=$(cd "$QT_BIN/.." && pwd)
QT_BASE=$(cd "$QT_ROOT/../.." 2>/dev/null && pwd || true)
QT_CMAKE="$QT_BIN/qt-cmake"
[ -x "$QT_CMAKE" ] || QT_CMAKE=$(command -v qt-cmake 2>/dev/null || true)
# Make the selected Qt runtime/plugins discoverable when the smoke executable
# is launched outside an IDE shell. Existing user values are preserved.
PATH="$QT_BIN:$PATH"; export PATH
if [ -d "$QT_ROOT/lib" ]; then
    LD_LIBRARY_PATH="$QT_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; export LD_LIBRARY_PATH
    DYLD_LIBRARY_PATH="$QT_ROOT/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"; export DYLD_LIBRARY_PATH
fi
if [ -d "$QT_ROOT/plugins" ]; then
    QT_PLUGIN_PATH="$QT_ROOT/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"; export QT_PLUGIN_PATH
fi
CMAKE_EXE="${QT_BASE:+$QT_BASE/Tools/CMake_64/bin/cmake}"
[ -n "$CMAKE_EXE" ] && [ -x "$CMAKE_EXE" ] || CMAKE_EXE=$(command -v cmake 2>/dev/null || true)
NINJA_EXE="${QT_BASE:+$QT_BASE/Tools/Ninja/ninja}"
[ -n "$NINJA_EXE" ] && [ -x "$NINJA_EXE" ] || NINJA_EXE=$(command -v ninja 2>/dev/null || true)

[ -f manifest.json ] || { echo "[ERROR] manifest.json not found." >&2; exit 1; }
[ -f mod.qrc ] || { echo "[ERROR] mod.qrc not found." >&2; exit 1; }

printf '%s\n' "============================================================" \
              "  Gem Cascade $VERSION - VERIFIED RCC BUILD" \
              "============================================================" \
              "RCC    : $RCC_EXE" \
              "Qt kit : $QT_ROOT" \
              "Output : $OUTPUT" ""

echo "[1/5] Validating source, QRC contract, i18n, gameplay and build contract..."
"$PYTHON" "$PWD/tools/validate_source.py"

echo
echo "[2/5] Building binary RCC..."
rm -f "$OUTPUT"
"$RCC_EXE" --binary "$PWD/mod.qrc" -o "$OUTPUT"
[ -s "$OUTPUT" ] || { echo "[ERROR] RCC returned success but output is missing/empty." >&2; exit 1; }

if [ "${GEM_CASCADE_SKIP_QT_SMOKE:-0}" = "1" ]; then
    echo
echo "[WARN] GEM_CASCADE_SKIP_QT_SMOKE=1: mounted RCC / QQmlEngine verification skipped by explicit request."
    echo "[OK] $OUTPUT created (UNVERIFIED Qt runtime smoke)."
    exit 0
fi

echo
echo "[3/5] Checking Qt post-build smoke toolchain..."
[ -n "$QT_CMAKE" ] && [ -x "$QT_CMAKE" ] || { echo "[ERROR] qt-cmake not found for selected Qt kit." >&2; rm -f "$OUTPUT"; exit 1; }
[ -n "$CMAKE_EXE" ] && [ -x "$CMAKE_EXE" ] || { echo "[ERROR] cmake not found." >&2; rm -f "$OUTPUT"; exit 1; }
[ -n "$NINJA_EXE" ] && [ -x "$NINJA_EXE" ] || { echo "[ERROR] ninja not found." >&2; rm -f "$OUTPUT"; exit 1; }

echo
echo "[4/5] Building mounted-RCC QQmlEngine verifier..."
rm -rf "$SMOKE_BUILD"
"$QT_CMAKE" -S "$PWD/tools/qt_rcc_smoke" -B "$SMOKE_BUILD" -G Ninja -DCMAKE_MAKE_PROGRAM="$NINJA_EXE"
"$CMAKE_EXE" --build "$SMOKE_BUILD" --parallel
SMOKE_EXE="$SMOKE_BUILD/gem_cascade_rcc_smoke"
[ -x "$SMOKE_EXE" ] || { echo "[ERROR] Post-build smoke executable was not created." >&2; rm -f "$OUTPUT"; exit 1; }

echo
echo "[5/5] Mounting ACTUAL RCC at /mods/gem_cascade and loading Main.qml..."
if ! "$SMOKE_EXE" "$OUTPUT"; then
    rm -f "$OUTPUT"
    echo "[ERROR] Post-build smoke failed. No unverified RCC is left behind." >&2
    exit 1
fi

echo
echo "============================================================"
echo "[OK] Gem Cascade $VERSION BUILD COMPLETED AND VERIFIED"
echo "============================================================"
echo "$OUTPUT"
