-- Regierungsreformen (Aufgabe E4, KATALOG §14): alle 4 Tage verkündet die Zeitung eine neue Reform, die 3–5 Tage
-- gilt. Steuern und Subventionen ändern Zahlen; freie Tiere greifen den Hof an (abstrakt beim Tageswechsel,
-- Tiere laufen nur als Bild herum), starke Pferde draußen wehren sie ab.
local K = require("game.katalog")
local H = require("game.horse_model")
local Care = require("game.care")
local Farm = require("game.farm")
local Rng = require("lib.rng")

local R = {}

R.ANGRIFFE = 2               -- Tiere je Nacht (Krokodile auch tags: doppelt)
R.SCHADEN = 2                -- zerstörte Deko je ungeschütztem Angriff
R.ANGST = 5                  -- Bindungsverlust für schwache Pferde draußen

-- Zustand: ctx.reform = {aktiv = {{id, von, bis}}, naechste = Tag der nächsten Verkündung, seit = {[gebiet] = Tag}}
function R.state(ctx)
  if not ctx.reform then ctx.reform = {aktiv = {}, naechste = K.reformen.alle_tage, seit = {}} end
  return ctx.reform
end

function R.def(id)
  for _, r in ipairs(K.reformen.liste) do if r.id == id then return r end end
  error("unbekannte Reform " .. tostring(id))
end

-- Vermerkt, ab wann ein Gebiet erreicht ist (für Wölfe/Krokodile).
function R.erreicht(ctx, nr, day)
  local st = R.state(ctx)
  st.seit[nr] = st.seit[nr] or day
end

function R.ist_aktiv(ctx, id)
  for _, a in ipairs(R.state(ctx).aktiv) do if a.id == id then return a end end
end

-- Welche Reformen sind an diesem Tag möglich?
local function moegliche(ctx, day)
  local st, out = R.state(ctx), {}
  for _, r in ipairs(K.reformen.liste) do
    local ok = true
    if r.gebiet then
      local seit = st.seit[r.gebiet]
      ok = seit ~= nil and day >= seit + (r.tage_nach or 0)
    end
    if R.ist_aktiv(ctx, r.id) then ok = false end
    if ok then out[#out + 1] = r end
  end
  return out
end

-- Pferdesteuer je Pferd und Tag: 0–10, steigt im Spielverlauf (alle 6 Tage +1).
function R.steuer(day)
  return math.min(K.reformen.liste[4].steuer_max, math.max(K.reformen.liste[4].steuer_min, (day - 1) // 6))
end

-- Setzt die Wirkungen der aktiven Reformen auf Preise (Hafersteuer). Der Generator fragt `faktor_strom`.
function R.anwenden(ctx)
  ctx.futter_aufschlag = R.ist_aktiv(ctx, "hafersteuer") and R.def("hafersteuer").futter_aufschlag or 0
end

-- Faktor für den Göpel-Generator (Stromsubvention ×2).
function R.faktor_strom(ctx)
  return R.ist_aktiv(ctx, "stromsubvention") and R.def("stromsubvention").generator_faktor or 1
end

-- Nacht (und bei Krokodilen auch Tag) vor dem Tag `day`: greifen freie Tiere an? Bericht
-- {tiere = Name, abgewehrt, zerstoert = Anzahl Deko, erschreckt = Pferde} oder nil.
function R.angriffe(ctx, day)
  local farm = ctx.hof or ctx.area.farm
  if not farm then return nil end
  local akt
  for _, id in ipairs({"krokodile_frei", "woelfe_frei", "hunde_frei"}) do
    if R.ist_aktiv(ctx, id) then akt = R.def(id) break end
  end
  if not akt then return nil end
  local n = R.ANGRIFFE * (akt.tagsueber and 2 or 1)
  local draussen, wehr = {}, {}
  for _, d in ipairs(ctx.herd) do
    if d.ort == "weide" or d.ort == "frei" then
      draussen[#draussen + 1] = d
      if Care.effective(d, "staerke") >= akt.abwehr_staerke then wehr[#wehr + 1] = d end
    end
  end
  local rep = {tiere = akt.name, abgewehrt = #wehr > 0, zerstoert = 0, erschreckt = 0}
  if #wehr > 0 then
    for _, d in ipairs(wehr) do Care.train(d, "staerke", 0.2) end
    return rep
  end
  local rng = Rng.new((ctx.seed or 1) + day * 7)
  local deko = {}
  for _, id in ipairs(Farm.CATEGORIES[1].items) do deko[id] = true end
  local ziele = {}
  for _, it in ipairs(farm.items or {}) do if deko[it.id] then ziele[#ziele + 1] = it end end
  for _ = 1, n do
    if #ziele == 0 then break end
    for _ = 1, R.SCHADEN do
      if #ziele == 0 then break end
      local i = rng:int(1, #ziele)
      local it = table.remove(ziele, i)
      if ctx.area.farm then
        local before = ctx.money
        Farm.remove(ctx, it.cx, it.cy)
        ctx.money = before                -- kein Geld zurück: die Deko ist kaputt
      else
        for j, e in ipairs(farm.items) do if e == it then table.remove(farm.items, j) break end end
        Farm.reindex(farm)
      end
      rep.zerstoert = rep.zerstoert + 1
    end
  end
  for _, d in ipairs(draussen) do
    d.bindung = math.max(0, d.bindung - R.ANGST)
    rep.erschreckt = rep.erschreckt + 1
  end
  return rep
end

-- Tageswechsel zu `day`: Angriffe der letzten Nacht, abgelaufene Reformen weg, neue verkünden, Steuer. Setzt
-- ctx.reform_neu (Name der neuen Reform), ctx.angriff (Bericht) und ctx.steuer (gezahlt).
function R.tick(ctx, day)
  local st = R.state(ctx)
  ctx.reform_neu, ctx.steuer = nil, 0
  ctx.angriff = R.angriffe(ctx, day)
  local steuer = R.ist_aktiv(ctx, "pferdesteuer")
  if steuer then
    local total = R.steuer(day) * #ctx.herd
    total = math.min(total, ctx.money)
    ctx.money = ctx.money - total
    ctx.steuer = total
  end
  for i = #st.aktiv, 1, -1 do if st.aktiv[i].bis < day then table.remove(st.aktiv, i) end end
  if day >= st.naechste then
    local list = moegliche(ctx, day)
    local rng = Rng.new((ctx.seed or 1) * 13 + day)
    if #list > 0 then
      local r = list[rng:int(1, #list)]
      local dauer = rng:int(K.reformen.dauer_min, K.reformen.dauer_max)
      st.aktiv[#st.aktiv + 1] = {id = r.id, von = day, bis = day + dauer - 1}
      ctx.reform_neu = r.name
    end
    st.naechste = day + K.reformen.alle_tage
  end
  R.anwenden(ctx)
end

-- Bild der freien Tiere (nur zum Anschauen): laufen um den Hof, Hunde und Wölfe nachts, Krokodile immer.
function R.draw_tiere(ctx, clock, now)
  local akt
  for _, id in ipairs({"krokodile_frei", "woelfe_frei", "hunde_frei"}) do
    if R.ist_aktiv(ctx, id) then akt = R.def(id) akt.sprite = id:gsub("_frei", "") break end
  end
  if not akt or not (akt.tagsueber or clock:is_night()) then return end
  local sprite = ({hunde_frei = "tier_hund", woelfe_frei = "tier_wolf", krokodile_frei = "tier_krokodil"})[akt.id]
  local p = ctx.area.plot
  for i = 1, 4 do
    local w, h = p.w * 16, p.h * 16
    local x = p.x * 16 + (now * (0.4 + i * 0.1) + i * 97) % w
    local y = p.y * 16 + (i * 83 + 40 + math.sin(now / 40 + i) * 6) % h
    ctx.S.draw(sprite, flr(x), flr(y), ((now // 90) + i) % 2 == 0)
  end
end

return R
