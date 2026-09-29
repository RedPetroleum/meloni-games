-- Erzeugt von tools/sprites.py aus sprites.txt, nicht von Hand ändern.
local img = loadimg('sprites.png')
local rects = {
  horse_run1 = {119, 0, 30, 24},
  horse_run2 = {149, 0, 30, 24},
  horse_kick = {76, 0, 43, 24},
  horse_slide = {32, 68, 42, 14},
  carrot = {83, 68, 9, 11},
  apple = {74, 68, 9, 11},
  fence = {56, 0, 20, 27},
  hay = {198, 0, 20, 18},
  puddle = {0, 68, 32, 15},
  logs = {218, 0, 23, 17},
  crate = {179, 0, 19, 18},
  wall = {0, 0, 19, 68},
  branch = {19, 0, 37, 32},
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
