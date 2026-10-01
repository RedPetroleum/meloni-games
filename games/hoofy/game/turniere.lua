-- Turniere (Aufgabe E1, KATALOG §13): sechs Klassen nach Fahrzeug, drei Wettbewerbe je Klasse. Teilnahme kostet
-- Startgebühr, danach ist der Wettbewerb bis zur nächsten Runde (alle 3 Tage) für alle Pferde weg.
-- Wertung = Stat-Anteil × (0,5 + Bindung / 200). Die Minispiele (E2/E3) liefern später ihre eigene Punktzahl
-- über `punkte`; ohne sie wird aus den Werten gerechnet.
local K = require("game.katalog")
local H = require("game.horse_model")
local Care = require("game.care")
local Economy = require("game.economy")
local Rng = require("lib.rng")

local T = {}

T.GEGNER = 5                 -- Teilnehmer außer dem eigenen Pferd
T.STREUUNG = 0.10            -- Tagesform ± 10 % (eigenes Pferd und Gegner)
T.SIM = 200                  -- Läufe für die angezeigten Chancen

function T.runde(day) return (day - 1) // K.turniere.rotation_tage end

-- Zustand: Runde und Menge der verbrauchten Wettbewerbe ("klasse:wettbewerb"). Neue Runde: alles offen.
function T.state(ctx, day)
  local r = T.runde(day)
  if not ctx.turnier or ctx.turnier.runde ~= r then ctx.turnier = {runde = r, weg = {}} end
  return ctx.turnier
end

-- Klassen, die man mit dem Fahrzeug im Besitz mitmachen darf (Dorf immer).
function T.klassen(ctx)
  local reach = Economy.fahrzeug(ctx).gebiete
  local out = {}
  for i, k in ipairs(K.turniere.klassen) do
    local need = 1
    for _, f in ipairs(K.welt.fahrzeuge) do if f.id == k.fahrzeug then need = f.gebiete end end
    if need <= reach then out[#out + 1] = {index = i, def = k} end
  end
  return out
end

-- Seltenheit 0–100 aus Farbstufe (60 %) und frühestem Gebiet der Rasse (40 %).
function T.seltenheit(d)
  local n = #K.farben.stufen
  local stufe = K.farbe(d.farbe).stufe
  return (stufe - 1) / (n - 1) * 60 + (K.rasse(d.rasse).gebiet - 1) / 5 * 40
end

-- Punktzahl der Fähigkeit des Pferds im Wettbewerb (0–100), ohne Bindungsfaktor.
function T.fach(d, wb)
  local eff = function(k) return Care.effective(d, k) end
  if wb == "schoenheitswettbewerb" then
    return T.seltenheit(d) * 0.4 + d.sauberkeit * 0.3 + math.min(100, Economy.schoenheit(d)) * 0.3
  elseif wb == "springreiten" then
    return (eff("staerke") + eff("ausdauer")) / 2
  end
  return (eff("tempo") + eff("ausdauer")) / 2
end

function T.wertung(d, wb)
  return T.fach(d, wb) * (K.turniere.wertung_basis + d.bindung / K.turniere.wertung_teiler)
end

local function wb_index(wb)
  for i, w in ipairs(K.turniere.wettbewerbe) do if w.id == wb then return i end end
  error("unbekannter Wettbewerb " .. tostring(wb))
end

-- Stärke der Gegner einer Klasse in dieser Runde: Mittel 10 + 10 × Klasse, je Gegner ± 12.
function T.gegner(ctx, klasse, wb, runde)
  local R = Rng.new((ctx.seed or 1) * 31 + runde * 1009 + klasse * 37 + wb_index(wb))
  local out = {}
  for i = 1, T.GEGNER do out[i] = 10 + 10 * klasse + R:int(-12, 12) end
  return out
end

-- Platz (1 = Sieger) des eigenen Werts gegen die Gegner mit Tagesform aus R.
local function platz(own, gegner, R)
  local function form(v) return v * (1 + (R:next() - 0.5) * 2 * T.STREUUNG) end
  local mine, rank = form(own), 1
  for _, g in ipairs(gegner) do if form(g) > mine then rank = rank + 1 end end
  return rank
end

-- Chancen in Prozent {sieg, podest} für Pferd d (Wertung aus den Werten oder `punkte`).
function T.chancen(ctx, d, klasse, wb, runde, punkte)
  local own = punkte or T.wertung(d, wb)
  local g, R = T.gegner(ctx, klasse, wb, runde), Rng.new(7)
  local win, top = 0, 0
  for _ = 1, T.SIM do
    local p = platz(own, g, R)
    if p == 1 then win = win + 1 end
    if p <= 3 then top = top + 1 end
  end
  return win * 100 // T.SIM, top * 100 // T.SIM
end

-- Teilnehmen: bezahlt, verbraucht den Wettbewerb, würfelt den Platz. Gibt Ergebnis oder false und Grund zurück.
-- punkte: Punktzahl aus einem Minispiel (sonst gerechnet).
function T.teilnehmen(ctx, day, d, klasse, wb, punkte)
  local st = T.state(ctx, day)
  local k = K.turniere.klassen[klasse]
  local ok = false
  for _, c in ipairs(T.klassen(ctx)) do if c.index == klasse then ok = true end end
  if not ok then return false, "Fahrzeug" end
  local key = klasse .. ":" .. wb
  if st.weg[key] then return false, "weg" end
  if d.alter < 1 then return false, "Fohlen" end
  if ctx.money < k.gebuehr then return false, "Geld" end
  ctx.money = ctx.money - k.gebuehr
  st.weg[key] = true
  local own = punkte or T.wertung(d, wb)
  local R = Rng.new((ctx.seed or 1) + day * 17 + klasse)
  local rank = platz(own, T.gegner(ctx, klasse, wb, st.runde), R)
  local preis = k.preise[rank] or 0
  ctx.money = ctx.money + preis
  return {rank = rank, preis = preis, gebuehr = k.gebuehr, wertung = own, klasse = k.name, wb = wb}
end

return T
