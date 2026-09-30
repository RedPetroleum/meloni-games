-- Erzeugt von tools/sprites.py aus sprites.txt, nicht von Hand ändern.
local img = loadimg('sprites.png')
local rects = {
  levi_walk1 = {38, 0, 26, 18},
  levi_walk2 = {64, 0, 26, 18},
  levi_jump = {90, 0, 26, 16},
  levi_loaf = {12, 0, 26, 18},
  yrsa_walk1 = {164, 0, 22, 15},
  yrsa_walk2 = {186, 0, 22, 15},
  yrsa_jump = {208, 0, 22, 13},
  yrsa_loaf = {142, 0, 22, 15},
  cup = {14, 28, 11, 8},
  glass = {240, 0, 8, 10},
  vase = {130, 0, 12, 15},
  plant = {116, 0, 14, 15},
  moth1 = {30, 28, 7, 5},
  moth2 = {37, 28, 7, 5},
  human = {0, 0, 12, 28},
  pot = {0, 28, 14, 10},
  plate = {44, 28, 12, 4},
  egg = {25, 28, 5, 6},
  pens = {248, 0, 7, 10},
  frame = {230, 0, 10, 10},
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
