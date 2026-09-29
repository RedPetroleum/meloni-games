-- Alles, was auf der Karte steht oder läuft: feste Requisiten und bewegliche Figuren.
-- Gezeichnet wird nach der Fußlinie sortiert (3/4-Ansicht: weiter unten heißt weiter vorne).
-- Requisiten liegen in Blöcken (CHUNK Pixel), damit auch große Karten nur das Sichtbare anfassen.
--
-- Eine Figur ist eine Tabelle mit x, y (Fußpunkt) und optional:
--   e:update(world)     jeden Frame
--   e:draw()            in der Tiefenreihenfolge
--   e:draw_shadow()     vor allen Figuren (Schatten liegen auf dem Boden)
--   e:draw_over()       nach allen Figuren (Sprechblasen, Namen)
--   e.dead = true       wird am Ende des Frames entfernt
--   e.reach             wie weit das Bild vom Fußpunkt absteht (Sichtbarkeit), Standard 32
local World = {}
World.__index = World

local CHUNK = 128

function World.new(map)
  local self = setmetatable({}, World)
  self.map = map
  self.entities = {}
  self.chunks = {}
  self.cw = (map.pw + CHUNK - 1) // CHUNK
  self.visible = {}
  for _, p in ipairs(map.props) do self:add_static(p) end
  return self
end

-- Feste Requisite mit Zeichenteilen (siehe Tilemap:place_prop), sortiert nach p.y.
function World:add_static(p)
  local cx0, cy0 = max(0, p.x0 // CHUNK), max(0, p.y0 // CHUNK)
  local cx1, cy1 = (p.x1 - 1) // CHUNK, (p.y1 - 1) // CHUNK
  for cy = cy0, cy1 do
    for cx = cx0, min(self.cw - 1, cx1) do
      local k = cy * self.cw + cx + 1
      local list = self.chunks[k]
      if not list then list = {}; self.chunks[k] = list end
      list[#list + 1] = p
    end
  end
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

-- Zeichnet alles Sichtbare; die Kamera ist schon gesetzt (camera(cam_x, cam_y)).
function World:draw(cam_x, cam_y, view_w, view_h)
  local vis, n = self.visible, 0
  local vx1, vy1 = cam_x + view_w, cam_y + view_h
  local seen = self.seen or {}
  self.seen = seen
  local stamp = (self.stamp or 0) + 1
  self.stamp = stamp
  for cy = max(0, cam_y // CHUNK), (vy1 - 1) // CHUNK do
    for cx = max(0, cam_x // CHUNK), min(self.cw - 1, (vx1 - 1) // CHUNK) do
      local list = self.chunks[cy * self.cw + cx + 1]
      if list then
        for k = 1, #list do
          local p = list[k]
          if seen[p] ~= stamp and p.x1 > cam_x and p.x0 < vx1 and p.y1 > cam_y and p.y0 < vy1 then
            seen[p] = stamp
            n = n + 1
            vis[n] = p
          end
        end
      end
    end
  end
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
    elseif o.draw then
      o:draw()
    end
  end
  for i = 1, n do
    local o = vis[i]
    if o.draw_over then o:draw_over() end
  end
end

return World
