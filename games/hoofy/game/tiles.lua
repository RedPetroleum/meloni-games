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

-- Gebietspalette (KATALOG §10): Sprite-Satz (land_… bzw. die recolor-Kopien in sprites.txt), Wiese und
-- Schatten, Schatten auf Weg und Sand, Kartenfarben von Wald, Baum, Busch, Stein, Weg und Sand.
-- Die Farben müssen zu den recolor-Zeilen in sprites.txt passen.
local function hex(v) return rgb(v >> 16, v >> 8 & 255, v & 255) end
local function pal(set, grass, shadow, path_shadow, sand_shadow, forest, bush, rock, path, sand)
  return {set = set, grass = hex(grass), shadow = hex(shadow), path_shadow = hex(path_shadow), sand_shadow = hex(sand_shadow),
    forest = hex(forest), bush = hex(bush), rock = hex(rock), path = hex(path), sand = hex(sand)}
end
T.PALETTES = {
  ["sattgrün"] = pal("land", 0x7fb04f, 0x62923f, 0xb38c57, 0xcdb27a, 0x37682d, 0x4f8b3a, 0x9aa0a6, 0xd4b077, 0xead7a0),
  ["dunkelgrün"] = pal("birke", 0x4f8a42, 0x3c6e33, 0x94784c, 0xbcae7e, 0x2a5a26, 0x3e7a36, 0x8c968a, 0xb49a6c, 0xd8cc9c),
  ["blaugrün"] = pal("aue", 0x4fa082, 0x3a846a, 0xa8946a, 0xc8bf94, 0x1f5c4c, 0x2f7c66, 0x8a9cac, 0xc8b48a, 0xe4dcb4),
  ["gelb"] = pal("steppe", 0xc9b858, 0xa89844, 0xa07a48, 0xd6c48a, 0x5c6a2a, 0x7f8c3a, 0xb0a48c, 0xc49a62, 0xf0e0a8),
  ["rot-orange"] = pal("canyon", 0xc47a4a, 0xa25e36, 0xc49264, 0xd6ae74, 0x4e5c30, 0x6f7e44, 0xb46a4e, 0xe2b484, 0xf0cc96),
  ["violett"] = pal("nebel", 0x8f72b0, 0x725892, 0xa494b0, 0xcabfd6, 0x343f74, 0x4c5c9a, 0xa8a4b8, 0xc4b4cc, 0xe6deea),
}

-- Böden (Ebene ground). Kartenfarbe (map) für die Übersichtskarte.
T.GROUND = {GRASS = ".", FOREST = "F", WATER = "~", BRIDGE = "=", BRIDGE_V = "I", PATH = ":", SAND = "s"}
T.GROUNDS = {
  ["."] = {base = true, shadow = C.grass_shadow, map = rgb(0x7f, 0xb0, 0x4f)},
  F = {sprites = {"land_forest1", "land_forest2", "land_forest3", "land_forest4"}, solid = true, shadow = C.grass_shadow,
    map = rgb(0x37, 0x68, 0x2d)},
  ["~"] = {frames = {{"ground_water1"}, {"ground_water2"}}, edges = "land_bank", solid = true,
    shadow = C.grass_shadow, map = rgb(0x4a, 0x8c, 0xc0)},
  ["="] = {sprites = {"ground_bridge"}, shadow = C.wood_shadow, map = rgb(0xb0, 0x7a, 0x44)},
  I = {sprites = {"ground_bridge_v"}, shadow = C.wood_shadow, map = rgb(0xb0, 0x7a, 0x44)},
  [":"] = {sprites = {"land_path1", "land_path2"}, edges = "land_fringe", shadow = C.path_shadow,
    map = rgb(0xd4, 0xb0, 0x77)},
  b = {sprites = {"ground_carrots"}, edges = "land_fringe", shadow = C.path_shadow, map = rgb(0x8a, 0x5a, 0x36)},
  s = {sprites = {"land_sand1", "land_sand2"}, edges = "land_fringe", shadow = C.sand_shadow,
    map = rgb(0xea, 0xd7, 0xa0)},
}

-- Pflanzen (C5): pflanze_<id>_<stufe> als Objekte, 1×1 (Apfelbaum 2×2), ohne Kollision
T.PLANT_IDS = {"gras", "karotte", "apfelbaum", "hafer", "sonnenblume", "minze", "zuckerruebe", "luzerne", "drachenfrucht", "goldene_karotte"}

-- Deko auf Gras (Ebene deco), Lage in der Kachel aus einem Hash.
T.DECOS = {a = "land_tuft", b = "land_tuft2", c = "land_flower_p", d = "land_flower_y", e = "land_pebble"}
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
  edge_tree = {variants = {"land_tree", "land_tree", "land_tree", "land_bush"}, jitter = 3, flip = true, map = rgb(0x2a, 0x55, 0x22)},
  tree = {sprite = "land_tree", coll = "T", map = rgb(0x2a, 0x55, 0x22)},
  bush = {sprite = "land_bush", coll = "u", map = rgb(0x4f, 0x8b, 0x3a)},
  rock = {sprite = "land_rock", coll = "o", map = rgb(0x9a, 0xa0, 0xa6)},
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
  goepel = {sprite = "goepel", w = 2, h = 2, coll = "X", map = rgb(0x8a, 0x5a, 0x36)},
  hangar = {sprite = "hangar", w = 6, h = 4, coll = "X", map = rgb(0x6d, 0x73, 0x7a)},
}
fence.map = rgb(0x7b, 0x4c, 0x2b)
for _, id in ipairs(T.PLANT_IDS) do
  for stufe = 1, 3 do
    T.PROPS["pflanze_" .. id .. "_" .. stufe] = {sprite = "pflanze_" .. id .. "_" .. stufe, w = id == "apfelbaum" and 2 or 1,
      h = id == "apfelbaum" and 2 or 1, map = rgb(0x4f, 0x8b, 0x3a)}
  end
end

-- Stellt Wiese, Böden, Deko, Bäume, Büsche und Steine auf die Palette des Gebiets um (name aus
-- K.welt.gebiete): Sprite-Namen land_… werden zu <set>_…, dazu Schatten- und Kartenfarben.
-- Danach muss die Karte neu vorbereitet werden (Tilemap:prepare), das macht Area.get.
local LAND_GROUNDS = {F = {"forest1", "forest2", "forest3", "forest4"}, [":"] = {"path1", "path2"}, s = {"sand1", "sand2"}}
local LAND_DECOS = {a = "tuft", b = "tuft2", c = "flower_p", d = "flower_y", e = "pebble"}
function T.set_palette(name)
  local p = T.PALETTES[name] or T.PALETTES["sattgrün"]
  local function n(id) return p.set .. "_" .. id end
  T.COLORS.grass, T.COLORS.grass_shadow = p.grass, p.shadow
  local G = T.GROUNDS
  G["."].shadow, G["."].map = p.shadow, p.grass
  G.F.shadow, G["~"].shadow = p.shadow, p.shadow
  for ch, ids in pairs(LAND_GROUNDS) do
    local list = {}
    for i, id in ipairs(ids) do list[i] = n(id) end
    G[ch].sprites = list
  end
  G["~"].edges, G[":"].edges, G.s.edges, G.b.edges = n("bank"), n("fringe"), n("fringe"), n("fringe")
  G[":"].shadow, G.s.shadow = p.path_shadow, p.sand_shadow
  G.F.map, G[":"].map, G.s.map = p.forest, p.path, p.sand
  for ch, id in pairs(LAND_DECOS) do T.DECOS[ch] = n(id) end
  local P = T.PROPS
  P.edge_tree.variants = {n("tree"), n("tree"), n("tree"), n("bush")}
  P.tree.sprite, P.bush.sprite, P.rock.sprite = n("tree"), n("bush"), n("rock")
  P.edge_tree.map, P.tree.map, P.bush.map, P.rock.map = p.forest, p.forest, p.bush, p.rock
end

return T
