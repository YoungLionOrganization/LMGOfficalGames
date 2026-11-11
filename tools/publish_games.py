#!/usr/bin/env python3
"""Compare local LeoMiniGames releases with the store and publish updates."""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
import xml.etree.ElementTree as ET

from build_game import GAMES, build, validate_game


API_BASE = "https://leominigames.younglion.xyz/api/v1"
ICON_TYPES = {"png": "image/png", "webp": "image/webp", "svg": "image/svg+xml",
              "jpg": "image/jpeg", "jpeg": "image/jpeg"}
METADATA_FIELDS = ("id", "name", "description", "author", "version", "category",
                   "icon", "min_app_version", "package_format", "entry")


class RejectRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


HTTP = build_opener(RejectRedirects())


def api(path, *, token=None, payload=None, missing_ok=False):
    headers = {"Accept": "application/json", "Cache-Control": "no-cache"}
    body = None
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if token is not None:
        headers["Authorization"] = f"Bearer {token}"
    request = Request(API_BASE + path, data=body, headers=headers)
    try:
        with HTTP.open(request, timeout=30) as response:
            return json.load(response)["data"]
    except HTTPError as error:
        with error:
            if missing_ok and error.code == 404:
                try:
                    if json.load(error)["error"]["code"] == "not_found":
                        return None
                except (ValueError, KeyError, TypeError):
                    pass
        raise RuntimeError(f"{request.get_method()} {path}: HTTP {error.code}") from None
    except URLError:
        raise RuntimeError(f"{request.get_method()} {path}: connection failed") from None


def store_release(game_id):
    release = api(f"/mods/{game_id}", missing_ok=True)
    if release is not None and release["id"] != game_id:
        raise ValueError("Catalog returned a different game ID.")
    return release


def version_parts(version):
    if not isinstance(version, str) or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("Expected a numeric major.minor.patch version.")
    return tuple(int(part) for part in version.split("."))


def release_action(manifest, remote):
    if remote is None:
        return "new"
    local_version = version_parts(manifest["version"])
    remote_version = version_parts(remote["version"])
    # The Vol4 GPL edition and the live Megafactory edition share this ID.
    if manifest["id"] == "pocket_factory" and remote_version == (3, 0, 0):
        return "different edition"
    if local_version > remote_version:
        return "update"
    return "current" if local_version == remote_version else "store is newer"


def put_asset(content, content_type, details, token):
    ticket = api("/admin/upload-url", token=token, payload=details)
    url = urlsplit(ticket["upload_url"])
    key = ticket["object_key"]
    prefix = f"mods/{details['id']}/{details['version']}/"
    if url.scheme != "https" or not url.hostname or url.username or url.password:
        raise ValueError("Expected an HTTPS object upload URL.")
    if not key.startswith(prefix) or not key[len(prefix):]:
        raise ValueError("Upload ticket returned an unexpected object key.")
    request = Request(url.geturl(), data=content, method="PUT",
                      headers={"Content-Type": content_type})
    for attempt in range(3):
        try:
            with HTTP.open(request, timeout=120):
                return key
        except HTTPError as error:
            error.close()
            if attempt == 2 or error.code not in {408, 429, 500, 502, 503, 504}:
                raise RuntimeError(f"{details['kind']} upload failed: HTTP {error.code}") from None
        except (URLError, TimeoutError):
            if attempt == 2:
                raise RuntimeError(f"{details['kind']} upload failed: connection error") from None


def publish(game_dir, manifest, token, rcc):
    game_id = manifest["id"]
    current = json.loads((game_dir / "manifest.json").read_text(encoding="utf-8"))
    if current != manifest:
        raise ValueError("The local manifest changed after the version check.")
    version = validate_game(game_dir)
    icon_path = (game_dir / manifest["icon_path"]).resolve()
    extension = icon_path.suffix.lower().lstrip(".")
    if not icon_path.is_relative_to(game_dir) or extension not in ICON_TYPES:
        raise ValueError("Expected a supported icon inside the game folder.")
    metadata = {key: manifest[key] for key in METADATA_FIELDS}
    build(game_dir, version, rcc)
    package = (game_dir / "dist" / f"{game_id}-{version}.rcc").read_bytes()
    digest = hashlib.sha256(package).hexdigest()
    icon = icon_path.read_bytes()

    if release_action(manifest, store_release(game_id)) not in {"new", "update"}:
        print(f"{game_id}: skipped, the store version changed during the build")
        return

    common = {"market": "mod", "id": game_id, "version": version}
    metadata.update(sha256=digest, size_bytes=len(package))
    metadata["object_key"] = put_asset(
        package, "application/octet-stream",
        dict(common, kind="package", sha256=digest, size_bytes=len(package)), token,
    )
    metadata["icon_object_key"] = put_asset(
        icon, ICON_TYPES[extension],
        dict(common, kind="icon", extension=extension, size_bytes=len(icon)), token,
    )
    if release_action(manifest, store_release(game_id)) not in {"new", "update"}:
        raise RuntimeError("Store version changed before catalog publication.")
    api("/admin/mods", token=token, payload=metadata)
    confirmed = store_release(game_id)
    if not confirmed or confirmed["version"] != version or confirmed["sha256"] != digest:
        raise RuntimeError("The store did not confirm the published version and SHA-256.")
    print(f"{game_id}: published and verified {version}")


def read_token(path):
    token = path.read_text(encoding="utf-8-sig").strip()
    if not token or any(ch.isspace() for ch in token) or not token.isascii():
        raise ValueError("The admin token file must contain one ASCII token.")
    return token


def main():
    games = {folder.name: folder for folder in sorted(GAMES.iterdir())
             if (folder / "manifest.json").is_file()}
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("game", nargs="?", choices=games, help="check one game (default: all)")
    parser.add_argument("--publish", action="store_true", help="build and publish pending releases")
    parser.add_argument("--rcc", default=os.environ.get("LMG_RCC") or "rcc", help="path to Qt 6 rcc")
    parser.add_argument("--token-file", type=Path, default=GAMES.parents[1] / "raw_admin_token",
                        help="admin token file (default: raw_admin_token next to the repository)")
    args = parser.parse_args()

    game_id = "store"
    try:
        pending = []
        for game_id in ([args.game] if args.game else games):
            game_dir = games[game_id]
            manifest = json.loads((game_dir / "manifest.json").read_text(encoding="utf-8"))
            if manifest["id"] != game_id:
                raise ValueError("Manifest ID must match the game folder.")
            version_parts(manifest["version"])
            remote = store_release(game_id)
            action = release_action(manifest, remote)
            remote_version = remote["version"] if remote else "missing"
            print(f"{game_id}: local {manifest['version']}, store {remote_version} ({action})")
            if action in {"new", "update"}:
                pending.append((game_dir, manifest))

        print(f"{len(pending)} release(s) pending.")
        if args.publish and pending:
            game_id = "admin token"
            token = read_token(args.token_file)
            for game_dir, manifest in pending:
                game_id = game_dir.name
                publish(game_dir, manifest, token, args.rcc)
    except (OSError, KeyError, TypeError, ValueError, RuntimeError, ET.ParseError,
            subprocess.CalledProcessError) as error:
        print(f"{game_id}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
