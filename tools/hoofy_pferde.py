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

make test/run/shot/dist call it before tools/sprites.py; it only writes when something changed.
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PATH = os.path.join(ROOT, "games/hoofy/sprites.txt")
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


def drop_row(rows, r):
    return rows if r is None else rows[:r] + rows[r + 1:]


def dup_row(rows, r):
    return rows if r is None else rows[:r + 1] + rows[r:]


def col(rows, c):
    return "".join(r[c] for r in rows)


def best_col(rows, lo, hi):
    return min(range(max(lo, 1), hi + 1), key=lambda c: (diff(col(rows, c), col(rows, c - 1)), abs(c - (lo + hi) / 2)))


def drop_col(rows, c):
    return [r[:c] + r[c + 1:] for r in rows]


def dup_col(rows, c):
    return [r[:c + 1] + r[c:] for r in rows]


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
    out = [BEGIN, ""]
    for body, fn in (("pony", pony), ("kaltblut", kaltblut), ("einhorn", einhorn)):
        bodies[body] = {}
        for pose in POSES:
            name = "horse_%s_%s" % (body, pose)
            if name in hand:
                bodies[body][pose] = pad(hand[name])
            else:
                rows = fn(bodies["warmblut"][pose], pose)
                bodies[body][pose] = rows
                out.append(block(name, rows))
    for pat in PATTERNS:
        for body in ("warmblut", "pony", "kaltblut", "einhorn"):
            for pose in POSES:
                out.append(block("muster_%s_%s_%s" % (pat, body, pose), overlay(bodies[body][pose], pat)))
    out.append(END)
    return rest.rstrip("\n") + "\n\n" + "\n".join(out) + "\n"


def main():
    text = open(PATH, encoding="utf-8").read()
    new = generate(text)
    if new != text:
        with open(PATH, "w", encoding="utf-8") as f:
            f.write(new)
        print("hoofy_pferde: Körper und Muster in sprites.txt erneuert")


if __name__ == "__main__":
    main()
