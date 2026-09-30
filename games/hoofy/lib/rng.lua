-- Eigener Zufall aus einem Seed (xorshift32), unabhängig von rnd(): Karten sehen aus demselben
-- Seed immer gleich aus, egal was das Spiel sonst würfelt. Rechnet auf der Konsole (32-Bit-Zahlen)
-- und am Rechner (64 Bit) gleich.
local U = require("lib.util")

local Rng = {}
Rng.__index = Rng

local MASK = 0xffffffff

function Rng.new(seed)
  local s = (seed * 0x9E3779B1 + 1013904223) & MASK
  if s == 0 then s = 1 end
  return setmetatable({s = s}, Rng)
end

-- 0 <= r < 1
function Rng:next()
  local s = self.s
  s = (s ~ (s << 13)) & MASK
  s = s ~ (s >> 17)
  s = (s ~ (s << 5)) & MASK
  self.s = s
  return (s >> 8) / 16777216
end

-- ganze Zahl lo..hi
function Rng:int(lo, hi)
  return lo + flr(self:next() * (hi - lo + 1))
end

function Rng:pick(list)
  return list[1 + flr(self:next() * #list)]
end

-- Glattes Rauschen 0..1 (Wertrauschen, bilinear zwischen Gitterpunkten im Abstand scale).
function Rng.noise(x, y, scale, seed)
  local fx, fy = x / scale, y / scale
  local x0, y0 = flr(fx), flr(fy)
  local tx, ty = fx - x0, fy - y0
  tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
  local a = U.hash(x0, y0, seed)
  local b = U.hash(x0 + 1, y0, seed)
  local c = U.hash(x0, y0 + 1, seed)
  local d = U.hash(x0 + 1, y0 + 1, seed)
  local top = a + (b - a) * tx
  local bottom = c + (d - c) * tx
  return top + (bottom - top) * ty
end

return Rng
