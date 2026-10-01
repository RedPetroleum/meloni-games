-- Wirtschaftssimulation (Aufgabe B8, Rebalancing E77): spielt eine Spielweise über viele Tage durch und misst,
-- wie lange jede Phase aus KATALOG §15 dauert. Reine Datenrechnung ohne Welt und Grafik.
--
-- Spielweise „normal“: jeden Tag ein Wildpferd aus dem weitesten erreichbaren Gebiet (Zähmen gelingt immer),
-- die drei besten Pferde bleiben, das beste wird täglich geritten (Galopp, Sprünge). Jeder Job einmal am Tag mit
-- dem bestbezahlten Pferd, ein Verkauf am Tag an den Käufer (bestes Angebot für ein überzähliges Pferd),
-- Bestellungen werden geliefert, Turniere in jeder Runde mit dem besten Pferd, wenn sich die Startgebühr lohnt
-- (Wertung aus den Werten, ohne Minispiel). Heu bei Hunger, Striegeln, Streicheln. Sobald das Geld reicht, wird
-- die nächste Phase gekauft. Nicht modelliert: Zucht, Anbau, Schätze, Göpel, Reformen, Deko.
local K = require("game.katalog")
local H = require("game.horse_model")
local V = require("game.value")
local Care = require("game.care")
local Days = require("game.days")
local Jobs = require("game.jobs")
local Buyers = require("game.buyers")
local Orders = require("game.orders")
local Turniere = require("game.turniere")
local Rng = require("lib.rng")

local Sim = {}

Sim.KEEP = 3                    -- so viele Pferde bleiben
Sim.CATCH = 1                   -- Wildpferde pro Tag
Sim.MIN_PER_DAY = 4.5           -- echte Minuten je Spieltag (Tag ausgespielt, Nacht verschlafen, Menüs halten die Uhr an)

-- Ziele: die Phasen aus KATALOG §15. Nach Phase n ist Gebiet n + 1 erreichbar (das Zugfahrzeug dafür).
Sim.GOALS = {}
for i, p in ipairs(K.wirtschaft.phasen) do
  local f
  for _, v in ipairs(K.welt.fahrzeuge) do if v.gebiete == i + 1 then f = v end end
  Sim.GOALS[i] = {id = "phase" .. i, cost = p.kosten, fahrzeug = f.id, text = "Phase " .. i .. ": " .. p.ziel .. " (" .. p.kosten .. ")"}
end

local WB = {"schoenheitswettbewerb", "springreiten", "pferderennen"}

-- Erwarteter Gewinn einer Teilnahme aus den angezeigten Chancen (2. und 3. Platz gemittelt).
local function lohnt(ctx, d, ki, wb, runde)
  local k = K.turniere.klassen[ki]
  local win, top = Turniere.chancen(ctx, d, ki, wb, runde)
  local ev = win / 100 * k.preise[1] + (top - win) / 100 * (k.preise[2] + k.preise[3]) / 2 - k.gebuehr
  return ev > 0
end

-- Läuft `days` Tage mit Seed `seed`. Gibt {geld = {Tag → Geld inkl. ausgegeben}, erreicht = {Ziel-id → Tag},
-- quellen = {Phase → {verkauf, jobs, bestellung, turnier, futter}}} zurück.
function Sim.run(seed, days)
  local rng = Rng.new(seed * 7 + 3)
  local ctx = {money = K.wirtschaft.startgeld, herd = {}, herd_horses = {}, lead = {}, orders = {}, seed = seed, max_gebiet = 1,
    clock = {day = 1}, inv = {}}
  local out = {geld = {}, erreicht = {}, quellen = {}, tage = days}
  for i = 1, #Sim.GOALS do out.quellen[i] = {verkauf = 0, jobs = 0, bestellung = 0, turnier = 0, futter = 0} end
  local spent, gi = 0, 1
  local function book(key, before)
    local q = out.quellen[gi]
    if q then q[key] = q[key] + ctx.money - before end
  end

  for day = 1, days do
    ctx.clock.day = day
    if day > 1 then for _, d in ipairs(ctx.herd) do Days.horse_day(d) end end
    local kaeufer = Buyers.visit(seed, day)
    Orders.tick(ctx, day)
    for _ = 1, Sim.CATCH do
      local d = H.wild({gebiet = ctx.max_gebiet, rng = rng})
      d.wild, d.ort = nil, "stall"
      ctx.herd[#ctx.herd + 1] = d
    end
    -- Pflege
    for _, d in ipairs(ctx.herd) do
      if d.hunger > 50 then
        local before = ctx.money
        ctx.money = ctx.money - 5
        book("futter", before)
        Care.feed(d, "heu")
      end
      if d.sauberkeit < 70 then Care.brush(d) end
      Care.stroke(d)
    end
    table.sort(ctx.herd, function(a, b) return V.leistung(a) > V.leistung(b) end)
    local star = ctx.herd[1]
    if star then
      Care.train(star, "tempo", 4)
      Care.train(star, "ausdauer", 2)
      Care.train(star, "staerke", 2)
    end
    -- Bestellungen
    for oi = #ctx.orders, 1, -1 do
      local o = ctx.orders[oi]
      for i, d in ipairs(ctx.herd) do
        if Orders.matches(o, d) then
          local before = ctx.money
          ctx.money = ctx.money + Orders.reward(d)
          book("bestellung", before)
          table.remove(ctx.herd, i)
          table.remove(ctx.orders, oi)
          break
        end
      end
    end
    -- Jobs: jeder einmal, mit dem bestbezahlten Pferd
    for _, j in ipairs(Jobs.list()) do
      local best, pay
      for _, d in ipairs(ctx.herd) do
        if Jobs.eligible(d, j, day, ctx) and (not pay or Jobs.lohn(d, j) > pay) then best, pay = d, Jobs.lohn(d, j) end
      end
      if best then
        local before = ctx.money
        Jobs.run(ctx, j, best, day)
        book("jobs", before)
      end
    end
    -- Turniere: am ersten Tag jeder Runde alles, was sich lohnt
    local F = require("game.fortschritt")
    if F.offen("turnier", day) and (day - 1) % K.turniere.rotation_tage == 0 then
      local runde = Turniere.runde(day)
      for _, c in ipairs(Turniere.klassen(ctx)) do
        for _, wb in ipairs(WB) do
          local bd, bw
          for _, d in ipairs(ctx.herd) do
            local w = Turniere.wertung(d, wb)
            if d.alter >= 1 and (not bw or w > bw) then bd, bw = d, w end
          end
          if bd and ctx.money >= c.def.gebuehr and lohnt(ctx, bd, c.index, wb, runde) then
            local before = ctx.money
            Turniere.teilnehmen(ctx, day, bd, c.index, wb)
            book("turnier", before)
          end
        end
      end
    end
    -- Verkauf: ein überzähliges Pferd an den Käufer des Tages, bestes Angebot. Den Schlachter (−20 Bindung für alle
    -- übrigen, Rückmeldung 1.3.3) meidet der Spieler: das kostet mehr Turniergeld, als der Verkauf bringt.
    if kaeufer and Buyers.folge(kaeufer.typ) > -20 then
      local best_i, best_p
      for i = Sim.KEEP + 1, #ctx.herd do
        local p = Buyers.offer(kaeufer.typ, ctx.herd[i])
        if p and (not best_p or p > best_p) then best_i, best_p = i, p end
      end
      if best_i then
        local before = ctx.money
        table.remove(ctx.herd, best_i)
        ctx.money = ctx.money + best_p
        book("verkauf", before)
        local delta = Buyers.folge(kaeufer.typ)
        for _, e in ipairs(ctx.herd) do e.bindung = mid(0, e.bindung + delta, 100) end
      end
    end
    -- Ziele: sobald das Geld reicht, wird gekauft
    local goal = Sim.GOALS[gi]
    while goal and ctx.money >= goal.cost do
      ctx.money = ctx.money - goal.cost
      spent = spent + goal.cost
      ctx.inv[goal.fahrzeug] = 1
      ctx.max_gebiet = gi + 1
      out.erreicht[goal.id] = day
      gi = gi + 1
      goal = Sim.GOALS[gi]
    end
    out.geld[day] = ctx.money + spent
  end
  out.pferde = #ctx.herd
  return out
end

-- Mittel, kleinster und größter Wert aus einer Liste (nil-Einträge zählen nicht).
local function stats(list)
  local sum, n, lo, hi = 0, 0, nil, nil
  for _, v in ipairs(list) do
    sum, n = sum + v, n + 1
    lo = lo and min(lo, v) or v
    hi = hi and max(hi, v) or v
  end
  return n > 0 and sum / n or nil, lo, hi, n
end
Sim.stats = stats

-- Läuft `seeds` Seeds mit je `days` Tagen und fasst zusammen: Tage je Phase (Dauer der Phase, nicht ab Spielbeginn),
-- Einnahmen je Tag und Quelle in der Phase.
function Sim.summary(seeds, days)
  local res = {phasen = {}}
  local runs = {}
  for s = 1, seeds do runs[s] = Sim.run(s, days) end
  for i, g in ipairs(Sim.GOALS) do
    local dauer, missed = {}, 0
    local q = {verkauf = 0, jobs = 0, bestellung = 0, turnier = 0, futter = 0}
    for _, r in ipairs(runs) do
      local t = r.erreicht[g.id]
      local prev = i == 1 and 0 or r.erreicht[Sim.GOALS[i - 1].id]
      if t and prev then
        local len = max(1, t - prev)
        dauer[#dauer + 1] = len
        for k, v in pairs(r.quellen[i]) do q[k] = q[k] + v / len end
      else
        missed = missed + 1
      end
    end
    local mean, lo, hi, n = stats(dauer)
    for k, v in pairs(q) do q[k] = n > 0 and v / n or 0 end
    q.netto = q.verkauf + q.jobs + q.bestellung + q.turnier + q.futter
    res.phasen[i] = {mittel = mean, min = lo, max = hi, verfehlt = missed, text = g.text, quellen = q,
      minuten = mean and mean * Sim.MIN_PER_DAY}
  end
  res.runs = runs
  return res
end

return Sim
