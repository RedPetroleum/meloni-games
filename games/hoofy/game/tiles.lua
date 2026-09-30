-- Was die Zeichen der Kartenebenen bedeuten (lib/tilemap.lua): Böden, Deko, Kollisionsformen,
-- Objekte. Die Karten selbst erzeugt game/mapgen.lua.
local Map = require("lib.tilemap")

local T = {}

T.COLORS = {
  grass = rgb(0x7f, 0xb0, 0x4f),
  grass_shadow = rgb(0x62, 0x92, 0x3f),
  path_shadow = rgb(0xb3, 0x8c, 0x57),
  sand_shadow = rgb(0xcd, 0xb2, 0x7a),
  wood_shadow = rgb(0x55, 0x33, 0x20),
}
local C = T.COLORS

-- Böden (Ebene ground). Kartenfarbe (map) für die Übersichtskarte.
T.GROUND = {GRASS = ".", FOREST = "F", WATER = "~", BRIDGE = "=", BRIDGE_V = "I", PATH = ":", SAND = "s"}
T.GROUNDS = {
  ["."] = {base = true, shadow = C.grass_shadow, map = rgb(0x7f, 0xb0, 0x4f)},
  F = {sprites = {"ground_forest1", "ground_forest2"}, solid = true, shadow = C.grass_shadow,
    map = rgb(0x37, 0x68, 0x2d)},
  ["~"] = {frames = {{"ground_water1"}, {"ground_water2"}}, edges = "bank", solid = true,
    shadow = C.grass_shadow, map = rgb(0x4a, 0x8c, 0xc0)},
  ["="] = {sprites = {"ground_bridge"}, shadow = C.wood_shadow, map = rgb(0xb0, 0x7a, 0x44)},
  I = {sprites = {"ground_bridge_v"}, shadow = C.wood_shadow, map = rgb(0xb0, 0x7a, 0x44)},
  [":"] = {sprites = {"ground_path1", "ground_path2"}, edges = "fringe", shadow = C.path_shadow,
    map = rgb(0xd4, 0xb0, 0x77)},
  s = {sprites = {"ground_sand1", "ground_sand2"}, edges = "fringe", shadow = C.sand_shadow,
    map = rgb(0xea, 0xd7, 0xa0)},
}

-- Deko auf Gras (Ebene deco), Lage in der Kachel aus einem Hash.
T.DECOS = {a = "deco_tuft", b = "deco_tuft2", c = "deco_flower_p", d = "deco_flower_y", e = "deco_pebble"}
T.DECO_MIX = "aabbcde"

-- Kollisionsformen (Ebene coll): Rechtecke in Pixeln relativ zur Kachel.
T.SHAPES = {
  T = {{4, 9, 12, 16}},     -- Baum auf der Wiese
  u = {{1, 7, 15, 16}},     -- Busch
  o = {{2, 9, 14, 16}},     -- Stein
  X = {{0, 0, 16, 16}},     -- Gebäude
  Y = {{1, 6, 15, 12}},     -- Hindernis
  B = {{1, 8, 15, 16}},     -- Bank
  H = {{0, 6, 16, 16}},     -- Hecke
  L = {{5, 10, 11, 16}},    -- Lampe, Statue
  K = {{2, 8, 14, 16}},     -- Blumenkübel
}
-- Zaun: "A" + Maske der Nachbarn (1 links, 2 rechts, 4 oben, 8 unten), Pfosten + Latten.
T.FENCE_BASE = string.byte("A")
for mask = 0, 15 do
  local list = {{5, 10, 11, 16}}
  if mask & 1 ~= 0 then list[#list + 1] = {0, 10, 8, 16} end
  if mask & 2 ~= 0 then list[#list + 1] = {8, 10, 16, 16} end
  if mask & 4 ~= 0 then list[#list + 1] = {5, 0, 11, 10} end
  T.SHAPES[string.char(T.FENCE_BASE + mask)] = list
end

-- Höhe der Hindernisse in Pixeln: wer höher springt, kommt drüber (Bäume und Häuser nie).
T.HEIGHTS = {u = 12, o = 16, Y = 14, B = 10, H = 14, K = 10}
for mask = 0, 15 do T.HEIGHTS[string.char(T.FENCE_BASE + mask)] = 18 end

local function fence_mask(map, cx, cy)
  if cx < 0 or cy < 0 or cx >= map.w or cy >= map.h then return 0 end
  local c = string.byte(map.coll[cy + 1], cx + 1) - T.FENCE_BASE
  return (c >= 0 and c < 16) and c or -1
end

local fence = {
  build = function(map, cx, cy)
    local S, x, y = map.S, cx * Map.TILE, cy * Map.TILE
    local mask = fence_mask(map, cx, cy)
    local parts = {}
    if mask & 1 ~= 0 then parts[#parts + 1] = Map.part(S, "fence_rail_e", x, y + 4, true) end
    if mask & 2 ~= 0 then parts[#parts + 1] = Map.part(S, "fence_rail_e", x + 8, y + 4) end
    if mask & 4 ~= 0 then parts[#parts + 1] = Map.part(S, "fence_rail_v", x + 6, y - 1) end
    parts[#parts + 1] = Map.part(S, "fence_post", x + 6, y + 3)
    return parts
  end,
}

-- Objekte: sprite (oder variants), w/h Grundfläche in Kacheln, coll = Zeichen der Kollisionsform
-- für die ganze Grundfläche (nil: keine), map = Farbe auf der Übersichtskarte.
T.PROPS = {
  edge_tree = {variants = {"tree", "tree", "tree", "bush"}, jitter = 3, flip = true, map = rgb(0x2a, 0x55, 0x22)},
  tree = {sprite = "tree", coll = "T", map = rgb(0x2a, 0x55, 0x22)},
  bush = {sprite = "bush", coll = "u", map = rgb(0x4f, 0x8b, 0x3a)},
  rock = {sprite = "rock", coll = "o", map = rgb(0x9a, 0xa0, 0xa6)},
  shop = {sprite = "house_a", w = 3, h = 2, coll = "X", map = rgb(0xb8, 0x47, 0x3a)},
  cottage = {sprite = "cottage_a", w = 3, h = 2, coll = "X", map = rgb(0x5d, 0x7f, 0xb0)},
  stand = {sprite = "stand", w = 2, coll = "X", map = rgb(0xe0, 0x47, 0x5a)},
  board = {sprite = "board", coll = "u", map = rgb(0x7b, 0x4c, 0x2b)},
  jump = {sprite = "jump", coll = "Y", dy = -2, map = rgb(0xfb, 0xf8, 0xef)},
  fence = fence,
  wohnwagen = {sprite = "wohnwagen", w = 3, h = 2, coll = "X", map = rgb(0xfb, 0xf8, 0xef)},
  stall_s = {sprite = "stable", w = 4, h = 3, coll = "X", map = rgb(0x8a, 0x5a, 0x36)},
  gate = {sprite = "gate", map = rgb(0x7b, 0x4c, 0x2b)},
  bank = {sprite = "bank", coll = "B", map = rgb(0xb0, 0x7a, 0x44)},
  lampe = {sprite = "lampe", coll = "L", map = rgb(0xf7, 0xd6, 0x5a)},
  blumenkuebel = {sprite = "blumenkuebel", coll = "K", map = rgb(0xe0, 0x47, 0x5a)},
  hecke = {sprite = "hecke", coll = "H", map = rgb(0x37, 0x68, 0x2d)},
  brunnen = {sprite = "brunnen", w = 2, h = 2, coll = "X", map = rgb(0x9a, 0xa0, 0xa6)},
  teich = {sprite = "teich", w = 2, h = 2, coll = "X", dy = 4, map = rgb(0x4a, 0x8c, 0xc0)},
  statue = {sprite = "statue", coll = "L", map = rgb(0xc8, 0xcd, 0xd1)},
  stall_m = {sprite = "stall_m", w = 6, h = 3, coll = "X", map = rgb(0x8a, 0x5a, 0x36)},
  stall_l = {sprite = "stall_l", w = 8, h = 4, coll = "X", map = rgb(0x8a, 0x5a, 0x36)},
  stall_xl = {sprite = "stall_xl", w = 10, h = 4, coll = "X", map = rgb(0x8a, 0x5a, 0x36)},
  haeuschen = {sprite = "cottage_a", w = 3, h = 2, coll = "X", map = rgb(0x5d, 0x7f, 0xb0)},
  villa = {sprite = "villa", w = 5, h = 3, coll = "X", map = rgb(0xfb, 0xf8, 0xef)},
  schuppen = {sprite = "schuppen", w = 3, h = 2, coll = "X", map = rgb(0x7b, 0x4c, 0x2b)},
  garage = {sprite = "garage", w = 4, h = 3, coll = "X", map = rgb(0x9a, 0xa0, 0xa6)},
  hangar = {sprite = "hangar", w = 6, h = 4, coll = "X", map = rgb(0x6d, 0x73, 0x7a)},
}
fence.map = rgb(0x7b, 0x4c, 0x2b)

return T
