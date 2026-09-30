-- Wirtschaftssimulation (Aufgabe B8): spielt eine einfache Strategie über viele Tage durch und misst,
-- wie lange es bis zu den Zielen aus KATALOG §15 dauert. Reine Datenrechnung ohne Welt und Grafik.
--
-- Strategie: alle 2 Tage kommt ein Wildpferd dazu (Zähmen gelingt immer, kostet keine Zeit), die zwei
-- besten Pferde behalten wir zum Arbeiten, überzählige gehen an den Käufer des Tages (bestes Angebot).
-- Jedes Pferd macht täglich den bestbezahlten möglichen Job, wird bei Hunger mit Heu gefüttert und
-- gestriegelt. Bestellungen werden geliefert, wenn ein Pferd passt. Nicht modelliert (zu Gunsten der
-- Schätzung niedrig): Turniere (E1), Anbau (C5), Fundstücke (D3), Steuer-Reformen (E4).
local K = require("game.katalog")
local H = require("game.horse_model")
local V = require("game.value")
local Care = require("game.care")
local Days = require("game.days")
local Jobs = require("game.jobs")
local Buyers = require("game.buyers")
local Orders = require("game.orders")
local Rng = require("lib.rng")

local Sim = {}

Sim.KEEP = 2                    -- so viele Pferde bleiben zum Arbeiten
Sim.CATCH_EVERY = 2             -- alle 2 Tage ein neues Wildpferd
Sim.GOALS = {
  {id = "fahrrad", cost = 400, text = "Fahrrad (400)"},
  {id = "phase1", cost = 900, text = "Phase 1: Fahrrad + Schuppen + Anhänger 1 (900)"},
  {id = "mofa", cost = 2000, text = "Mofa (2000)"},
  {id = "phase2", cost = 3700, text = "Phase 2: Mofa + Anhänger 2 + Stall M (3700)"},
}

local function best_job(d, day)
  local best, pay
  for _, j in ipairs(Jobs.list()) do
    if Jobs.eligible(d, j, day) then
      local p = Jobs.lohn(d, j)
      if not pay or p > pay then best, pay = j, p end
    end
  end
  return best
end

-- Läuft `days` Tage mit Seed `seed`. Gibt {geld = {Tag → Geld}, erreicht = {Ziel-id → Tag}, verkauft, stats} zurück.
function Sim.run(seed, days)
  local rng = Rng.new(seed * 7 + 3)
  local ctx = {money = K.wirtschaft.startgeld, herd = {}, herd_horses = {}, lead = {}, orders = {}, seed = seed, max_gebiet = 1,
    clock = {day = 1}}
  local out = {geld = {}, erreicht = {}, verkauft = 0, job_einnahmen = 0, verkauf_einnahmen = 0, bestell_einnahmen = 0,
    futter_ausgaben = 0, tage = days}
  local spent = 0                   -- für Ziele ausgegebenes Geld
  local goal_i = 1
  local stall, weide = 0, 0

  for day = 1, days do
    ctx.clock.day = day
    -- Tageswechsel für alle Pferde
    if day > 1 then
      for _, d in ipairs(ctx.herd) do Days.horse_day(d) end
    end
    local kaeufer = Buyers.visit(seed, day)
    Orders.tick(ctx, day)
    -- neues Wildpferd
    if day % Sim.CATCH_EVERY == 0 then
      local d = H.wild({gebiet = 1, rng = rng})
      d.wild = nil
      ctx.herd[#ctx.herd + 1] = d
      -- Unterbringung: Stall (2), Weide (4), sonst nichts (Sauberkeit sinkt nicht, kein Training-Verlust)
      if stall < 2 then d.ort, stall = "stall", stall + 1 elseif weide < 4 then d.ort, weide = "weide", weide + 1 end
    end
    -- füttern und striegeln
    for _, d in ipairs(ctx.herd) do
      if d.hunger > 60 and ctx.money >= 5 then
        ctx.money = ctx.money - 5
        out.futter_ausgaben = out.futter_ausgaben + 5
        Care.feed(d, "heu")
      end
      if d.sauberkeit < 40 then Care.brush(d) end
      Care.stroke(d)
    end
    -- Bestellungen liefern
    for oi = #ctx.orders, 1, -1 do
      local o = ctx.orders[oi]
      for i, d in ipairs(ctx.herd) do
        if Orders.matches(o, d) then
          local sum = Orders.reward(d)
          ctx.money = ctx.money + sum
          out.bestell_einnahmen = out.bestell_einnahmen + sum
          table.remove(ctx.herd, i)
          table.remove(ctx.orders, oi)
          break
        end
      end
    end
    -- Jobs
    for _, d in ipairs(ctx.herd) do
      local j = best_job(d, day)
      if j then
        local sum = Jobs.run(ctx, j, d, day)
        if sum then out.job_einnahmen = out.job_einnahmen + sum end
      end
    end
    -- Verkauf an den Käufer des Tages: überzählige Pferde, bestes Angebot
    table.sort(ctx.herd, function(a, b) return V.leistung(a) > V.leistung(b) end)
    local best_i, best_p
    for i = Sim.KEEP + 1, #ctx.herd do
      local p = Buyers.offer(kaeufer.typ, ctx.herd[i])
      if p and (not best_p or p > best_p) then best_i, best_p = i, p end
    end
    if best_i then
      local d = ctx.herd[best_i]
      table.remove(ctx.herd, best_i)
      if d.ort == "stall" then stall = stall - 1 elseif d.ort == "weide" then weide = weide - 1 end
      ctx.money = ctx.money + best_p
      out.verkauft = out.verkauft + 1
      out.verkauf_einnahmen = out.verkauf_einnahmen + best_p
      local delta = Buyers.folge(kaeufer.typ)
      for _, e in ipairs(ctx.herd) do e.bindung = mid(0, e.bindung + delta, 100) end
    end
    -- Ziele: sobald das Geld reicht, wird ausgegeben (Geld sinkt)
    local goal = Sim.GOALS[goal_i]
    while goal and ctx.money + spent >= goal.cost do
      out.erreicht[goal.id] = day
      goal_i = goal_i + 1
      goal = Sim.GOALS[goal_i]
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

-- Läuft `seeds` Seeds mit je `days` Tagen und fasst zusammen: Tage bis zu jedem Ziel und Einnahmen je Tag.
function Sim.summary(seeds, days)
  local res = {ziele = {}}
  local runs = {}
  local income = {}
  for s = 1, seeds do
    local r = Sim.run(s, days)
    runs[s] = r
    income[#income + 1] = (r.job_einnahmen + r.verkauf_einnahmen + r.bestell_einnahmen - r.futter_ausgaben) / days
  end
  for _, g in ipairs(Sim.GOALS) do
    local list, missed = {}, 0
    for _, r in ipairs(runs) do
      if r.erreicht[g.id] then list[#list + 1] = r.erreicht[g.id] else missed = missed + 1 end
    end
    local mean, lo, hi = stats(list)
    res.ziele[g.id] = {mittel = mean, min = lo, max = hi, verfehlt = missed, text = g.text}
  end
  res.einnahmen_tag = (stats(income))
  local function avg(key)
    local t = {}
    for _, r in ipairs(runs) do t[#t + 1] = r[key] / days end
    return (stats(t))
  end
  res.job_tag, res.verkauf_tag, res.bestell_tag, res.futter_tag = avg("job_einnahmen"), avg("verkauf_einnahmen"),
    avg("bestell_einnahmen"), avg("futter_ausgaben")
  res.runs = runs
  return res
end

return Sim
