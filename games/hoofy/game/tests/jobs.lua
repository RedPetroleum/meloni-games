-- Selbsttests für Jobs (Aufgabe B5): Lohn, Training, Energie, Voraussetzungen, ein Job pro Tag.
local Stage = require("game.stage")
local Wild = require("game.wild")
local Jobs = require("game.jobs")
local K = require("game.katalog")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local function job(id)
  for _, j in ipairs(Jobs.list()) do if j.id == id then return j end end
end

local function horse(extra)
  local d = H.wild({rng = Rng.new(2), rasse = "haflinger", zug = "nachteule"})
  d.gen = {tempo = 40, staerke = 60, spuer = 35, ausdauer = 75}
  d.train = {tempo = 0, staerke = 0, spuer = 0, ausdauer = 0}
  d.pot = {tempo = 80, staerke = 80, spuer = 50, ausdauer = 100}
  d.bindung, d.sauberkeit, d.gewicht, d.energie = 50, 60, 50, 75
  for k, v in pairs(extra or {}) do d[k] = v end
  return d
end

return {
  {"Drei Jobs aus dem Katalog mit Energiekosten 30 / 30 / 40", function()
    C.eq(#Jobs.list(), 3)
    C.eq(job("postritt").energie, 30)
    C.eq(job("kutschtaxi").energie, 30)
    C.eq(job("pfluegen").energie, 40)
  end},
  {"Lohn: Postritt 15 + Tempo/2, Kutschtaxi 15 + Stärke/2, Pflügen 25 + Stärke/3", function()
    local d = horse()
    C.eq(Jobs.lohn(d, job("postritt")), 15 + 20)
    C.eq(Jobs.lohn(d, job("kutschtaxi")), 15 + 30)
    C.eq(Jobs.lohn(d, job("pfluegen")), 25 + 20)
    d.train.staerke = 7
    C.eq(Jobs.lohn(d, job("pfluegen")), 25 + 22, "Training zählt")
  end},
  {"Voraussetzungen: Postritt ab Bindung 40, Kutschtaxi ab Stärke 30, Pflügen ab Stärke 50", function()
    local d = horse({bindung = 39})
    local ok, why = Jobs.eligible(d, job("postritt"), 1)
    C.ok(not ok and why:find("Bindung"), "Bindung 39")
    d.bindung = 40
    C.ok(Jobs.eligible(d, job("postritt"), 1))
    d.gen.staerke = 29
    C.ok(not Jobs.eligible(d, job("kutschtaxi"), 1))
    d.gen.staerke = 30
    C.ok(Jobs.eligible(d, job("kutschtaxi"), 1))
    C.ok(not Jobs.eligible(d, job("pfluegen"), 1), "Stärke 30 < 50")
    d.gen.staerke = 50
    C.ok(Jobs.eligible(d, job("pfluegen"), 1))
  end},
  {"Arbeiten: Geld, Energie ab, Training nach der Formel, ein Job pro Pferd und Tag", function()
    local ctx = Stage.build(1)
    ctx.money = 10
    local d = horse()
    local before = {tempo = d.train.tempo, ausdauer = d.train.ausdauer}
    local sum = Jobs.run(ctx, job("postritt"), d, 3)
    C.eq(sum, 35)
    C.eq(ctx.money, 45)
    C.eq(d.energie, 45, "75 − 30")
    -- Tempo +2 × (1 − 40/80) × Bonus (1 + 0,25 × 0,6 + 0,25 × 0,5 = 1,275), Ausdauer +1 × (1 − 75/100) × 1,275
    C.near(d.train.tempo - before.tempo, 2 * 0.5 * 1.275, 1e-4)
    C.near(d.train.ausdauer - before.ausdauer, 1 * 0.25 * 1.275, 1e-4)
    local again, why = Jobs.run(ctx, job("kutschtaxi"), d, 3)
    C.ok(again == nil and why:find("schon gearbeitet"), "zweiter Job am selben Tag")
    C.eq(ctx.money, 45)
    local nextday = Jobs.run(ctx, job("kutschtaxi"), d, 4)
    C.ok(nextday, "am nächsten Tag wieder")
    C.eq(d.energie, 15)
  end},
  {"Zu wenig Energie: kein Job; Pflügen braucht 40", function()
    local ctx = Stage.build(1)
    local d = horse({energie = 39})
    local p, why = Jobs.run(ctx, job("pfluegen"), d, 1)
    C.ok(p == nil and why:find("müde"))
    C.eq(d.energie, 39, "nichts abgezogen")
    d.energie = 40
    C.ok(Jobs.run(ctx, job("pfluegen"), d, 1))
    C.eq(d.energie, 0)
    C.near(d.train.staerke, 3 * (1 - 60 / 80) * 1.275, 1e-4, "Stärke +3")
  end},
  {"Training begrenzt durch das Potenzial, Bildschirme", function()
    local ctx = Stage.build(1)
    local d = horse()
    d.gen.tempo, d.pot.tempo = 80, 80
    Jobs.run(ctx, job("postritt"), d, 1)
    C.eq(d.train.tempo, 0, "am Potenzial nichts mehr")
    local Screens = require("game.screens")
    ctx.wild = Wild.new(ctx, 1)
    ctx.wild:add_own({name = "Hilde"})
    Screens.jobs(ctx).draw()
    local nav = {stack = {}}
    function nav.push(s) nav.stack[#nav.stack + 1] = s end
    function nav.pop() nav.stack[#nav.stack] = nil end
    local sc = Screens.jobs(ctx)
    nav.push(sc)
    local old = btnp
    btnp = function(b) return b == BTN_A end
    sc.update(nav)
    C.eq(#nav.stack, 2)
    sc.update(nav)
    nav.stack[2].update(nav)
    btnp = old
    nav.stack[#nav.stack].draw()
  end},
}
