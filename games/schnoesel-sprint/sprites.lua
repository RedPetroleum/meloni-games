-- Erzeugt von tools/sprites.py aus sprites.txt, nicht von Hand ändern.
local img = loadimg('sprites.png')
local rects = {
  snoesel_fat = {0, 0, 25, 28},
  snoesel_mid = {25, 0, 25, 27},
  snoesel_fit = {50, 0, 25, 25},
  dumbbell = {121, 0, 20, 8},
  monster_can = {75, 0, 17, 15},
  burger = {105, 0, 16, 13},
  water = {92, 0, 13, 14},
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
