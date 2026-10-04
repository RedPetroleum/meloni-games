#!/usr/bin/env python3
"""Hoofy: the player figure in layers for the wardrobe (games/hoofy/figur.txt).

    tools/hoofy_figur.py            rewrite the generated section of games/hoofy/sprites.txt
                                    and games/hoofy/game/figur_pos.lua

figur.txt holds the layers (body, bottoms, tops, hair, hats) drawn in the coordinates of the 12x20
player image, and the color variants. Every layer is cropped to its pixels. The pixels that take the chosen
color (hair L y, tops B X J, bottoms T t) are left out of the sprite and become rectangles instead; the
game fills them in the chosen color and draws the sprite (outline, fixed colors) on top. So one sprite per
layer serves every color. The sprites go between the marker lines in sprites.txt, offsets, rectangles and
colors go to game/figur_pos.lua.

make test/run/shot/dist call it before tools/sprites.py; it only writes when something changed.
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
GAME = os.path.join(ROOT, "games/hoofy")
SRC = os.path.join(GAME, "figur.txt")
SPRITES = os.path.join(GAME, "sprites.txt")
POS = os.path.join(GAME, "game/figur_pos.lua")
BEGIN = "# >>> Figur, erzeugt von tools/hoofy_figur.py aus figur.txt (nicht von Hand ändern)"
END = "# <<< Figur"
PFERDE = "# >>> Pferde"
KINDS = ("fhaar", "foben", "funten")


def palette_of(text):
    pal, on = {}, False
    for line in text.split("\n"):
        if line.strip() == "palette":
            on = True
            continue
        if on:
            if not line.strip():
                break
            if line.startswith("#"):
                continue
            parts = line.split()
            pal[parts[0]] = parts[1].lower()
    return pal


def parse(path, pal):
    layers, colors, cur = [], [], None
    for number, raw in enumerate(open(path, encoding="utf-8"), 1):
        line = raw.rstrip("\n").rstrip()
        where = f"{path}:{number}"
        if not line or line.startswith("#"):
            cur = None
            continue
        if line.startswith("farbe "):
            parts = line.split()
            if len(parts) < 4 or parts[1] not in KINDS:
                sys.exit(f"{where}: farbe ART ID Z=RRGGBB … (ART: {', '.join(KINDS)})")
            swaps = {}
            for s in parts[3:]:
                if not re.fullmatch(r".=[0-9a-fA-F]{6}", s):
                    sys.exit(f"{where}: '{s}' sollte wie 'L=6b3e26' aussehen")
                if s[0] not in pal:
                    sys.exit(f"{where}: '{s[0]}' steht nicht in der Palette von sprites.txt")
                swaps[s[0]] = s[2:].lower()
            colors.append({"kind": parts[1], "id": parts[2], "swaps": swaps, "where": where})
            cur = None
        elif line.startswith("layer "):
            parts = line.split()
            if len(parts) != 4 or not re.fullmatch(r"[a-z_]+", parts[1]):
                sys.exit(f"{where}: layer NAME X Y")
            if any(l["name"] == parts[1] for l in layers):
                sys.exit(f"{where}: Schicht {parts[1]} doppelt")
            cur = {"name": parts[1], "x": int(parts[2]), "y": int(parts[3]), "rows": [], "where": where}
            layers.append(cur)
        elif cur is not None:
            for ch in line:
                if ch != "." and ch not in pal:
                    sys.exit(f"{where}: '{ch}' steht nicht in der Palette von sprites.txt")
            cur["rows"].append(line)
        else:
            sys.exit(f"{where}: erwartet 'layer', 'farbe' oder eine Leerzeile")
    return layers, colors


def crop(layer):
    rows = layer["rows"]
    pts = [(x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch != "."]
    if not pts:
        sys.exit(f"{layer['where']}: Schicht {layer['name']} ist leer")
    x0, x1 = min(p[0] for p in pts), max(p[0] for p in pts)
    y0, y1 = min(p[1] for p in pts), max(p[1] for p in pts)
    out = [r.ljust(x1 + 1, ".")[x0:x1 + 1] for r in rows[y0:y1 + 1]]
    return layer["x"] + x0, layer["y"] + y0, out


def rects(rows, ch):
    """Rechtecke (x0, y0, x1, y1), die genau die Pixel mit Zeichen ch abdecken: Läufe je Zeile, gleiche Läufe
    in Folgezeilen zusammengefasst."""
    out, open_ = [], {}
    for y, r in enumerate(rows + [""]):
        runs, x = [], 0
        while x < len(r):
            if r[x] == ch:
                x0 = x
                while x < len(r) and r[x] == ch:
                    x += 1
                runs.append((x0, x - 1))
            else:
                x += 1
        still = {}
        for run in runs:
            if run in open_:
                still[run] = open_.pop(run)
            else:
                still[run] = y
        for (x0, x1), y0 in open_.items():
            out.append((x0, y0, x1, y - 1))
        open_ = still
    return sorted(out, key=lambda q: (q[1], q[0]))


def main():
    text = open(SPRITES, encoding="utf-8").read()
    pal = palette_of(text)
    layers, colors = parse(SRC, pal)
    chars = {k: set() for k in KINDS}          # Zeichen, die je Art gefärbt werden
    for c in colors:
        chars[c["kind"]] |= set(c["swaps"])

    block = [BEGIN, "# Spielfigur in Schichten (Garderobe), Quelle: figur.txt. Gefärbte Flächen fehlen hier, die",
             "# zeichnet game/figur.lua als Rechtecke (game/figur_pos.lua) in der gewählten Farbe."]
    pos = []
    for l in layers:
        ox, oy, rows = crop(l)
        kind = l["name"].split("_")[0]
        own = sorted(chars.get(kind, ()))
        fixed = ["".join("." if ch in own else ch for ch in r) for r in rows]
        has_sprite = any(ch != "." for r in fixed for ch in r)
        if has_sprite:
            block += [f"sprite {l['name']}"] + fixed + [""]
        # kompakt als Bytes: x+8, y+16, Breite, Höhe, Sprite ja/nein, dann je Zeichen: Zeichen, Anzahl, x0 y0 x1 y1 …
        data = [ox + 8, oy + 16, len(rows[0]), len(rows), 1 if has_sprite else 0]
        for ch in own:
            rs = rects(rows, ch)
            if rs:
                data += [ord(ch), len(rs)] + [v for q in rs for v in q]
        assert all(0 <= v < 256 for v in data), l["name"]
        pos.append(f"    {l['name']} = \"{''.join(f'\\{v}' for v in data)}\",")
    base, lua_colors = {}, []
    for c in colors:
        k = c["kind"]
        if all(pal[ch] == v for ch, v in c["swaps"].items()):
            if k in base:
                sys.exit(f"{c['where']}: zweite Grundfarbe für {k}")
            base[k] = c["id"]
        missing = chars[k] - set(c["swaps"])
        if missing:
            sys.exit(f"{c['where']}: Farbe für {', '.join(sorted(missing))} fehlt")
        lua_colors.append(f"    {k}_{c['id']} = \"{''.join(ch + v for ch, v in c['swaps'].items())}\",")
    for k in KINDS:
        if k not in base:
            sys.exit(f"{SRC}: keine Grundfarbe für {k} (eine farbe muss der Palette in sprites.txt entsprechen)")
    block.append(END)

    if BEGIN in text:
        start = text.index(BEGIN)
        end = text.index(END, start) + len(END)
        new = text[:start] + "\n".join(block) + text[end:]
    elif PFERDE in text:
        # vor den Teil von tools/hoofy_pferde.py, der setzt seinen immer ans Ende
        at = text.index(PFERDE)
        new = text[:at] + "\n".join(block) + "\n\n" + text[at:]
    else:
        new = text.rstrip("\n") + "\n\n" + "\n".join(block) + "\n"
    changed = []
    if new != text:
        open(SPRITES, "w", encoding="utf-8").write(new)
        changed.append("sprites.txt")

    lua = ("-- Erzeugt von tools/hoofy_figur.py aus figur.txt, nicht von Hand ändern.\n"
           "-- pos: Schicht → Bytes (kompakt, ausgepackt in game/figur.lua): x + 8, y + 16 der linken oberen Ecke im\n"
           "-- 12×20-Bild der Figur, Breite, Höhe, 1 = hat ein Sprite; dann je färbbarem Zeichen: Zeichen, Anzahl Rechtecke,\n"
           "-- je Rechteck x0 y0 x1 y1 (relativ zur Schicht), gefüllt in der gewählten Farbe.\n"
           "-- farbe: Farbvariante → je Zeichen das Zeichen und RRGGBB; das erste ist die Musterfarbe (Farbfeld im Editor).\n"
           "-- basis: die Farbe, die der Palette in sprites.txt entspricht (Grundausstattung).\n"
           "return {\n  pos = {\n" + "\n".join(pos) + "\n  },\n  farbe = {\n" + "\n".join(lua_colors) + "\n  },\n"
           "  basis = {" + ", ".join(f"{k} = \"{base[k]}\"" for k in KINDS) + "},\n}\n")
    if not os.path.exists(POS) or open(POS, encoding="utf-8").read() != lua:
        open(POS, "w", encoding="utf-8").write(lua)
        changed.append("game/figur_pos.lua")
    if changed:
        print(f"games/hoofy: Figur {len(layers)} Schichten, {len(colors)} Farben -> {', '.join(changed)}")


if __name__ == "__main__":
    main()
