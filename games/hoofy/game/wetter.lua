-- Wetter (Aufgabe D4): Regen an einem Tag aus Seed und Tagesnummer (etwa jeder vierte Tag).
-- Wirkung: Pferde draußen (Weide, frei) verlieren Sauberkeit (KATALOG §2: Regen −15). Bild: Regenlinien.
local K = require("game.katalog")
local U = require("lib.util")

local W = {}

W.CHANCE = 0.25           -- Anteil Regentage
W.COLOR = rgb(0xa8, 0xc8, 0xe8)
W.DROPS = 70

-- Regnet es an diesem Tag? ctx.regen_erzwungen (Szenario) überstimmt.
function W.regnet(ctx, day)
  if ctx.regen_erzwungen ~= nil then return ctx.regen_erzwungen end
  return U.hash(ctx.seed or 1, day, 17) < W.CHANCE
end

-- Sauberkeitsverlust für ein Pferd, das den Regentag draußen stand.
function W.nass(d)
  if d.ort ~= "weide" and d.ort ~= "frei" then return 0 end
  local before = d.sauberkeit
  d.sauberkeit = math.max(0, d.sauberkeit + K.stats.sauberkeit.regen)
  return d.sauberkeit - before
end

-- Zeichnet Regen über den Bildschirm (Frame now): schräge Striche, die fallen.
function W.draw(now)
  for i = 1, W.DROPS do
    local x = (i * 37 + now * 2) % (SCREEN_W + 20) - 10
    local y = (i * 53 + now * 6 + (i % 5) * 11) % (SCREEN_H + 10)
    line(x, y, x - 3, y + 7, W.COLOR)
  end
end

return W
