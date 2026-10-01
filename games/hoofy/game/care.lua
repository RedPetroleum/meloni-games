-- Pflege und Training (KATALOG §2 Zustände/Training, §5 Charakter, §7 Futter): reine Regeln auf
-- den Pferdedaten, ohne Grafik. Tageswechsel (A12) ruft Care.daily_bond auf.
local K = require("game.katalog")
local H = require("game.horse_model")

local Care = {}

local function clamp(v, lo, hi) return mid(lo, v, hi) end

-- Gewicht: Abweichung > 15 von 50 senkt Tempo und Stärke um 1 % je Punkt darüber (KATALOG §2).
function Care.weight_factor(data)
  local g = K.stats.gewicht
  local over = abs((data.gewicht or g.start) - g.start) - g.toleranz
  if over <= 0 then return 1 end
  return max(0, 1 - over * g.malus_prozent / 100)
end

-- Wirksamer Wert für Tempo/Stärke (mit Gewichtsmalus), sonst der Gesamtwert.
function Care.effective(data, key)
  local v = H.stat(data, key)
  if key == "tempo" or key == "staerke" then v = v * Care.weight_factor(data) end
  return v
end

-- Bonus aus Sauberkeit und Bindung auf den Trainingszuwachs (bis ×1,5). Eitel: Sauberkeit doppelt.
function Care.training_bonus(data)
  local c = data.sauberkeit / 100 * 0.25
  if data.zug == "eitel" then c = c * K.charakter.eitel.sauberkeit_faktor end
  return min(K.stats.training_bonus_max, 1 + c + data.bindung / 100 * 0.25)
end

-- Trainingszuwachs = Basis × (1 − Gesamt / Max-Potenzial) × Bonus (faul −20 %, Drachenfrucht ×2).
function Care.training_gain(data, key, base)
  local total, pot = H.stat(data, key), data.pot[key]
  if pot <= 0 then return 0 end
  local gain = base * max(0, 1 - total / pot) * Care.training_bonus(data)
  if data.zug == "faul" then gain = gain * (1 - K.charakter.faul.training_malus / 100) end
  if (data.boost or 0) > 0 then gain = gain * 2 end
  return gain
end

-- Trainiert: erhöht data.train[key], begrenzt durch das Max-Potenzial. Gibt den Zuwachs zurück.
function Care.train(data, key, base)
  local gain = Care.training_gain(data, key, base)
  local room = data.pot[key] - H.stat(data, key)
  gain = min(gain, max(0, room))
  data.train[key] = data.train[key] + gain
  return gain
end

-- Streicheln: Bindung +2, aber nur einmal pro Tag (data.gestreichelt, A12 setzt es zurück).
function Care.stroke(data)
  if data.gestreichelt then return 0 end
  data.gestreichelt = true
  local add = K.stats.bindung.streicheln
  data.bindung = clamp(data.bindung + add, 0, 100)
  return add
end

-- Füttern mit Futter id: gekauftes (heu, hafer, karotte, premiumfutter; KATALOG §7) oder Ernte
-- (apfel, sonnenblumenkerne, minze, zuckerruebe, luzerne, drachenfrucht, goldene_karotte).
-- Bindung +1 je Fütterung. Gibt Namen und Bindungsänderung zurück.
local CROP_OF = {apfel = "apfelbaum", sonnenblumenkerne = "sonnenblume", minze = "minze", zuckerruebe = "zuckerruebe",
  luzerne = "luzerne", drachenfrucht = "drachenfrucht", goldene_karotte = "goldene_karotte"}

function Care.feed(data, id)
  local item
  for _, f in ipairs(K.futter.kaufen) do if f.id == id then item = f end end
  local crop
  if not item and CROP_OF[id] then
    for _, p in ipairs(K.futter.anbau) do if p.id == CROP_OF[id] then crop = p end end
  end
  if not item and not crop then error("unbekanntes Futter " .. tostring(id)) end
  local src = item or crop
  local w = src.wirkung
  local bond = K.stats.bindung.fuettern + (w.bindung or 0)
  -- Minze: Bindung ×2 bei eitel
  if crop and crop.eitel_faktor and data.zug == "eitel" then bond = K.stats.bindung.fuettern + (w.bindung or 0) * crop.eitel_faktor end
  data.hunger = clamp(data.hunger + (w.hunger or 0), 0, 100)
  if w.energie then data.energie = min(H.stat(data, "ausdauer"), data.energie + w.energie) end
  if w.sauberkeit then data.sauberkeit = clamp(data.sauberkeit + w.sauberkeit, 0, 100) end
  if w.gewicht then data.gewicht = clamp(data.gewicht + w.gewicht, 0, 100) end
  data.bindung = clamp(data.bindung + bond, 0, 100)
  -- Drachenfrucht: Training ×2 für einen Tag
  if crop and crop.training_faktor then data.boost = 1 end
  local pot_add = src.fohlen_potenzial
  local pot_max = src.fohlen_potenzial_max or 10
  if pot_add and data.alter < 1 then
    local room = pot_max - (data.pot_bonus or 0)
    local add = min(pot_add, max(0, room))
    if add > 0 then
      data.pot_bonus = (data.pot_bonus or 0) + add
      for _, key in ipairs(H.STATS) do data.pot[key] = min(K.stats.potenzial_max, data.pot[key] + add) end
    end
  end
  return src.name, bond
end

-- Striegeln (braucht die Bürste): Sauberkeit +40, Bindung +1.
function Care.brush(data)
  local add = K.futter.kaufen[5].wirkung.sauberkeit
  data.sauberkeit = clamp(data.sauberkeit + add, 0, 100)
  data.bindung = clamp(data.bindung + 1, 0, 100)
  return add
end

-- Bindungsänderung eines Tages aus Zuständen (KATALOG §2): −3 bei Hunger > 70, −2 bei
-- Sauberkeit < 30 (eitel doppelt). Gibt die Änderung zurück und wendet sie an.
function Care.daily_bond(data)
  local b, delta = K.stats.bindung, 0
  if data.hunger > b.hunger_grenze then delta = delta - b.hunger_malus end
  if data.sauberkeit < b.schmutz_grenze then
    delta = delta - b.schmutz_malus * (data.zug == "eitel" and K.charakter.eitel.sauberkeit_faktor or 1)
  end
  data.bindung = clamp(data.bindung + delta, 0, 100)
  return delta
end

-- Lose Hinweise für Bildschirme: Hunger, Gewicht und Sauberkeit in Worten.
function Care.describe(data)
  local t = {}
  t[#t + 1] = data.hunger > 60 and "hungrig" or data.hunger < 10 and "sehr satt" or "satt genug"
  t[#t + 1] = data.sauberkeit < 40 and "schmutzig" or "sauber"
  local g = data.gewicht - 50
  if g > 15 then t[#t + 1] = "zu dick" elseif g < -15 then t[#t + 1] = "zu dünn" end
  return table.concat(t, ", ")
end

return Care
