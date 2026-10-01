#!/usr/bin/env python3
"""Sprites as text: games/<id>/sprites.txt -> sprites.png + sprites.lua.

    tools/sprites.py games/<id>          build (does nothing without sprites.txt)
    tools/sprites.py import IMAGE X Y W H NAME [--palette games/<id>/sprites.txt] [--bg RRGGBB]
                                         print a PNG region as a sprite block, e.g. from a
                                         screenshot of the runner or a drawing from a paint program

sprites.txt: one character per pixel, "." is transparent. Lines starting with # are comments.

    palette
    b 954f36   Fell
    m 413130   Mähne

    sprite horse_run1
    ..mm.....
    .mbbbbb..
    ...b..b..

A sprite ends at a blank line. Color variants (e.g. coat colors) without copying the pixels:

    recolor horse fox  b=c26a2e m=e8b070

copies every sprite whose name starts with "horse_" as "fox_..." (horse_run1 -> fox_run1) and
swaps the listed palette characters for new colors (RRGGBB or another palette character).

In the game:

    local S = require('sprites')      -- loads sprites.png, call it at the top or in _init
    S.draw('horse_run1', x, y)        -- optional: flip_x, flip_y
    local w, h = S.size('horse_run1')

The generated files are committed with the game (the runner and the device use them as they are);
make test, run, shot and dist rebuild them first, and only write them when something changed.
"""
import argparse
import os
import re
import struct
import sys
import zlib

HEADER = "-- Erzeugt von tools/sprites.py aus sprites.txt, nicht von Hand ändern.\n"


# ---- PNG ----

def write_png(path, width, height, rgba):
    """rgba: list of rows, each a list of (r, g, b, a)."""
    raw = bytearray()
    for row in rgba:
        raw.append(0)
        for px in row:
            raw.extend(px)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def read_png(path):
    """Returns (width, height, rows of (r, g, b, a)). Non-interlaced PNGs of any common type."""
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        sys.exit(f"{path}: not a PNG")
    pos, idat, palette, trns = 8, b"", None, None
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
        elif kind == b"PLTE":
            palette = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif kind == b"tRNS":
            trns = body
        elif kind == b"IDAT":
            idat += body
    if interlace:
        sys.exit(f"{path}: interlaced PNGs are not supported")
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    bits = channels * depth
    stride, bpp = (width * bits + 7) // 8, max(1, bits // 8)
    raw = zlib.decompress(idat)
    rows, prev = [], bytearray(stride)
    for y in range(height):
        f, line = raw[y * (stride + 1)], bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b, c = prev[i], prev[i - bpp] if i >= bpp else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        prev = line
        if depth < 8:
            per_byte, mask = 8 // depth, (1 << depth) - 1
            values = [(line[x // per_byte] >> (8 - depth * (x % per_byte + 1))) & mask for x in range(width)]
        elif depth == 8:
            values = list(line)
        else:
            values = [line[i] for i in range(0, len(line), 2)]  # 16 bit: high byte
        row = []
        for x in range(width):
            v = values[x * channels:(x + 1) * channels]
            if ctype == 3:
                r, g, b = palette[v[0]]
                a = trns[v[0]] if trns and v[0] < len(trns) else 255
            elif ctype == 0:
                r = g = b = v[0] * 255 // ((1 << min(depth, 8)) - 1)
                a = 255
            elif ctype == 4:
                r = g = b = v[0]
                a = v[1]
            else:
                r, g, b = v[:3]
                a = v[3] if ctype == 6 else 255
            row.append((r, g, b, a))
        rows.append(row)
    return width, height, rows


# ---- sprites.txt ----

def parse(path):
    palette, sprites, section, current = {".": None}, [], None, None
    recolors = []
    for number, line in enumerate(open(path, encoding="utf-8"), 1):
        line = line.rstrip("\n").rstrip()
        where = f"{path}:{number}"
        if not line or line.startswith("#"):
            current = None
            continue
        if line == "palette":
            section, current = "palette", None
        elif line.startswith("recolor "):
            parts = line.split()
            if len(parts) < 4 or not all(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", n) for n in parts[1:3]):
                sys.exit(f"{where}: recolor lines look like 'recolor horse fox b=c26a2e m=e8b070'")
            swaps = {}
            for swap in parts[3:]:
                if not re.fullmatch(r".=(#?[0-9a-fA-F]{6}|.)", swap):
                    sys.exit(f"{where}: '{swap}' should look like 'b=c26a2e' or 'b=m'")
                swaps[swap[0]] = swap[2:]
            recolors.append({"base": parts[1], "name": parts[2], "swaps": swaps, "where": where})
            section, current = None, None
        elif line.startswith("sprite "):
            name = line.split(None, 1)[1].strip()
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
                sys.exit(f"{where}: sprite name '{name}' must be a Lua identifier")
            if any(s["name"] == name for s in sprites):
                sys.exit(f"{where}: sprite '{name}' defined twice")
            section, current = "sprite", {"name": name, "rows": [], "line": number}
            sprites.append(current)
        elif section == "palette":
            parts = line.split()
            if len(parts) < 2 or len(parts[0]) != 1 or not re.fullmatch(r"#?[0-9a-fA-F]{6}", parts[1]):
                sys.exit(f"{where}: palette lines look like 'b 954f36 comment'")
            if parts[0] in palette:
                sys.exit(f"{where}: color '{parts[0]}' defined twice (or '.', which is transparent)")
            hexcode = parts[1].lstrip("#")
            palette[parts[0]] = tuple(int(hexcode[i:i + 2], 16) for i in (0, 2, 4))
        elif section == "sprite" and current is not None:
            for ch in line:
                if ch not in palette:
                    sys.exit(f"{where}: '{ch}' is not in the palette")
            current["rows"].append(line)
        else:
            sys.exit(f"{where}: expected 'palette', 'sprite NAME' or a blank line")
    for s in sprites:
        if not s["rows"]:
            sys.exit(f"{path}:{s['line']}: sprite '{s['name']}' has no pixels")
        s["w"], s["h"] = max(len(r) for r in s["rows"]), len(s["rows"])
    names = {s["name"] for s in sprites}
    for rc in recolors:
        colors = {}
        for ch, value in rc["swaps"].items():
            if ch not in palette or ch == ".":
                sys.exit(f"{rc['where']}: '{ch}' is not in the palette")
            if len(value) == 1:
                if value not in palette:
                    sys.exit(f"{rc['where']}: '{value}' is not in the palette")
                colors[ch] = palette[value]
            else:
                hexcode = value.lstrip("#")
                colors[ch] = tuple(int(hexcode[i:i + 2], 16) for i in (0, 2, 4))
        prefix = rc["base"] + "_"
        base = [s for s in sprites if s["name"].startswith(prefix) and "colors" not in s]
        if not base:
            sys.exit(f"{rc['where']}: no sprites named {prefix}...")
        for s in base:
            name = rc["name"] + "_" + s["name"][len(prefix):]
            if name in names:
                sys.exit(f"{rc['where']}: sprite '{name}' defined twice")
            names.add(name)
            sprites.append(dict(s, name=name, colors=colors))
    return palette, sprites


# Rows per sheet. The console decodes a PNG with two full RGBA copies (lodepng, then the engine's
# conversion), so one tall sheet needs several MB of contiguous PSRAM at once; a 256x2926 sheet
# (Hoofy) crashed the console at startup. Taller sets are split into sprites.png, sprites_2.png, ...
SHEET_MAX_H = 512


def pack(sprites, sheet_w=256, max_h=SHEET_MAX_H):
    """Shelf packing, tallest first, onto sheets of at most max_h rows (a single taller sprite gets
    a sheet of its own). Sets sheet, x, y on every sprite; returns [(width, height)] per sheet."""
    sheet_w = max(sheet_w, max(s["w"] for s in sprites))
    sheets = []
    x = y = shelf_h = 0
    for s in sorted(sprites, key=lambda s: (-s["h"], s["name"])):
        if x + s["w"] > sheet_w:
            x, y, shelf_h = 0, y + shelf_h, 0
        if not sheets or (x == 0 and y > 0 and y + s["h"] > max_h):
            if sheets:
                sheets[-1] = y
            sheets.append(0)
            x = y = shelf_h = 0
        s["sheet"], s["x"], s["y"] = len(sheets), x, y
        x += s["w"]
        shelf_h = max(shelf_h, s["h"])
    sheets[-1] = y + shelf_h
    return [(sheet_w, h) for h in sheets]


def sheet_file(n):
    return "sprites.png" if n == 1 else f"sprites_{n}.png"


def build(game_dir):
    source = os.path.join(game_dir, "sprites.txt")
    if not os.path.exists(source):
        return False
    palette, sprites = parse(source)
    if not sprites:
        sys.exit(f"{source}: no sprites")
    sheets = pack(sprites)
    pixels = [[[(0, 0, 0, 0)] * w for _ in range(h)] for w, h in sheets]
    for s in sprites:
        sheet = pixels[s["sheet"] - 1]
        for dy, row in enumerate(s["rows"]):
            for dx, ch in enumerate(row):
                color = s.get("colors", {}).get(ch) or palette[ch]
                if color:
                    sheet[s["y"] + dy][s["x"] + dx] = color + (255,)
    # Only write what changed: the PNG bytes may differ between zlib versions (CI vs. laptop), and a
    # rewritten file would give the game a new checksum and the console an update for nothing.
    changed = False
    for n, ((width, height), rows) in enumerate(zip(sheets, pixels), 1):
        png_path = os.path.join(game_dir, sheet_file(n))
        if not os.path.exists(png_path) or read_png(png_path) != (width, height, [[tuple(p) for p in row] for row in rows]):
            write_png(png_path, width, height, rows)
            changed = True
    n = len(sheets) + 1
    while os.path.exists(os.path.join(game_dir, sheet_file(n))):
        os.remove(os.path.join(game_dir, sheet_file(n)))
        changed = True
        n += 1
    lua_path = os.path.join(game_dir, "sprites.lua")

    if len(sheets) == 1:
        rects = "\n".join(f"  {s['name']} = {{{s['x']}, {s['y']}, {s['w']}, {s['h']}}}," for s in sprites)
        lua = HEADER + f"""local img = loadimg('sprites.png')
local rects = {{
{rects}
}}

local S = {{img = img, rects = rects}}

-- Zeichnet ein Sprite mit der oberen linken Ecke bei x, y.
function S.draw(name, x, y, flip_x, flip_y)
  local r = rects[name]
  if not r then error('unknown sprite ' .. tostring(name), 2) end
  sspr(img, r[1], r[2], r[3], r[4], x, y, r[3], r[4], flip_x, flip_y)
end
"""
    else:
        loads = "\n".join(f"local s{n} = loadimg('{sheet_file(n)}')" for n in range(1, len(sheets) + 1))
        rects = "\n".join(f"  {s['name']} = {{{s['x']}, {s['y']}, {s['w']}, {s['h']}, s{s['sheet']}}},"
                           for s in sprites)
        lua = HEADER + f"""-- Mehrere Bilder (tools/sprites.py SHEET_MAX_H), der 5. Eintrag eines Rechtecks ist sein Bild.
{loads}
local rects = {{
{rects}
}}

local S = {{img = s1, imgs = {{{", ".join(f"s{n}" for n in range(1, len(sheets) + 1))}}}, rects = rects}}

-- Zeichnet ein Sprite mit der oberen linken Ecke bei x, y.
function S.draw(name, x, y, flip_x, flip_y)
  local r = rects[name]
  if not r then error('unknown sprite ' .. tostring(name), 2) end
  sspr(r[5], r[1], r[2], r[3], r[4], x, y, r[3], r[4], flip_x, flip_y)
end
"""
    lua += """
-- Breite und Höhe eines Sprites.
function S.size(name)
  local r = rects[name]
  if not r then error('unknown sprite ' .. tostring(name), 2) end
  return r[3], r[4]
end

return S
"""
    if not os.path.exists(lua_path) or open(lua_path, encoding="utf-8").read() != lua:
        with open(lua_path, "w", encoding="utf-8") as f:
            f.write(lua)
        changed = True
    if changed:
        sizes = ", ".join(f"{sheet_file(n)} ({w}x{h})" for n, (w, h) in enumerate(sheets, 1))
        print(f"{game_dir}: {len(sprites)} sprites -> {sizes}, sprites.lua")
    return True


# ---- import ----

def to565(c):
    """The screen has 16-bit colors: compare colors the way they end up on the display."""
    return (c[0] >> 3, c[1] >> 2, c[2] >> 3)


def import_region(args):
    width, height, rows = read_png(args.image)
    if args.x < 0 or args.y < 0 or args.x + args.w > width or args.y + args.h > height:
        sys.exit(f"region is outside the {width}x{height} image")
    known = {}  # 16-bit color -> character
    if args.palette and os.path.exists(args.palette):
        for ch, color in parse(args.palette)[0].items():
            if color:
                known[to565(color)] = ch

    def lookup(color):
        # Nearest palette color, so tiny differences (rounding on the way to the screen) still match
        key = to565(color)
        best = min(known, key=lambda k: sum(abs(a - b) for a, b in zip(k, key)), default=None)
        if best is not None and sum(abs(a - b) for a, b in zip(best, key)) <= args.tolerance:
            return known[best]
        return None
    bg = tuple(int(args.bg[i:i + 2], 16) for i in (0, 2, 4)) if args.bg else None
    free = [c for c in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            if c not in known.values()]
    new_colors, lines = {}, []
    for y in range(args.y, args.y + args.h):
        line = ""
        for x in range(args.x, args.x + args.w):
            r, g, b, a = rows[y][x]
            if a < 128 or (bg and to565((r, g, b)) == to565(bg)):
                line += "."
                continue
            ch = lookup((r, g, b))
            if ch is None:
                if not free:
                    sys.exit("too many colors")
                ch = known[to565((r, g, b))] = free.pop(0)
                new_colors[ch] = (r, g, b)
            line += ch
        lines.append(line.rstrip(".") or ".")  # a blank line would end the sprite
    while lines and lines[-1] == ".":
        lines.pop()
    if new_colors:
        print("# new colors for the palette:")
        for ch, c in new_colors.items():
            print(f"{ch} {c[0]:02x}{c[1]:02x}{c[2]:02x}")
        print()
    print(f"sprite {args.name}")
    print("\n".join(lines))


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "import":
        ap = argparse.ArgumentParser(prog="sprites.py import")
        ap.add_argument("image")
        for name in ("x", "y", "w", "h"):
            ap.add_argument(name, type=int)
        ap.add_argument("name")
        ap.add_argument("--palette", help="sprites.txt whose palette characters to reuse")
        ap.add_argument("--bg", help="background color RRGGBB that becomes transparent")
        ap.add_argument("--tolerance", type=int, default=2,
                        help="how far (in 16-bit color steps) a pixel may be from a palette color")
        import_region(ap.parse_args(sys.argv[2:]))
        return
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("game_dirs", nargs="+")
    for game_dir in ap.parse_args().game_dirs:
        build(game_dir)


if __name__ == "__main__":
    main()
