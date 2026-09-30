-- Erzeugt von tools/sprites.py aus sprites.txt, nicht von Hand ändern.
local img = loadimg('sprites.png')
local rects = {
  rider = {0, 64, 30, 22},
  rider_l = {60, 64, 30, 22},
  rider_r = {122, 64, 30, 22},
  rider_front = {30, 64, 30, 22},
  rider_nohand = {90, 64, 32, 22},
  deck = {0, 103, 30, 8},
  deck_side = {168, 86, 32, 9},
  car_rear = {0, 86, 32, 17},
  police1 = {152, 64, 32, 20},
  police2 = {184, 64, 32, 20},
  bus = {191, 0, 40, 23},
  ramp = {200, 86, 40, 9},
  cone = {160, 86, 8, 9},
  lamp = {144, 0, 12, 44},
  tree = {168, 0, 23, 25},
  house_a = {104, 0, 40, 56},
  house_b = {32, 0, 32, 64},
  charger = {156, 0, 12, 27},
  blue_rear = {216, 64, 32, 17},
  taxi_rear = {64, 86, 32, 17},
  white_rear = {128, 86, 32, 17},
  green_rear = {32, 86, 32, 17},
  violet_rear = {96, 86, 32, 17},
  b_a = {64, 0, 40, 56},
  b_b = {0, 0, 32, 64},
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
