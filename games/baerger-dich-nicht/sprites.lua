-- Erzeugt aus sprites.txt.
local img = loadimg('sprites.png')
local rects = {
  bear_red = {0, 0, 15, 15},
  bear_yellow = {15, 0, 15, 15},
  bear_green = {30, 0, 15, 15},
  bear_blue = {45, 0, 15, 15},
}
local S = {img=img, rects=rects}
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
