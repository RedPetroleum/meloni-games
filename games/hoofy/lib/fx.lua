-- Kurzlebige Effekte in der Welt (Herzchen, Staub): steigen auf, verschwinden nach life Frames.
local FX = {}
FX.__index = FX

function FX.new(S)
  return setmetatable({S = S, list = {}}, FX)
end

-- sprite: Name aus sprites.txt oder nil für einen Punkt in color. opts.ground: liegt am Boden und wird
-- vor den Figuren gezeichnet (Staub), sonst danach (Herzchen).
function FX:spawn(x, y, opts)
  local p = {
    x = x, y = y, vx = opts.vx or 0, vy = opts.vy or -0.4,
    life = opts.life or 40, sprite = opts.sprite, color = opts.color, ground = opts.ground or false,
  }
  self.list[#self.list + 1] = p
end

function FX:update()
  local list, j = self.list, 1
  for i = 1, #list do
    local p = list[i]
    p.x, p.y = p.x + p.vx, p.y + p.vy
    p.life = p.life - 1
    if p.life > 0 then list[j] = p; j = j + 1 end
  end
  for i = j, #list do list[i] = nil end
end

-- ground: true zeichnet nur die Bodeneffekte, sonst nur die übrigen.
function FX:draw(ground)
  ground = ground or false
  for _, p in ipairs(self.list) do
    if p.ground ~= ground then
    elseif p.sprite then
      local w, h = self.S.size(p.sprite)
      self.S.draw(p.sprite, flr(p.x - w / 2), flr(p.y - h / 2))
    else
      pset(p.x, p.y, p.color)
    end
  end
end

return FX
