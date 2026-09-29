-- Erzeugt von tools/sprites.py aus sprites.txt, nicht von Hand ändern.
local img = loadimg('sprites.png')
local rects = {
  ground_path1 = {146, 127, 16, 16},
  ground_path2 = {162, 127, 16, 16},
  ground_sand1 = {178, 127, 16, 16},
  ground_sand2 = {194, 127, 16, 16},
  ground_water1 = {210, 127, 16, 16},
  ground_water2 = {226, 127, 16, 16},
  ground_bridge = {114, 127, 16, 16},
  ground_carrots = {130, 127, 16, 16},
  fringe_n = {232, 150, 16, 3},
  fringe_s = {0, 165, 16, 3},
  fringe_w = {111, 127, 3, 16},
  fringe_e = {108, 127, 3, 16},
  bank_n = {174, 150, 16, 6},
  bank_s = {207, 150, 16, 3},
  bank_w = {105, 127, 3, 16},
  bank_e = {102, 127, 3, 16},
  deco_tuft = {223, 150, 5, 3},
  deco_tuft2 = {228, 150, 4, 3},
  deco_flower_p = {201, 150, 3, 4},
  deco_flower_y = {204, 150, 3, 4},
  deco_pebble = {16, 165, 3, 2},
  tree = {64, 0, 32, 39},
  bush = {0, 150, 20, 15},
  rock = {115, 150, 14, 11},
  hay = {20, 150, 16, 14},
  fence_post = {111, 150, 4, 12},
  fence_rail_e = {129, 150, 8, 9},
  fence_rail_v = {197, 150, 4, 5},
  stable = {0, 0, 64, 56},
  player_down = {30, 127, 12, 20},
  player_down_walk = {42, 127, 12, 20},
  player_up = {78, 127, 12, 20},
  player_up_walk = {90, 127, 12, 20},
  player_side = {54, 127, 12, 20},
  player_side_walk = {66, 127, 12, 20},
  horse_side = {30, 104, 30, 23},
  horse_side_walk = {60, 104, 30, 23},
  horse_graze = {0, 104, 30, 23},
  horse_down = {240, 0, 16, 25},
  horse_down_walk = {0, 56, 16, 25},
  horse_up = {176, 56, 16, 24},
  horse_up_walk = {16, 56, 16, 25},
  icon_carrot = {155, 150, 5, 7},
  icon_horse = {137, 150, 9, 8},
  icon_horse_empty = {146, 150, 9, 8},
  icon_sun = {167, 150, 7, 7},
  icon_moon = {160, 150, 7, 7},
  emo_heart = {66, 150, 15, 13},
  emo_bang = {36, 150, 15, 13},
  emo_carrot = {51, 150, 15, 13},
  emo_zzz = {96, 150, 15, 13},
  emo_storm = {81, 150, 15, 13},
  heart = {190, 150, 7, 6},
  fuchs_side = {180, 81, 30, 23},
  fuchs_side_walk = {210, 81, 30, 23},
  fuchs_graze = {150, 81, 30, 23},
  fuchs_down = {192, 0, 16, 25},
  fuchs_down_walk = {208, 0, 16, 25},
  fuchs_up = {160, 56, 16, 24},
  fuchs_up_walk = {224, 0, 16, 25},
  rappe_side = {120, 104, 30, 23},
  rappe_side_walk = {150, 104, 30, 23},
  rappe_graze = {90, 104, 30, 23},
  rappe_down = {32, 56, 16, 25},
  rappe_down_walk = {48, 56, 16, 25},
  rappe_up = {192, 56, 16, 24},
  rappe_up_walk = {64, 56, 16, 25},
  schimmel_side = {210, 104, 30, 23},
  schimmel_side_walk = {0, 127, 30, 23},
  schimmel_graze = {180, 104, 30, 23},
  schimmel_down = {80, 56, 16, 25},
  schimmel_down_walk = {96, 56, 16, 25},
  schimmel_up = {208, 56, 16, 24},
  schimmel_up_walk = {112, 56, 16, 25},
  falbe_side = {90, 81, 30, 23},
  falbe_side_walk = {120, 81, 30, 23},
  falbe_graze = {60, 81, 30, 23},
  falbe_down = {144, 0, 16, 25},
  falbe_down_walk = {160, 0, 16, 25},
  falbe_up = {144, 56, 16, 24},
  falbe_up_walk = {176, 0, 16, 25},
  bunt_side = {0, 81, 30, 23},
  bunt_side_walk = {30, 81, 30, 23},
  bunt_graze = {224, 56, 30, 23},
  bunt_down = {96, 0, 16, 25},
  bunt_down_walk = {112, 0, 16, 25},
  bunt_up = {128, 56, 16, 24},
  bunt_up_walk = {128, 0, 16, 25},
}

local S = {img = img, rects = rects}

-- Zeichnet ein Sprite mit der oberen linken Ecke bei x, y.
function S.draw(name, x, y, flip_x, flip_y)
  local r = rects[name]
  if not r then error('unknown sprite ' .. tostring(name), 2) end
  sspr(img, r[1], r[2], r[3], r[4], x, y, r[3], r[4], flip_x, flip_y)
end

-- Breite und Höhe eines Sprites.
function S.size(name)
  local r = rects[name]
  if not r then error('unknown sprite ' .. tostring(name), 2) end
  return r[3], r[4]
end

return S
