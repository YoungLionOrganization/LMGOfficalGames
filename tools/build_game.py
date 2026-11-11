#!/usr/bin/env python3
"""Validate and compile an official LeoMiniGames RCC package."""

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET


GAMES = Path(__file__).resolve().parents[1] / "games"


def validate_game(game_dir):
    manifest = json.loads((game_dir / "manifest.json").read_text(encoding="utf-8"))
    if manifest["id"] != game_dir.name:
        raise ValueError("Manifest ID must match the game folder name.")
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", manifest["version"]):
        raise ValueError("Manifest version must have the form major.minor.patch.")
    if manifest["package_format"] != "rcc-v1" or manifest["plugin_level"] != 2:
        raise ValueError("Expected a Level 2 RCC v1 plugin.")
    if manifest["license"] != "GPL-3.0-or-later" or manifest["source_available"] is not True:
        raise ValueError("Expected a GPL-3.0-or-later source release.")
    if manifest.get("license_file") != "LICENSE" or not (game_dir / "LICENSE").is_file():
        raise ValueError("Missing LICENSE.")

    qrc = ET.parse(game_dir / "mod.qrc").getroot()
    groups = qrc.findall("qresource")
    if qrc.tag != "RCC" or not groups:
        raise ValueError("mod.qrc must contain an RCC root and at least one qresource.")

    files = {path.relative_to(game_dir).as_posix() for path in game_dir.rglob("*") if path.is_file()}
    resources = {}
    for group in groups:
        if group.get("prefix", "/") != "/":
            raise ValueError("The host mounts the game itself, so qresource prefix must be '/'.")
        language = group.get("lang", "")
        for node in group.findall("file"):
            source = (node.text or "").strip()
            if source not in files or not (game_dir / source).resolve().is_relative_to(game_dir):
                raise ValueError(f"Missing or out-of-tree QRC source: {source!r}")
            alias = node.get("alias", source)
            path = PurePosixPath(alias)
            if not path.parts or path.is_absolute() or ".." in path.parts or "\\" in alias:
                raise ValueError(f"Invalid QRC alias: {alias!r}")
            key = language, path.as_posix()
            if key in resources:
                raise ValueError(f"Duplicate QRC resource: {alias!r} ({language or 'default'}).")
            resources[key] = source

    if ("", manifest["entry"]) not in resources:
        raise ValueError("The manifest entry point is missing from mod.qrc.")
    if resources.get(("", "manifest.json")) != "manifest.json":
        raise ValueError("The source manifest must be packaged at /manifest.json.")
    if manifest["icon_path"] not in files:
        raise ValueError(f"Missing manifest icon: {manifest['icon_path']}")

    return manifest["version"]


def build(game_dir, version, rcc):
    executable = shutil.which(rcc)
    if not executable:
        raise ValueError("Qt 6 rcc was not found. Use --rcc or set LMG_RCC.")
    executable = Path(executable).resolve()

    dist = game_dir / "dist"
    dist.mkdir(exist_ok=True)
    filename = f"{game_dir.name}-{version}.rcc"
    with tempfile.TemporaryDirectory(dir=dist) as temp_dir:
        package = Path(temp_dir) / filename
        subprocess.run([str(executable), "--binary", "mod.qrc", "-o", str(package)],
                       cwd=game_dir, check=True)
        if not package.is_file() or package.stat().st_size == 0:
            raise ValueError("rcc did not create a nonempty package.")
        with package.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        checksum = package.with_suffix(".rcc.sha256")
        checksum.write_text(f"{digest}  {filename}\n", encoding="ascii", newline="\n")
        package.replace(dist / package.name)
        checksum.replace(dist / checksum.name)
    print(f"Built {dist / filename}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("game", choices=sorted(p.name for p in GAMES.iterdir()
                                              if (p / "manifest.json").is_file()))
    parser.add_argument("--rcc", default=os.environ.get("LMG_RCC") or "rcc",
                        help="path to Qt 6 rcc")
    parser.add_argument("--validate-only", action="store_true", help="check the source without Qt")
    args = parser.parse_args()
    game_dir = GAMES / args.game
    try:
        version = validate_game(game_dir)
        print(f"Validated {args.game} {version}")
        if not args.validate_only:
            build(game_dir, version, args.rcc)
    except (KeyError, OSError, ValueError, ET.ParseError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"{args.game}: {error}\n")


if __name__ == "__main__":
    main()
