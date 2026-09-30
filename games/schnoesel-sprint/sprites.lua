-- Erzeugt von tools/sprites.py aus sprites.txt, nicht von Hand ändern.
local img = loadimg('sprites.png')
local rects = {
  snoesel_fat = {0, 0, 46, 56},
  snoesel_mid = {92, 0, 46, 56},
  snoesel_fit = {46, 0, 46, 56},
  dumbbell = {193, 0, 31, 18},
  monster_can = {138, 0, 17, 28},
  burger = {171, 0, 22, 18},
  water = {155, 0, 16, 24},
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
