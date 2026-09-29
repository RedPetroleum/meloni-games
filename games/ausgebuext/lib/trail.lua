-- Spur aus den letzten Positionen einer Figur, damit andere ihr folgen können (Führstrick,
-- Karawane): Wer auf Abstand d folgt, läuft genau den Weg nach, den die Figur gegangen ist.
local Trail = {}
Trail.__index = Trail

local STEP = 2      -- neuer Punkt, wenn sich die Figur so weit bewegt hat
local MAX = 160     -- so viele Punkte (reicht für STEP * MAX Pixel)

function Trail.new(x, y)
  local self = setmetatable({xs = {}, ys = {}, n = 0, head = 0}, Trail)
  self:reset(x, y)
  return self
end

function Trail:reset(x, y)
  self.head, self.n = 1, 1
  self.xs[1], self.ys[1] = x, y
end

function Trail:push(x, y)
  local hx, hy = self.xs[self.head], self.ys[self.head]
  local dx, dy = x - hx, y - hy
  if dx * dx + dy * dy < STEP * STEP then return end
  self.head = self.head % MAX + 1
  self.xs[self.head], self.ys[self.head] = x, y
  if self.n < MAX then self.n = self.n + 1 end
end

-- Punkt, der auf der Spur d Pixel hinter (fx, fy) liegt; fx, fy ist die aktuelle Position.
function Trail:point_at(fx, fy, d)
  local px, py = fx, fy
  local i = self.head
  for _ = 1, self.n do
    local x, y = self.xs[i], self.ys[i]
    local dx, dy = x - px, y - py
    local seg = math.sqrt(dx * dx + dy * dy)
    if seg >= d and seg > 0 then
      local t = d / seg
      return px + dx * t, py + dy * t
    end
    d = d - seg
    px, py = x, y
    i = i - 1
    if i < 1 then i = MAX end
  end
  return px, py
end

return Trail
