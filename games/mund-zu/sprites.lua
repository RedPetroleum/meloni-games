-- Erzeugt von tools/sprites.py aus sprites.txt, nicht von Hand ändern.
local img = loadimg('sprites.png')
local rects = {
  head = {0, 0, 24, 30},
  m_open = {118, 0, 8, 5},
  m_talk = {134, 0, 8, 5},
  m_shut = {126, 0, 8, 5},
  m_gasp = {82, 0, 10, 7},
  m_blow = {104, 0, 6, 5},
  m_cough = {110, 0, 8, 5},
  eyes_shut = {142, 0, 14, 3},
  mask = {60, 0, 16, 9},
  p_mask = {92, 0, 12, 7},
  p_sauger = {24, 0, 14, 14},
  p_part = {48, 0, 12, 11},
  p_paper = {38, 0, 10, 12},
  life = {76, 0, 6, 7},
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
