-- Erzeugt von tools/sprites.py aus sprites.txt, nicht von Hand ändern.
local img = loadimg('sprites.png')
local rects = {
  bunny_down = {36, 0, 16, 16},
  bunny_up = {68, 0, 16, 16},
  bunny_side = {52, 0, 16, 16},
  bunny_dead = {144, 0, 16, 13},
  gnome_walk = {24, 0, 12, 18},
  carrot = {176, 0, 8, 9},
  heart = {192, 0, 7, 7},
  heart_empty = {199, 0, 7, 7},
  chick = {184, 0, 8, 8},
  butterfly1 = {206, 0, 7, 6},
  butterfly2 = {213, 0, 7, 6},
  flower_p = {5, 18, 5, 5},
  flower_y = {10, 18, 5, 5},
  flower_dead = {0, 18, 5, 5},
  feather = {21, 18, 4, 4},
  gib_hat = {15, 18, 6, 5},
  gib_beard = {25, 18, 6, 4},
  gib_boot = {35, 18, 5, 3},
  gib_eye = {31, 18, 4, 4},
  saw_side1 = {220, 0, 16, 6},
  saw_side2 = {236, 0, 16, 6},
  saw_v1 = {132, 0, 6, 16},
  saw_v2 = {138, 0, 6, 16},
  evil_down = {84, 0, 16, 16},
  evil_up = {116, 0, 16, 16},
  evil_side = {100, 0, 16, 16},
  evil_dead = {160, 0, 16, 13},
  flitz_walk = {12, 0, 12, 18},
  brumm_walk = {0, 0, 12, 18},
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
