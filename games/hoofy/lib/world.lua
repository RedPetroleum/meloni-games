-- Alles, was auf der Karte steht oder läuft: feste Requisiten (aus der Karte) und bewegliche Figuren.
-- Gezeichnet wird nach der Fußlinie sortiert (3/4-Ansicht: weiter unten heißt weiter vorne).
-- Requisiten liefert die Karte blockweise (Tilemap:props_in), so fasst auch eine große Karte nur
-- das Sichtbare an.
--
-- Eine Figur ist eine Tabelle mit x, y (Fußpunkt) und optional:
--   e:update(world)     jeden Frame
--   e:draw()            in der Tiefenreihenfolge
--   e:draw_shadow()     vor allen Figuren (Schatten liegen auf dem Boden)
--   e:draw_over()       nach allen Figuren (Sprechblasen, Namen)
--   e:xray_box(), e:draw_xray()   verdeckt etwas davor gezeichnetes Bild den Kasten x0, y0, x1, y1,
--                       wird draw_xray nach allem gezeichnet (Umriss der Spielfigur hinter Bäumen)
--   e.dead = true       wird am Ende des Frames entfernt
--   e.reach             wie weit das Bild vom Fußpunkt absteht (Sichtbarkeit), Standard 32
local World = {}
World.__index = World

function World.new(map)
  local self = setmetatable({}, World)
  self.map = map
  self.entities = {}
  self.visible = {}
  return self
end

function World:add(e)
  self.entities[#self.entities + 1] = e
  return e
end

function World:update()
  local list = self.entities
  for i = 1, #list do
    local e = list[i]
    if e.update and not e.dead then e:update(self) end
  end
  local j = 1
  for i = 1, #list do
    local e = list[i]
    if not e.dead then list[j] = e; j = j + 1 end
  end
  for i = j, #list do list[i] = nil end
end

-- Alle Figuren, für die filter(e) wahr ist, nach Abstand zu x, y (höchstens r).
function World:nearest(x, y, r, filter)
  local best, best_d = nil, r
  for _, e in ipairs(self.entities) do
    if not e.dead and (not filter or filter(e)) then
      local dx, dy = e.x - x, e.y - y
      local d = math.sqrt(dx * dx + dy * dy)
      if d <= best_d then best, best_d = e, d end
    end
  end
  return best, best_d
end

local function by_depth(a, b)
  if a.y ~= b.y then return a.y < b.y end
  return a.x < b.x
end

-- Liegt ein nach vis[i] gezeichnetes Bild über dem Kasten von e?
function World:covered(e, i, n)
  local x0, y0, x1, y1 = e:xray_box()
  local vis = self.visible
  for j = i + 1, n do
    local o = vis[j]
    local ox0, oy0, ox1, oy1
    if o[1] then
      ox0, oy0 = o[5], o[6]
      ox1, oy1 = ox0 + o[3], oy0 + o[4]
    elseif o.parts then
      ox0, oy0, ox1, oy1 = o.x0, o.y0, o.x1, o.y1
    end
    if ox0 and ox1 > x0 + 2 and ox0 < x1 - 2 and oy1 > y0 + 2 and oy0 < y1 - 2 then return true end
  end
  return false
end

-- Zeichnet alles Sichtbare; die Kamera ist schon gesetzt (camera(cam_x, cam_y)).
function World:draw(cam_x, cam_y, view_w, view_h)
  local vis = self.visible
  local vx1, vy1 = cam_x + view_w, cam_y + view_h
  local n = self.map:props_in(cam_x, cam_y, vx1, vy1, vis, 0)
  for _, e in ipairs(self.entities) do
    local r = e.reach or 32
    if e.x + r > cam_x and e.x - r < vx1 and e.y + r > cam_y and e.y - r * 2 < vy1 then
      if e.draw_shadow then e:draw_shadow() end
      n = n + 1
      vis[n] = e
    end
  end
  for i = n + 1, #vis do vis[i] = nil end
  table.sort(vis, by_depth)
  local img = self.map.img
  for i = 1, n do
    local o = vis[i]
    if o.parts then
      local parts = o.parts
      for k = 1, #parts do
        local p = parts[k]
        sspr(img, p[1], p[2], p[3], p[4], p[5], p[6], p[3], p[4], p[7])
      end
    elseif o[1] then
      sspr(img, o[1], o[2], o[3], o[4], o[5], o[6], o[3], o[4], o[7])
    elseif o.draw then
      o:draw()
    end
  end
  for i = 1, n do
    local o = vis[i]
    if o.draw_xray and self:covered(o, i, n) then o:draw_xray() end
    if o.draw_over then o:draw_over() end
  end
end

return World
