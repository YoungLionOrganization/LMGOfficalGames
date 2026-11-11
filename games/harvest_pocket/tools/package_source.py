#!/usr/bin/env python3
"""Create a deterministic Harvest Pocket source release ZIP and SHA-256 sidecar."""
from pathlib import Path
import hashlib, json, zipfile

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
version = str(manifest["version"])
release_dir = ROOT / "release"
release_dir.mkdir(exist_ok=True)
out = release_dir / f"HarvestPocket_{version}_Source.zip"

excluded_dirs = {"dist", "release", "__pycache__", ".git", ".idea", ".vscode"}
excluded_suffixes = {".pyc", ".tmp", ".bak", ".orig"}
files = []
for p in ROOT.rglob("*"):
    if not p.is_file():
        continue
    rel = p.relative_to(ROOT)
    if any(part in excluded_dirs for part in rel.parts):
        continue
    if p.suffix.lower() in excluded_suffixes:
        continue
    files.append((p, rel.as_posix()))

with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
    for p, rel in sorted(files, key=lambda x: x[1]):
        info = zipfile.ZipInfo(f"harvest_pocket/{rel}", date_time=(2026, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = (0o755 if rel == "build_mod.sh" else 0o644) << 16
        zf.writestr(info, p.read_bytes())

digest = hashlib.sha256(out.read_bytes()).hexdigest()
sidecar = out.with_suffix(out.suffix + ".sha256")
sidecar.write_text(f"{digest}  {out.name}\n", encoding="ascii")
print(out)
print(sidecar)
