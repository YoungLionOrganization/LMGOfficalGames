#!/usr/bin/env python3
"""Copy a Pocket Factory GPL 3.2 autosave into the Community save namespace."""

import argparse
import hashlib
import math
import os
from pathlib import Path
import struct
import tempfile

import cbor2


MAGIC = b"LMGSAVE\0"
MAX_HEADER = 1024 * 1024
MAX_PAYLOAD = 32 * 1024 * 1024
COMMUNITY_ID = "pocket_factory_community"


def numeric(value):
    return type(value) in (int, float) and 0 <= value <= 1e300 and math.isfinite(value)


def convert(source):
    with source.open("rb") as stream:
        prefix = stream.read(12)
        if len(prefix) != 12 or prefix[:8] != MAGIC:
            raise ValueError("Expected a LeoMiniGames save.")
        length = struct.unpack(">I", prefix[8:])[0]
        if not 0 < length <= MAX_HEADER:
            raise ValueError("Invalid save header size.")
        header_bytes = stream.read(length)
        payload = stream.read(MAX_PAYLOAD + 1)
    if len(header_bytes) != length or not 0 < len(payload) <= MAX_PAYLOAD:
        raise ValueError("Save is truncated or exceeds the supported size.")

    header = cbor2.loads(header_bytes)
    if not isinstance(header, dict) or header.get("formatVersion") != 1:
        raise ValueError("Unsupported save format.")
    version = header.get("gameVersion")
    if (header.get("gameId") != "pocket_factory" or header.get("schemaVersion") != 2
            or not isinstance(version, str) or not version.startswith("3.2.")):
        raise ValueError("Expected a Pocket Factory GPL 3.2 save with schema 2.")
    if header.get("checksum") != hashlib.sha256(payload).digest():
        raise ValueError("Save checksum failed.")

    data = cbor2.loads(payload)
    if not isinstance(data, dict) or any(key in data for key in ("state_v3_json", "state_v4_json", "factoryCores")):
        raise ValueError("Expected the six-line GPL edition.")
    lines = data.get("lines")
    if not isinstance(lines, list) or len(lines) != 6 or any(
        not isinstance(line, dict) or not numeric(line.get("level")) or line["level"] < 1
        or type(line.get("manager")) is not bool or not numeric(line.get("progress"))
        for line in lines
    ):
        raise ValueError("The six production line records are missing or invalid.")
    for key in ("coins", "ore", "parts", "circuits", "goods", "robots", "research",
                "reputation", "crowns", "storageLevel", "efficiencyLevel", "lastPersistMs"):
        if not numeric(data.get(key)):
            raise ValueError(f"Invalid GPL save field: {key}")
    contract = data.get("contract")
    if (not isinstance(contract, dict) or contract.get("kind") not in ("goods", "robots", "parts", "exports")
            or any(not numeric(contract.get(key)) for key in ("amount", "progress", "reward", "research"))
            or not 0 <= contract["progress"] <= contract["amount"] or contract["amount"] < 1):
        raise ValueError("Invalid GPL save contract.")

    new_header = cbor2.dumps(dict(header, gameId=COMMUNITY_ID))
    return MAGIC + struct.pack(">I", len(new_header)) + new_header + payload


def copy_save(source, saves_directory):
    contents = convert(source)
    directory = saves_directory.resolve(strict=True)
    if not directory.is_dir():
        raise ValueError("Provide the existing LeoMiniGames saves directory.")
    destination = directory / COMMUNITY_ID
    destination.mkdir(exist_ok=True)
    if destination.is_symlink() or destination.resolve().parent != directory:
        raise ValueError("Unexpected Community save directory.")
    target = destination / "autosave.lmgsave"
    backup = destination / "autosave.lmgsave.bak"
    if os.path.lexists(target) or os.path.lexists(backup):
        raise FileExistsError("Community already has an autosave or a backup.")

    with tempfile.NamedTemporaryFile(dir=destination, prefix=".transfer-", delete=False) as stream:
        staging = Path(stream.name)
    try:
        with staging.open("wb") as stream:
            stream.write(contents)
            stream.flush()
            os.fsync(stream.fileno())
        if os.path.lexists(backup):
            raise FileExistsError("A Community backup appeared during the transfer.")
        # A hard link publishes the complete file without replacing an existing save.
        os.link(staging, target)
    finally:
        staging.unlink()
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="original GPL 3.2 autosave.lmgsave")
    parser.add_argument("saves_directory", type=Path, help="LeoMiniGames saves directory")
    args = parser.parse_args()
    try:
        target = copy_save(args.source, args.saves_directory)
    except (OSError, ValueError, cbor2.CBORError) as error:
        parser.exit(1, f"Transfer failed: {error}\n")
    print(f"Community save copied to {target}")


if __name__ == "__main__":
    main()
