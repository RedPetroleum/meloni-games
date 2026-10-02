-- Erzeugt von tools/sprites.py aus sprites.txt, nicht von Hand ändern.
local img = loadimg('sprites.png')
local rects = {
  pl_down1 = {24, 0, 14, 20},
  pl_down2 = {38, 0, 14, 20},
  pl_up1 = {80, 0, 14, 20},
  pl_up2 = {94, 0, 14, 20},
  pl_side1 = {52, 0, 14, 20},
  pl_side2 = {66, 0, 14, 20},
  blatt_1 = {14, 28, 14, 12},
  blatt_2 = {28, 28, 14, 12},
  verbund = {192, 0, 20, 17},
  box = {0, 0, 24, 28},
  coffee = {70, 28, 11, 9},
  shadow = {99, 28, 12, 4},
  shadow_big = {81, 28, 18, 5},
  antrag_1 = {212, 0, 14, 12},
  antrag_2 = {226, 0, 14, 12},
  bescheid_1 = {240, 0, 14, 12},
  bescheid_2 = {0, 28, 14, 12},
  nein_1 = {42, 28, 14, 12},
  nein_2 = {56, 28, 14, 12},
  zap_down1 = {108, 0, 14, 20},
  zap_down2 = {122, 0, 14, 20},
  zap_up1 = {164, 0, 14, 20},
  zap_up2 = {178, 0, 14, 20},
  zap_side1 = {136, 0, 14, 20},
  zap_side2 = {150, 0, 14, 20},
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
