-- Erzeugt von tools/sprites.py aus sprites.txt, nicht von Hand ändern.
local img = loadimg('sprites.png')
local rects = {
  levi_walk1 = {52, 0, 26, 18},
  levi_walk2 = {78, 0, 26, 18},
  levi_jump = {104, 0, 26, 16},
  levi_loaf = {26, 0, 26, 18},
  yrsa_walk1 = {200, 0, 22, 15},
  yrsa_walk2 = {222, 0, 22, 15},
  yrsa_jump = {0, 38, 22, 13},
  yrsa_loaf = {156, 0, 22, 15},
  human_lady = {14, 0, 12, 34},
  human_guy = {0, 0, 14, 38},
  yrsa_sit = {178, 0, 22, 15},
  cup = {61, 38, 11, 8},
  glass = {32, 38, 8, 10},
  vase = {144, 0, 12, 15},
  plant = {130, 0, 14, 15},
  moth1 = {77, 38, 7, 5},
  moth2 = {84, 38, 7, 5},
  pot = {47, 38, 14, 10},
  plate = {91, 38, 12, 4},
  egg = {72, 38, 5, 6},
  pens = {40, 38, 7, 10},
  frame = {22, 38, 10, 10},
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
