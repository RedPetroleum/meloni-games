-- Tageswechsel (KATALOG §1/§2): wendet die Tagesregeln auf alle eigenen Pferde an.
local K = require("game.katalog")
local H = require("game.horse_model")
local Care = require("game.care")
local Farm = require("game.farm")

local Days = {}

local function clamp(v, lo, hi) return mid(lo, v, hi) end

-- Regeln eines Tages für ein Pferd. Reihenfolge: Bindung (aus den Zuständen von gestern), Gewicht,
-- Unterbringung, Hunger, Energie, Alter. Gibt eine Tabelle mit den Änderungen zurück.
function Days.horse_day(d)
  local S = K.stats
  local r = {bindung = Care.daily_bond(d)}
  -- Gewicht: Hunger > 70 senkt, zwei Tage Hunger < 10 (überfüttert) erhöht
  local w = d.gewicht
  if d.hunger > S.bindung.hunger_grenze then d.gewicht = d.gewicht + S.gewicht.hunger end   -- −3
  if d.hunger < S.hunger.satt then d.satt_tage = (d.satt_tage or 0) + 1 else d.satt_tage = 0 end
  if d.satt_tage >= S.hunger.satt_tage then d.gewicht = d.gewicht + S.gewicht.ueberfuettert end
  d.gewicht = clamp(d.gewicht, 0, 100)
  r.gewicht = d.gewicht - w
  r.verlust = Farm.daily(d, H)
  -- Hunger steigt
  local inc = d.zug == "verfressen" and S.hunger.pro_tag_verfressen or S.hunger.pro_tag
  d.hunger = clamp(d.hunger + inc, 0, 100)
  -- Energie: zurück auf die Ausdauer (Nachteule morgens −10)
  d.energie = H.stat(d, "ausdauer")
  if d.zug == "nachteule" then d.energie = d.energie + K.charakter.nachteule.morgen_energie end
  -- Alter: Fohlen wachsen in 4 Tagen aus
  if d.alter < 1 then d.alter = min(1, d.alter + 1 / K.zeit.fohlen_tage) end
  if (d.boost or 0) > 0 then d.boost = d.boost - 1 end
  d.gestreichelt = nil
  return r
end

-- Nachteulen bekommen nachts +20 Energie (einmal, bei Einbruch der Nacht).
function Days.dusk(ctx)
  for _, d in ipairs(ctx.herd) do
    if d.zug == "nachteule" then d.energie = d.energie + K.charakter.nachteule.nacht_energie end
  end
end

-- Neuer Tag (day = Nummer): Tagesregeln für alle eigenen Pferde, Wildpferde wechseln.
function Days.new_day(ctx, day)
  local report = {}
  for i, d in ipairs(ctx.herd) do report[i] = Days.horse_day(d) end
  ctx.wild:new_day(day)
  return report
end

return Days
