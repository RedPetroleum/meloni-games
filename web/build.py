#!/usr/bin/env python3
"""Baut den Browser-Player: eine einzelne HTML-Datei mit Engine (WebAssembly) und allen Spielen.

    python3 web/build.py build/web/meloni.wasm dist build/web/meloni-konsole.html
    python3 web/build.py build/web/meloni.wasm dist build/web/drittmittel/index.html --only drittmittel

Erwartet die Engine als WebAssembly (make web baut sie) und die Spiele aus make dist.
Mit --only entsteht eine Fokus-Seite: nur dieses eine Spiel, ohne Auswahl, nur Konsole und darunter
die Steuerung. Steht in games/<id>/meta.json ein Feld "controls" (Liste aus [Taste, Aktion],
Tasten: dpad, A, B, START, SELECT), zeigt die Seite die Belegung für genau dieses Spiel.
"""
import base64
import html as htmllib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAMES_DIR = os.path.join(HERE, "..", "games")
FIRST = ["kuschelwiese"]  # steht vorne und ist vorausgewählt


def b64(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode()


def main():
    args = sys.argv[1:]
    only = None
    if "--only" in args:
        i = args.index("--only")
        if i + 1 >= len(args):
            sys.exit(__doc__)
        only = args[i + 1]
        del args[i:i + 2]
    if len(args) != 3:
        sys.exit(__doc__)
    wasm, dist, out = args
    manifest = json.load(open(os.path.join(dist, "manifest.json"), encoding="utf-8"))
    covers = {f["url"][:-4]: f["url"] for f in manifest["files"] if f["path"].startswith("romart/")}
    games = []
    for f in manifest["files"]:
        if not f["path"].endswith(".mlg"):
            continue
        gid = f["url"][:-4]
        if only and gid != only:
            continue
        game = {"id": gid, "name": f["name"], "version": f["version"], "mlg": b64(os.path.join(dist, f["url"]))}
        meta_path = os.path.join(GAMES_DIR, gid, "meta.json")
        if os.path.exists(meta_path):
            controls = json.load(open(meta_path, encoding="utf-8")).get("controls")
            if controls:
                game["controls"] = controls
        if gid in covers:
            game["cover"] = b64(os.path.join(dist, covers[gid]))
        games.append(game)
    if only and not games:
        sys.exit(f"--only {only}: kein solches Spiel in {dist}")
    games.sort(key=lambda g: (g["id"] not in FIRST, FIRST.index(g["id"]) if g["id"] in FIRST else 0, g["name"]))
    core = open(os.path.join(HERE, "core.js"), encoding="utf-8").read()
    page = open(os.path.join(HERE, "player.html"), encoding="utf-8").read()
    page = page.replace("__CORE__", core).replace("__GAMES__", json.dumps(games, ensure_ascii=False))
    page = page.replace("__FOCUS__", "true" if only else "false")
    title = htmllib.escape(games[0]["name"] if only else "Meloni")
    if only:
        page = page.replace("<title>Meloni Spielkonsole</title>", f"<title>{title}</title>")
    page = page.replace("__WASM__", b64(wasm))
    # Eigenständige Datei: zum Öffnen im Browser braucht sie ein vollständiges Gerüst
    doc = ('<!doctype html>\n<html lang="de">\n<head>\n<meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">\n'
            # Vom iOS-Home-Bildschirm als eigene Web-App starten (Vollbild, eigener Speicher ohne 7-Tage-Löschung)
            '<meta name="apple-mobile-web-app-capable" content="yes">\n'
            '<meta name="mobile-web-app-capable" content="yes">\n'
            '<meta name="apple-mobile-web-app-title" content="' + title + '">\n'
            '<meta name="apple-mobile-web-app-status-bar-style" content="black">\n'
            '<style>body{margin:0}</style>\n</head>\n<body>\n' + page + '\n</body>\n</html>\n')
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        f.write(doc)
    print(f"{out}: {'Fokus ' + only if only else str(len(games)) + ' Spiele'}, {len(doc) // 1024} KB")


if __name__ == "__main__":
    main()
