#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

RCC_ARG="${1:-${RCC:-}}"
PYTHON=""
if command -v python3 >/dev/null 2>&1; then PYTHON="python3"
elif command -v python >/dev/null 2>&1; then PYTHON="python"
else
  echo "[ERROR] Python 3 is required for validation." >&2
  exit 3
fi

VERSION="$($PYTHON -c 'import json; print(json.load(open("manifest.json", encoding="utf-8"))["version"])')"
OUTPUT_DIR="$ROOT/dist"
OUTPUT="$OUTPUT_DIR/harvest_pocket-${VERSION}.rcc"
HASH="$OUTPUT.sha256"

if [[ -n "$RCC_ARG" ]]; then
  RCC_BIN="$RCC_ARG"
elif [[ -n "${QT_RCC:-}" ]]; then
  RCC_BIN="$QT_RCC"
elif command -v rcc >/dev/null 2>&1; then
  RCC_BIN="$(command -v rcc)"
else
  echo "[ERROR] Qt rcc is not available. Pass it as arg 1 or set RCC/QT_RCC." >&2
  exit 4
fi

if [[ "$RCC_BIN" == */* && ! -f "$RCC_BIN" ]]; then
  echo "[ERROR] Qt rcc not found: $RCC_BIN" >&2
  exit 4
fi

QMLLINT_BIN=""
if [[ "$RCC_BIN" == */* ]]; then
  QT_BIN_DIR="$(cd "$(dirname "$RCC_BIN")" && pwd)"
  [[ -x "$QT_BIN_DIR/qmllint" ]] && QMLLINT_BIN="$QT_BIN_DIR/qmllint"
fi
[[ -z "$QMLLINT_BIN" ]] && command -v qmllint >/dev/null 2>&1 && QMLLINT_BIN="$(command -v qmllint)"

if [[ -n "$QMLLINT_BIN" ]]; then
  echo "[QML] Running qmllint syntax preflight..."
  for qml in ./*.qml; do "$QMLLINT_BIN" --max-warnings -1 "$qml"; done
else
  echo "[WARN] qmllint unavailable; Python structural QML validation will still run."
fi

echo "[1/6] Validating source package..."
"$PYTHON" tools/validate_package.py
echo "[2/6] Running gameplay regression..."
"$PYTHON" tools/test_gameplay.py
echo "[3/6] Running migration regression..."
"$PYTHON" tools/test_migration.py
echo "[4/6] Running release-tree meta audit..."
"$PYTHON" tools/meta_audit.py
echo "[5/6] Building RCC..."
mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT" "$HASH"
"$RCC_BIN" --binary mod.qrc -o "$OUTPUT"
[[ -s "$OUTPUT" ]] || { echo "[ERROR] RCC output missing/empty: $OUTPUT" >&2; exit 20; }

echo "[6/6] Hashing output..."
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$OUTPUT_DIR" && sha256sum "$(basename "$OUTPUT")" > "$(basename "$HASH")")
elif command -v shasum >/dev/null 2>&1; then
  (cd "$OUTPUT_DIR" && shasum -a 256 "$(basename "$OUTPUT")" > "$(basename "$HASH")")
else
  "$PYTHON" - "$OUTPUT" "$HASH" <<'PY'
import hashlib, pathlib, sys
src=pathlib.Path(sys.argv[1]); out=pathlib.Path(sys.argv[2])
h=hashlib.sha256(src.read_bytes()).hexdigest()
out.write_text(f"{h}  {src.name}\n", encoding="ascii")
PY
fi
printf '[OK] RCC: %s\n[OK] SHA256: %s\n' "$OUTPUT" "$HASH"
