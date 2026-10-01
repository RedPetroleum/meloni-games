-- Tageswechsel (KATALOG §1/§2): wendet die Tagesregeln auf alle eigenen Pferde an.
local K = require("game.katalog")
local H = require("game.horse_model")
local Care = require("game.care")
local Farm = require("game.farm")
local Breeding = require("game.breeding")

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
  -- Göpel: Energie und Stärke zählen vor dem Tageswechsel
  local lauf, je = Farm.goepel_pferde(ctx.hof or ctx.area.farm, ctx.herd, H)
  ctx.goepel_geld = #lauf * je * (ctx.goepel_mult or 1)
  ctx.money = ctx.money + ctx.goepel_geld
  for i, d in ipairs(ctx.herd) do report[i] = Days.horse_day(d) end
  -- Stall: der beste Stall gibt allen Pferden im Stall Bindung (KATALOG §9)
  local bonus = Farm.stall_bonus(ctx.hof or ctx.area.farm)
  if bonus > 0 then
    for _, d in ipairs(ctx.herd) do
      if d.ort == "stall" then d.bindung = mid(0, d.bindung + bonus, 100) end
    end
  end
  -- Hof-Schönheit: alle Pferde bekommen Bindung (ab 50 / 150 / 400 Punkten +1 / +2 / +3)
  local schoen = Farm.schoenheit_bonus(ctx.hof or ctx.area.farm)
  if schoen > 0 then
    for _, d in ipairs(ctx.herd) do d.bindung = mid(0, d.bindung + schoen, 100) end
  end
  local reif = Farm.grow(ctx, day)
  ctx.reife = reif
  ctx.wild:new_day(day)
  -- Fohlen kommen zur Welt und folgen dem Spieler (oder stehen lose, wenn die Leine voll ist)
  local born = Breeding.tick(ctx, day)
  ctx.geburten = {}
  for _, b in ipairs(born) do
    ctx.wild:adopt(b.foal)
    ctx.geburten[#ctx.geburten + 1] = b.foal.name .. " (Fohlen von " .. b.mutter.name .. ")"
  end
  return report
end

return Days
