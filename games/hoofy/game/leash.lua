-- Leine und Folgen (KATALOG §2 Leine, §2 Bindung): Ausreißen, Führen, freies Folgen, Pfiff.
local K = require("game.katalog")
local Trail = require("lib.trail")

local L = {}

local LEINE = K.stats.leine
L.FOLLOW = K.stats.bindung.folgt     -- ab hier folgt das Pferd ohne Leine
L.WHISTLE = K.stats.bindung.pfiff    -- ab hier kommt es auf Pfiff
L.SPEED = 2.4                        -- so schnell holt ein geführtes Pferd höchstens auf
L.WHISTLE_FRAMES = 30                -- A so lange halten ohne Pferd in Reichweite (E29)

-- Ausreiß-Chance je 10 s: (100 − Bindung) / 10 %, sprinten ×2, reiten ×3, schreckhaft ×1,5.
-- mode: "gehen", "sprinten" oder "reiten".
function L.chance10(bindung, mode, zug)
  local p = (100 - bindung) / LEINE.teiler / 100
  if mode == "sprinten" then p = p * LEINE.sprinten end
  if mode == "reiten" then p = p * LEINE.reiten end
  if zug == "schreckhaft" then p = p * K.charakter.schreckhaft.ausreiss_faktor end
  return min(1, p)
end

-- Würfel einmal pro Sekunde: entspricht einer Chance von chance10 je LEINE.sek Sekunden.
-- rng: Tabelle mit :next() oder nil (dann rnd()).
function L.escape_roll(bindung, mode, zug, rng)
  local p10 = L.chance10(bindung, mode, zug)
  local p1 = 1 - (1 - p10) ^ (1 / LEINE.sek)
  local r = rng and rng:next() or rnd()
  return r < p1
end

-- Abstand, den das Pferd als Nr. i (1-basiert) in der Karawane hält.
function L.lead_dist(i)
  return 16 + i * 20
end

return L
