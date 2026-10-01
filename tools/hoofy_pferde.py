#!/usr/bin/env python3
"""Hoofy: derive the horse bodies and coat patterns in games/hoofy/sprites.txt.

    tools/hoofy_pferde.py            rewrite the generated section of games/hoofy/sprites.txt

Input: the hand-drawn Warmblut poses horse_warmblut_<pose> in sprites.txt.
Output (between the marker lines at the end of sprites.txt):
  horse_pony_<pose>, horse_kaltblut_<pose>, horse_einhorn_<pose>
      Pony: shorter legs and body; Kaltblut: taller and longer, white feathering above the
      hooves; Einhorn: Warmblut with a horn. A hand-drawn sprite with the same name elsewhere in
      sprites.txt wins (the generated one is left out), so any pose can be redrawn by hand.
  muster_<pattern>_<body>_<pose>
      coat pattern overlays (drawn over the coat color): only pixels of the coat (h, H, b).
  schmuck_<id>_<body>_<pose>
      jewelry overlays, cropped; their position in the horse image goes to game/schmuck_pos.lua.

make test/run/shot/dist call it before tools/sprites.py; it only writes when something changed.
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PATH = os.path.join(ROOT, "games/hoofy/sprites.txt")
POS_PATH = os.path.join(ROOT, "games/hoofy/game/schmuck_pos.lua")
BEGIN = "# >>> Pferde, erzeugt von tools/hoofy_pferde.py (nicht von Hand ändern, Hand-Sprites gleichen Namens gehen vor)"
END = "# <<< Pferde"

POSES = ["side", "side_walk", "gallop1", "gallop2", "graze", "down", "down_walk", "up", "up_walk"]
SIDE = {"side", "side_walk", "gallop1", "gallop2", "graze"}
COAT = set("hHb")

# Horn (Einhorn): (x, y, Zeichen) in Koordinaten der Warmblut-Pose, y < 0 = über dem Bild.
HORN_SIDE = [(26, 1, "7"), (27, 1, "6"), (27, 0, "7"), (28, 0, "6"), (28, -1, "6"), (29, -2, "6")]
HORN = {
    "side": HORN_SIDE, "side_walk": HORN_SIDE, "gallop1": HORN_SIDE, "gallop2": HORN_SIDE,
    "graze": [(27, 14, "7"), (28, 14, "6"), (28, 13, "6"), (29, 12, "6")],
    "down": [(7, 1, "6"), (8, 1, "7"), (7, 0, "7"), (8, 0, "6"), (7, -1, "6"), (8, -1, "7"), (8, -2, "6")],
    "down_walk": None,  # wie down
    "up": [(7, 0, "7"), (8, 0, "6"), (7, -1, "6")],
    "up_walk": None,
}
HORN["down_walk"], HORN["up_walk"] = HORN["down"], HORN["up"]

RAINBOW = ["D", "m", "Y", "l", "5", "4"]


def read_sprites(text):
    """{name: [rows]} for every sprite block outside the generated section."""
    if BEGIN in text:
        text = text[:text.index(BEGIN)] + text[text.index(END) + len(END):] if END in text else text[:text.index(BEGIN)]
    out = {}
    for m in re.finditer(r"^sprite (\w+)\n((?:[^\n#][^\n]*\n?)+)", text, re.M):
        out[m.group(1)] = [r for r in m.group(2).split("\n") if r]
    return out, text


def pad(rows):
    w = max(len(r) for r in rows)
    return [r.ljust(w, ".") for r in rows]


def diff(a, b):
    return sum(1 for x, y in zip(a, b) if x != y)


def best_row(rows, lo, hi):
    """Row in lo..hi that is most like the row above it (removing/duplicating it hurts least), or None."""
    span = range(max(lo, 1), min(hi, len(rows) - 1) + 1)
    if not span:
        return None
    return min(span, key=lambda r: (diff(rows[r], rows[r - 1]), -r))


# Die Körper entstehen aus dem Warmblut durch Weglassen/Verdoppeln von Zeilen und Spalten. Jede Operation
# wird in LOG mitgeschrieben, damit sich dieselbe Umformung auf die Schmuck-Overlays anwenden lässt.
LOG = None


def log(op, *args):
    if LOG is not None:
        LOG.append((op,) + args)


def drop_row(rows, r):
    log("drop_row", r)
    return rows if r is None else rows[:r] + rows[r + 1:]


def dup_row(rows, r):
    log("dup_row", r)
    return rows if r is None else rows[:r + 1] + rows[r:]


def col(rows, c):
    return "".join(r[c] for r in rows)


def best_col(rows, lo, hi):
    return min(range(max(lo, 1), hi + 1), key=lambda c: (diff(col(rows, c), col(rows, c - 1)), abs(c - (lo + hi) / 2)))


def drop_col(rows, c):
    log("drop_col", c)
    return [r[:c] + r[c + 1:] for r in rows]


def dup_col(rows, c):
    log("dup_col", c)
    return [r[:c + 1] + r[c:] for r in rows]


def replay(rows, ops):
    """Wendet mitgeschriebene Operationen (LOG) auf ein gleich großes Bild an."""
    global LOG
    saved, LOG = LOG, None
    for op in ops:
        if op[0] == "top":
            rows = ["." * len(rows[0])] * op[1] + rows
        else:
            rows = {"drop_row": drop_row, "dup_row": dup_row, "drop_col": drop_col, "dup_col": dup_col}[op[0]](rows, op[1])
    LOG = saved
    return rows


def leg_start(rows, pose):
    """First row of the legs: from here down the gap between the legs is free."""
    h, w = len(rows), len(rows[0])
    mids = [12] if pose in SIDE else [w // 2 - 1, w // 2]
    for y in range(h // 2, h):
        if all(rows[yy][c] == "." for yy in range(y, h) for c in mids):
            return y
    return h - 3


def pony(rows, pose):
    rows = pad(rows)
    legs = leg_start(rows, pose)
    for _ in range(2):
        rows = drop_row(rows, best_row(rows, legs + 1, len(rows) - 3))
    body_lo = 9 if pose in SIDE else 12
    rows = drop_row(rows, best_row(rows, body_lo, legs - 2))
    if pose in SIDE:
        for _ in range(2):
            rows = drop_col(rows, best_col(rows, 7, 15))
    return rows


def kaltblut(rows, pose):
    rows = pad(rows)
    legs = leg_start(rows, pose)
    body_lo = 9 if pose in SIDE else 12
    rows = dup_row(rows, best_row(rows, body_lo, legs - 2))
    if pose in SIDE:
        for _ in range(2):
            rows = dup_col(rows, best_col(rows, 7, 15))
    else:
        w = len(rows[0])
        rows = dup_col(rows, best_col(rows, 2, 4))
        rows = dup_col(rows, best_col(rows, w - 4, w - 2))
    # Behang: die zwei Reihen über den Hufen weiß
    rows = [list(r) for r in rows]
    h = len(rows)
    for x in range(len(rows[0])):
        for y in range(h - 1, 0, -1):
            if rows[y][x] == "u" and y > h * 0.6:
                for yy in (y - 1, y - 2):
                    if rows[yy][x] == "b":
                        rows[yy][x] = "U"
                break
    return ["".join(r) for r in rows]


def einhorn(rows, pose):
    rows = pad(rows)
    horn = HORN[pose]
    top = -min(0, min(y for _, y, _ in horn))
    log("top", top)
    rows = ["." * len(rows[0])] * top + rows
    rows = [list(r) for r in rows]
    for x, y, ch in horn:
        rows[y + top][x] = ch
    return ["".join(r) for r in rows]


def h32(*v):
    h = 2166136261
    for x in v:
        h = ((h ^ (x & 0xffffffff)) * 16777619) & 0xffffffff
    h ^= h >> 13
    return (h * 1274126177 & 0xffffffff) / 4294967296


def smooth(x, y, scale, seed):
    fx, fy = x / scale, y / scale
    x0, y0 = int(fx // 1), int(fy // 1)
    tx, ty = fx - x0, fy - y0
    a, b = h32(x0, y0, seed), h32(x0 + 1, y0, seed)
    c, d = h32(x0, y0 + 1, seed), h32(x0 + 1, y0 + 1, seed)
    top, bot = a + (b - a) * tx, c + (d - c) * tx
    return top + (bot - top) * ty


def pattern(name, x, y, h):
    """Color character of the pattern at (x, y), or None."""
    if name == "schecke":
        limit = 0.42 if y > h * 0.7 else 0.58
        return "V" if smooth(x, y, 5, 11) > limit else None
    if name == "tupfen":
        cell = h32(x // 3, y // 3, 23)
        return "1" if cell < 0.4 and x % 3 < 2 and y % 3 < 2 else None
    if name == "apfel":
        cell = h32(x // 4, y // 4, 31)
        return "2" if cell < 0.7 and x % 4 in (1, 2) and y % 4 in (1, 2) else None
    if name == "fliegen":
        return "3" if h32(x, y, 41) < 0.13 else None
    if name == "zebra":
        return "1" if ((x + y // 2) // 2) % 2 == 0 else None
    if name == "regenbogen":
        return RAINBOW[min(5, y * 6 // h)]
    raise ValueError(name)


PATTERNS = ["schecke", "tupfen", "apfel", "fliegen", "zebra", "regenbogen"]


def overlay(rows, name):
    h = len(rows)
    out = []
    for y, r in enumerate(rows):
        out.append("".join((pattern(name, x, y, h) or ".") if ch in COAT else "." for x, ch in enumerate(r)))
    return out


# ---- Schmuck (Rückmeldung 1.2.1: ausgerüsteter Schmuck ist zu sehen) ----
# Lage am Warmblut (x, y wie im Bild); die anderen Körper bekommen dieselbe Umformung wie das Pferd.
# Schleife: Mitte der Schleife in der Mähne. Kranz: Kacheln (x0, x1, y) einer Blumenreihe um den Hals.
# Decke: Rechteck (x0, y0, x1, y1) auf dem Rücken, nur über Fell. Goldhufeisen: die Hufe unten.
SCHLEIFE = ["P...P", "PPDPP", "P...P"]
SCHLEIFE_AT = {"side": (18, 5), "graze": (21, 11), "down": (8, 3), "up": (8, 4)}
KRANZ_AT = {
    "side": [(15, 21, 8), (15, 21, 9)],
    "graze": [(20, 24, 13), (23, 25, 14)],
    "down": [(2, 5, 12), (10, 13, 12), (4, 11, 13)],
    "up": [(4, 11, 6), (3, 12, 7)],
}
DECKE_AT = {"side": [(6, 9, 16, 13)], "graze": [(6, 9, 16, 13)],
            "down": [(1, 12, 3, 16), (12, 12, 14, 16)], "up": [(1, 8, 14, 11)]}
KRANZ_FARBEN = "PlYlVl"
SCHMUCK = ["maehnenschleife", "blumenkranz", "glitzerdecke", "goldhufeisen"]


def base_pose(pose):
    if pose in ("side", "side_walk", "gallop1", "gallop2"):
        return "side"
    return pose.replace("_walk", "")


def schmuck_warmblut(kind, rows, pose):
    """Overlay in der Größe des Warmblut-Bilds (nur Schleife, Kranz, Decke)."""
    h, w = len(rows), len(rows[0])
    out = [["."] * w for _ in range(h)]
    bp = base_pose(pose)
    if kind == "maehnenschleife":
        cx, cy = SCHLEIFE_AT[bp]
        for dy, line in enumerate(SCHLEIFE):
            for dx, ch in enumerate(line):
                x, y = cx - 2 + dx, cy - 1 + dy
                if ch != "." and 0 <= x < w and 0 <= y < h:
                    out[y][x] = ch
    elif kind == "blumenkranz":
        for x0, x1, y in KRANZ_AT[bp]:
            for x in range(x0, x1 + 1):
                if rows[y][x] != ".":
                    out[y][x] = KRANZ_FARBEN[(x + 3 * y) % len(KRANZ_FARBEN)]
    elif kind == "glitzerdecke":
        for x0, y0, x1, y1 in DECKE_AT[bp]:
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    if rows[y][x] in COAT:
                        trim = y == y1 or (bp in ("side", "graze") and x in (x0, x1))
                        out[y][x] = "7" if trim else ("V" if h32(x, y, 57) < 0.18 else "4")
    return ["".join(r) for r in out]


def hufe(rows):
    """Goldhufeisen: Huf-Pixel (u) in den untersten Reihen, unter denen der Umriss liegt."""
    h = len(rows)
    out = []
    for y, r in enumerate(rows):
        line = []
        for x, ch in enumerate(r):
            below = rows[y + 1][x] if y + 1 < h else "."
            line.append("6" if ch == "u" and y >= h - 4 and below == "k" else ".")
        out.append("".join(line))
    return out


def crop(rows):
    """Schneidet ein Overlay auf seinen Inhalt zu: (Zeilen, x0, y0) oder None, wenn es leer ist."""
    ys = [y for y, r in enumerate(rows) if r.strip(".")]
    if not ys:
        return None
    xs = [x for r in rows for x, ch in enumerate(r) if ch != "."]
    x0, x1, y0, y1 = min(xs), max(xs), ys[0], ys[-1]
    return [r[x0:x1 + 1] for r in rows[y0:y1 + 1]], x0, y0


def block(name, rows):
    return "sprite %s\n%s\n" % (name, "\n".join(rows))


def generate(text):
    hand, rest = read_sprites(text)
    bodies = {"warmblut": {}}
    for pose in POSES:
        name = "horse_warmblut_" + pose
        if name not in hand:
            sys.exit("hoofy_pferde: %s fehlt in sprites.txt" % name)
        bodies["warmblut"][pose] = pad(hand[name])
    global LOG
    out = [BEGIN, ""]
    ops = {"warmblut": {pose: [] for pose in POSES}}
    for body, fn in (("pony", pony), ("kaltblut", kaltblut), ("einhorn", einhorn)):
        bodies[body], ops[body] = {}, {}
        for pose in POSES:
            name = "horse_%s_%s" % (body, pose)
            LOG = []
            rows = fn(bodies["warmblut"][pose], pose)
            ops[body][pose], LOG = LOG, None
            if name in hand:
                bodies[body][pose] = pad(hand[name])
            else:
                bodies[body][pose] = rows
                out.append(block(name, rows))
    pos = []
    for kind in SCHMUCK:
        for body in ("warmblut", "pony", "kaltblut", "einhorn"):
            for pose in POSES:
                rows = bodies[body][pose]
                if kind == "goldhufeisen":
                    ov = hufe(rows)
                else:
                    ov = replay(schmuck_warmblut(kind, bodies["warmblut"][pose], pose), ops[body][pose])
                    if len(ov) != len(rows) or len(ov[0]) != len(rows[0]):
                        ov = None          # von Hand gezeichneter Körper anderer Größe: ohne diesen Schmuck
                c = ov and crop(ov)
                if c:
                    name = "schmuck_%s_%s_%s" % (kind, body, pose)
                    out.append(block(name, c[0]))
                    pos.append("  %s = {%d, %d}," % (name, c[1], c[2]))
    for pat in PATTERNS:
        for body in ("warmblut", "pony", "kaltblut", "einhorn"):
            for pose in POSES:
                out.append(block("muster_%s_%s_%s" % (pat, body, pose), overlay(bodies[body][pose], pat)))
    out.append(END)
    lua = ("-- Erzeugt von tools/hoofy_pferde.py, nicht von Hand ändern.\n"
           "-- Lage der Schmuck-Overlays im Pferdebild: Name → {x, y} der linken oberen Ecke.\n"
           "return {\n" + "\n".join(pos) + "\n}\n")
    return rest.rstrip("\n") + "\n\n" + "\n".join(out) + "\n", lua


def main():
    text = open(PATH, encoding="utf-8").read()
    new, lua = generate(text)
    if new != text:
        with open(PATH, "w", encoding="utf-8") as f:
            f.write(new)
        print("hoofy_pferde: Körper und Muster in sprites.txt erneuert")
    old = open(POS_PATH, encoding="utf-8").read() if os.path.exists(POS_PATH) else None
    if lua != old:
        with open(POS_PATH, "w", encoding="utf-8") as f:
            f.write(lua)
        print("hoofy_pferde: game/schmuck_pos.lua erneuert")


if __name__ == "__main__":
    main()
