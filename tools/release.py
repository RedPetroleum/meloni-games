#!/usr/bin/env python3
"""Builds the release folder for the HU-086 updater.

    tools/release.py [--out dist] [--extra SRC:DEST ...]

- every games/<id>/ with a main.lua becomes dist/<id>.mlg (-> roms/meloni/<id>.mlg on the SD card)
- games/<id>/cover.png becomes dist/<id>.png (-> romart/meloni/<id>.png, shown in the launcher)
- --extra adds other files, e.g. extra/tool.nes:roms/nes/tool.nes
- dist/manifest.json lists everything with size and sha256; the updater on the device downloads
  what changed and removes what disappeared.

.mlg format ("MLG1"): u32 count, per file u16 name length, name, u32 offset, u32 size (little endian,
offsets from the start of the file), then the file data. Files are sorted, so the archive (and its
sha256) only changes when a game file changes.
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def engine_api_version():
    """MEL_API_VERSION from engine/meloni/meloni.h: games may not need a newer API."""
    header = open(os.path.join(ROOT, "engine", "meloni", "meloni.h"), encoding="utf-8").read()
    match = re.search(r"#define\s+MEL_API_VERSION\s+(\d+)", header)
    if not match:
        sys.exit("MEL_API_VERSION not found in engine/meloni/meloni.h")
    return int(match.group(1))

SKIP_FILES = {"cover.png", "sprites.txt", "figur.txt", ".DS_Store"}  # sprites.txt, figur.txt: sources of sprites.png
SKIP_EXTENSIONS = (".sav", ".md")


def game_files(game_dir):
    files = []
    for base, dirs, names in os.walk(game_dir):
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        for name in sorted(names):
            if name.startswith(".") or name in SKIP_FILES or name.endswith(SKIP_EXTENSIONS):
                continue
            path = os.path.join(base, name)
            files.append(os.path.relpath(path, game_dir).replace(os.sep, "/"))
    return files


def pack(game_dir, out_path):
    names = game_files(game_dir)
    blobs = [open(os.path.join(game_dir, n), "rb").read() for n in names]
    header_size = 8 + sum(2 + len(n.encode()) + 8 for n in names)
    header = bytearray(b"MLG1" + struct.pack("<I", len(names)))
    offset = header_size
    for name, blob in zip(names, blobs):
        encoded = name.encode()
        header += struct.pack("<H", len(encoded)) + encoded + struct.pack("<II", offset, len(blob))
        offset += len(blob)
    with open(out_path, "wb") as f:
        f.write(header)
        for blob in blobs:
            f.write(blob)
    return names


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def load_meta(game_id, game_dir):
    meta_path = os.path.join(game_dir, "meta.json")
    if not os.path.exists(meta_path):
        sys.exit(f"{game_id}: meta.json missing")
    meta = json.load(open(meta_path, encoding="utf-8"))
    for key in ("name", "version", "api"):
        if key not in meta:
            sys.exit(f"{game_id}: meta.json needs '{key}'")
    if meta.get("id", game_id) != game_id:
        sys.exit(f"{game_id}: meta.json id '{meta['id']}' must match the folder name")
    if meta["api"] > engine_api_version():
        sys.exit(f"{game_id}: api {meta['api']} is newer than the engine's {engine_api_version()}")
    return meta


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=os.path.join(ROOT, "dist"))
    ap.add_argument("--extra", action="append", default=[], metavar="SRC:DEST")
    args = ap.parse_args()

    shutil.rmtree(args.out, ignore_errors=True)
    os.makedirs(args.out)
    entries = []

    def add(asset, dest, **info):
        path = os.path.join(args.out, asset)
        entries.append({"path": dest, "url": asset, "size": os.path.getsize(path), "sha256": sha256(path), **info})

    games_dir = os.path.join(ROOT, "games")
    for game_id in sorted(os.listdir(games_dir)):
        game_dir = os.path.join(games_dir, game_id)
        if not os.path.isfile(os.path.join(game_dir, "main.lua")):
            continue
        meta = load_meta(game_id, game_dir)
        names = pack(game_dir, os.path.join(args.out, f"{game_id}.mlg"))
        add(f"{game_id}.mlg", f"roms/meloni/{game_id}.mlg", name=meta["name"], version=meta["version"], api=meta["api"])
        cover = os.path.join(game_dir, "cover.png")
        if os.path.exists(cover):
            shutil.copy(cover, os.path.join(args.out, f"{game_id}.png"))
            add(f"{game_id}.png", f"romart/meloni/{game_id}.png")
        print(f"{game_id}.mlg: {len(names)} files ({', '.join(names)})")

    for extra in args.extra:
        src, _, dest = extra.partition(":")
        if not dest or not dest.startswith(("roms/", "romart/")):
            sys.exit(f"--extra {extra}: DEST must start with roms/ or romart/")
        asset = os.path.basename(dest)
        if os.path.exists(os.path.join(args.out, asset)):
            sys.exit(f"--extra {extra}: asset name {asset} is used twice")
        shutil.copy(os.path.join(ROOT, src), os.path.join(args.out, asset))
        add(asset, dest)
        print(f"{asset}: from {src}")

    try:
        commit = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        commit = "unknown"
    manifest = {
        "format": 1,
        "generated": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "commit": commit,
        "files": entries,
    }
    with open(os.path.join(args.out, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
    print(f"manifest.json: {len(entries)} files -> {args.out}")


if __name__ == "__main__":
    main()
