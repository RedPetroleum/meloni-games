-- Was die Zeichen in den Level-Karten bedeuten: Böden, Requisiten, Legende.
-- Neues Zeichen = neuer Eintrag in LEGEND; neue Requisite = Sprite in sprites.txt + Eintrag in PROPS.
local Map = require("lib.tilemap")

local T = {}

T.COLORS = {
  grass = rgb(0x7f, 0xb0, 0x4f),
  grass_shadow = rgb(0x62, 0x92, 0x3f),
  path_shadow = rgb(0xb3, 0x8c, 0x57),
  sand_shadow = rgb(0xcd, 0xb2, 0x7a),
  soil_shadow = rgb(0x5a, 0x38, 0x22),
  wood_shadow = rgb(0x55, 0x33, 0x20),
}
local C = T.COLORS

T.GROUNDS = {
  grass = {
    base = true, shadow = C.grass_shadow, deco_chance = 0.22,
    deco = {"deco_tuft", "deco_tuft", "deco_tuft2", "deco_tuft2", "deco_flower_p", "deco_flower_y", "deco_pebble"},
  },
  path = {sprites = {"ground_path1", "ground_path2"}, edges = "fringe", shadow = C.path_shadow},
  sand = {sprites = {"ground_sand1", "ground_sand2"}, edges = "fringe", shadow = C.sand_shadow, tag = "paddock"},
  carrots = {sprites = {"ground_carrots"}, edges = "fringe", shadow = C.soil_shadow, tag = "carrots"},
  bridge = {sprites = {"ground_bridge"}, shadow = C.wood_shadow},
  water = {frames = {"ground_water1", "ground_water2"}, edges = "bank", solid = true, shadow = C.grass_shadow},
}

-- Zaun: in jedem Feld ein Pfosten, Latten zu jedem Nachbarfeld, das auch Zaun ist.
local function is_fence(map, cx, cy)
  local L = map:legend_at(cx, cy)
  return L and L.prop == "fence"
end

local fence = {
  build = function(map, cx, cy)
    local S, x, y = map.S, cx * Map.TILE, cy * Map.TILE
    local parts = {}
    if is_fence(map, cx - 1, cy) then parts[#parts + 1] = Map.part(S, "fence_rail_e", x, y + 4, true) end
    if is_fence(map, cx + 1, cy) then parts[#parts + 1] = Map.part(S, "fence_rail_e", x + 8, y + 4) end
    if is_fence(map, cx, cy - 1) then parts[#parts + 1] = Map.part(S, "fence_rail_v", x + 6, y - 1) end
    parts[#parts + 1] = Map.part(S, "fence_post", x + 6, y + 3)
    return parts
  end,
  solids_for = function(map, cx, cy)
    local list = {{5, 10, 11, 16}}
    if is_fence(map, cx - 1, cy) then list[#list + 1] = {0, 10, 8, 16} end
    if is_fence(map, cx + 1, cy) then list[#list + 1] = {8, 10, 16, 16} end
    if is_fence(map, cx, cy - 1) then list[#list + 1] = {5, 0, 11, 10} end
    return list
  end,
}

-- solid: Kollision in Pixeln relativ zur Grundfläche (w x h Felder, Standard 1x1).
T.PROPS = {
  tree = {sprite = "tree", solid = {4, 9, 12, 16}},
  bush = {sprite = "bush", solid = {1, 7, 15, 16}},
  rock = {sprite = "rock", solid = {2, 9, 14, 16}},
  hay = {sprite = "hay", solid = {0, 6, 16, 16}},
  stable = {sprite = "stable", w = 4, h = 3, solid = {2, 0, 62, 47}},
  fence = fence,
}

T.LEGEND = {
  ["."] = {ground = "grass"},
  [","] = {ground = "grass", deco = {"deco_flower_p", "deco_flower_y"}},
  [":"] = {ground = "path"},
  ["s"] = {ground = "sand"},
  ["~"] = {ground = "water"},
  ["c"] = {ground = "carrots"},
  ["="] = {ground = "bridge"},
  ["#"] = {ground = "grass", prop = "fence"},
  ["T"] = {ground = "grass", prop = "tree"},
  ["b"] = {ground = "grass", prop = "bush"},
  ["r"] = {ground = "grass", prop = "rock"},
  ["h"] = {ground = "grass", prop = "hay"},
  ["S"] = {ground = "grass", prop = "stable"},
  ["@"] = {ground = "path", spawn = "player"},
}
for i = 1, 9 do
  T.LEGEND[tostring(i)] = {ground = "grass", spawn = "horse", id = i}
end

return T
