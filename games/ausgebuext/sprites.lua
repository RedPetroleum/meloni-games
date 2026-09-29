-- Erzeugt von tools/sprites.py aus sprites.txt, nicht von Hand ändern.
local img = loadimg('sprites.png')
local rects = {
  ground_path1 = {236, 104, 16, 16},
  ground_path2 = {0, 127, 16, 16},
  ground_sand1 = {16, 127, 16, 16},
  ground_sand2 = {32, 127, 16, 16},
  ground_water1 = {48, 127, 16, 16},
  ground_water2 = {64, 127, 16, 16},
  ground_bridge = {204, 104, 16, 16},
  ground_carrots = {220, 104, 16, 16},
  fringe_n = {42, 143, 16, 3},
  fringe_s = {58, 143, 16, 3},
  fringe_w = {201, 104, 3, 16},
  fringe_e = {198, 104, 3, 16},
  bank_n = {239, 127, 16, 6},
  bank_s = {17, 143, 16, 3},
  bank_w = {195, 104, 3, 16},
  bank_e = {192, 104, 3, 16},
  deco_tuft = {33, 143, 5, 3},
  deco_tuft2 = {38, 143, 4, 3},
  deco_flower_p = {11, 143, 3, 4},
  deco_flower_y = {14, 143, 3, 4},
  deco_pebble = {74, 143, 3, 2},
  tree = {64, 0, 32, 39},
  bush = {80, 127, 20, 15},
  rock = {180, 127, 14, 11},
  hay = {100, 127, 16, 14},
  fence_post = {176, 127, 4, 12},
  fence_rail_e = {194, 127, 8, 9},
  fence_rail_v = {7, 143, 4, 5},
  stable = {0, 0, 64, 56},
  player_down = {120, 104, 12, 20},
  player_down_walk = {132, 104, 12, 20},
  player_up = {168, 104, 12, 20},
  player_up_walk = {180, 104, 12, 20},
  player_side = {144, 104, 12, 20},
  player_side_walk = {156, 104, 12, 20},
  horse_side = {120, 81, 30, 23},
  horse_side_walk = {150, 81, 30, 23},
  horse_graze = {90, 81, 30, 23},
  horse_down = {192, 0, 16, 25},
  horse_down_walk = {208, 0, 16, 25},
  horse_up = {112, 56, 16, 24},
  horse_up_walk = {224, 0, 16, 25},
  icon_carrot = {220, 127, 5, 7},
  icon_horse = {202, 127, 9, 8},
  icon_horse_empty = {211, 127, 9, 8},
  icon_sun = {232, 127, 7, 7},
  icon_moon = {225, 127, 7, 7},
  emo_heart = {146, 127, 15, 13},
  emo_bang = {116, 127, 15, 13},
  emo_carrot = {131, 127, 15, 13},
  emo_zzz = {161, 127, 15, 13},
  heart = {0, 143, 7, 6},
  fuchs_side = {30, 81, 30, 23},
  fuchs_side_walk = {60, 81, 30, 23},
  fuchs_graze = {0, 81, 30, 23},
  fuchs_down = {144, 0, 16, 25},
  fuchs_down_walk = {160, 0, 16, 25},
  fuchs_up = {96, 56, 16, 24},
  fuchs_up_walk = {176, 0, 16, 25},
  rappe_side = {210, 81, 30, 23},
  rappe_side_walk = {0, 104, 30, 23},
  rappe_graze = {180, 81, 30, 23},
  rappe_down = {240, 0, 16, 25},
  rappe_down_walk = {0, 56, 16, 25},
  rappe_up = {128, 56, 16, 24},
  rappe_up_walk = {16, 56, 16, 25},
  schimmel_side = {60, 104, 30, 23},
  schimmel_side_walk = {90, 104, 30, 23},
  schimmel_graze = {30, 104, 30, 23},
  schimmel_down = {32, 56, 16, 25},
  schimmel_down_walk = {48, 56, 16, 25},
  schimmel_up = {144, 56, 16, 24},
  schimmel_up_walk = {64, 56, 16, 25},
  falbe_side = {190, 56, 30, 23},
  falbe_side_walk = {220, 56, 30, 23},
  falbe_graze = {160, 56, 30, 23},
  falbe_down = {96, 0, 16, 25},
  falbe_down_walk = {112, 0, 16, 25},
  falbe_up = {80, 56, 16, 24},
  falbe_up_walk = {128, 0, 16, 25},
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
