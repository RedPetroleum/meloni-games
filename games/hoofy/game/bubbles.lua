-- Sprechblasen über Pferden (E10, E11): höchstens eine, die wichtigste zuerst.
-- 👃 Schatz > 😱 Angst > Hunger > schmutzig > müde > Charakter (gelegentlich) > ❤ nach Streicheln.
local K = require("game.katalog")
local U = require("lib.util")

local B = {}

-- Charakterzug → Blase
local TRAIT = {
  verfressen = "emo_apple", schreckhaft = "emo_storm", faul = "emo_zzz", eitel = "emo_sparkle",
  nachteule = "emo_moon",
}

-- Schwellen (E11) kommen aus dem Katalog: Hunger „zu hoch“, Sauberkeit „schmutzig“, Energie 15.
B.HUNGER = K.stats.bindung.hunger_grenze - 10      -- 60
B.DIRTY = K.stats.sauberkeit.schmutzig + 10        -- 40
B.TIRED = 15

-- Charakter-Blase: alle 12 s für 2 s, je Pferd um einen festen Wert verschoben.
local function trait_phase(h, now)
  local shift = flr(U.hash(#(h.data.name or ""), h.data.gen.tempo, 5) * 720)
  return (now + shift) % 720 < 120
end

-- h: Pferd mit h.data (horse_model) und optional h.schatz, h.scared, h.react_emo/h.react_until (Reaktion auf
-- Pflege: Herz, Glitzer, Ärger), h.heart_t. now: Frames.
-- Gibt den Sprite-Namen der Blase oder nil zurück.
function B.choose(h, now)
  local d = h.data
  if h.schatz then return "emo_nose" end
  if h.react_emo and (h.react_until or 0) > now then return h.react_emo end
  if h.scared then return "emo_storm" end
  if d.hunger > B.HUNGER then return "emo_carrot" end
  if d.sauberkeit < B.DIRTY then return "emo_dirty" end
  if d.energie < B.TIRED then return "emo_zzz" end
  if (h.force_trait or trait_phase(h, now)) and TRAIT[d.zug] then return TRAIT[d.zug] end
  if (h.heart_t or 0) > 0 and d.bindung >= K.stats.bindung.folgt then return "emo_heart" end
  return nil
end

-- Zeichnet die Blase über dem Kopf; wippt leicht.
function B.draw(S, sprite, x, y, now)
  S.draw(sprite, flr(x) - 7, flr(y) - 1 - ((now // 20) % 2))
end

return B
