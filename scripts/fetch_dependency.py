#!/usr/bin/env python3
"""Download the CardDAV component release declared in dependencies.json.

This is the headless stand-in for 4D's Dependency Manager: tool4d cannot fetch
GitHub dependencies itself, so the component is unpacked into Components/ (the
folder 4D and tool4d load components from) before a headless run.

Usage:
    python3 scripts/fetch_dependency.py [--tag 0.1.2] [--destination Project/Components]

The release asset is verified against a pinned SHA256 so a headless run never
loads a silently different build.
"""
import argparse
import hashlib
import json
import os
import shutil
import sys
import urllib.request
import zipfile
from pathlib import Path

API = "https://api.github.com/repos/miyako/CardDAV/releases/tags/{tag}"
ASSET = "CardDAV.zip"
SHA256 = {
    "0.1.2": "f8d6c5a949bd48306aa6ceb89423c735b565301a9eff9dd5743dce08ef038cc9",
}


def _request(url):
    headers = {"User-Agent": "CardDAV-demo-fetch",
               "Accept": "application/vnd.github+json"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = "Bearer " + token
    with urllib.request.urlopen(
            urllib.request.Request(url, headers=headers), timeout=60) as response:
        return response.read()


def _safe_extract(archive, destination):
    destination = destination.resolve()
    for member in archive.infolist():
        target = (destination / member.filename).resolve()
        if target != destination and destination not in target.parents:
            raise ValueError("unsafe archive member: " + member.filename)
        if member.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        with archive.open(member) as source, open(target, "wb") as output:
            shutil.copyfileobj(source, output)
        mode = (member.external_attr >> 16) & 0o777
        if mode:
            target.chmod(mode)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag")
    parser.add_argument("--destination", type=Path, default=Path("Components"))
    parser.add_argument("--tool4d-cache", type=Path,
                        default=Path.home() / "Library/Caches/tool4d/Dependencies")
    parser.add_argument("--no-cache", action="store_true")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    declaration = json.loads(
        (root / "Project/Sources/dependencies.json").read_text())
    entry = declaration["dependencies"]["CardDAV"]
    tag = args.tag or entry.get("tag") or "0.1.2"

    target = args.destination / "CardDAV.4dbase"
    cache_target = args.tool4d_cache / ".github/miyako/CardDAV" / tag
    if (target / "CardDAV.4DZ").is_file() and (
            args.no_cache or (cache_target / "CardDAV.4DZ").is_file()):
        print(f"component already staged at {target}")
        return 0

    release = json.loads(_request(API.format(tag=tag)))
    asset = next((item for item in release.get("assets", [])
                  if item["name"] == ASSET), None)
    if asset is None:
        print(f"release {tag} has no {ASSET} asset", file=sys.stderr)
        return 1

    print(f"downloading {asset['name']} from release {tag}")
    payload = _request(asset["browser_download_url"])
    digest = hashlib.sha256(payload).hexdigest()
    expected = SHA256.get(tag)
    if expected and digest != expected:
        print(f"sha256 mismatch: expected {expected}, got {digest}",
              file=sys.stderr)
        return 1
    archive_path = args.destination / (ASSET + ".download")
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    archive_path.write_bytes(payload)
    try:
        with zipfile.ZipFile(archive_path) as archive:
            _safe_extract(archive, args.destination)
    finally:
        archive_path.unlink(missing_ok=True)

    if not (target / "CardDAV.4DZ").is_file():
        print(f"unpacked release does not contain {target / 'CardDAV.4DZ'}",
              file=sys.stderr)
        return 1
    print(f"staged {target} (sha256 {digest})")

    if not args.no_cache:
        if cache_target.is_dir():
            shutil.rmtree(cache_target)
        shutil.copytree(target, cache_target)
        metadata = {
            "github": entry.get("github", "miyako/CardDAV"),
            "tag": tag,
            "htmlURL": f"https://github.com/miyako/CardDAV/releases/tag/{tag}",
            "archiveURL": asset["browser_download_url"],
            "archiveSize": len(payload),
            "dependencies": None,
        }
        (cache_target.parent / (tag + ".json")).write_text(
            json.dumps(metadata, indent="\t") + "\n")
        print(f"primed tool4d cache at {cache_target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
