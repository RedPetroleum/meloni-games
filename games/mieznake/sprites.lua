-- Erzeugt von tools/sprites.py aus sprites.txt, nicht von Hand ändern.
local img = loadimg('sprites.png')
local rects = {
  cat_head_r = {0, 0, 20, 16},
  cat_head_u = {20, 0, 20, 16},
  cat_head_d = {40, 0, 20, 16},
  cat_body1 = {60, 0, 21, 11},
  cat_body2 = {81, 0, 21, 11},
  cat_tail = {102, 0, 21, 12},
  treat = {123, 0, 12, 11},
}
local S = {img = img, rects = rects}
function S.draw(name,x,y,flip_x,flip_y)
  local r=rects[name]
  if not r then error('unknown sprite '..tostring(name),2) end
  sspr(img,r[1],r[2],r[3],r[4],x,y,r[3],r[4],flip_x,flip_y)
end
function S.size(name)
  local r=rects[name]
  if not r then error('unknown sprite '..tostring(name),2) end
  return r[3],r[4]
end
return S
