-- Erzeugt von tools/sprites.py aus sprites.txt, nicht von Hand ändern.
local img = loadimg('sprites.png')
local rects = {
  snoesel_fat_down = {135, 0, 47, 70},
  snoesel_fat_mid = {182, 0, 47, 70},
  snoesel_fat_up = {0, 70, 47, 70},
  snoesel_chubby_down = {0, 0, 45, 70},
  snoesel_chubby_mid = {45, 0, 45, 70},
  snoesel_chubby_up = {90, 0, 45, 70},
  snoesel_sporty_down = {50, 140, 46, 70},
  snoesel_sporty_mid = {96, 140, 47, 70},
  snoesel_sporty_up = {143, 140, 46, 70},
  snoesel_muscle_down = {47, 70, 50, 70},
  snoesel_muscle_mid = {158, 70, 51, 70},
  snoesel_muscle_up = {0, 140, 50, 70},
  snoesel_muscle_flex = {97, 70, 61, 70},
  fist = {206, 140, 8, 7},
  monster_can = {189, 140, 17, 28},
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
