-- Selbsttests für das Springreiten-Minispiel (Aufgabe E2): Sprunghöhe, Ermüdung, Wertung, Turnierfluss.
local Springen = require("game.springen")
local Care = require("game.care")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local function horse(staerke, ausdauer, bindung)
  local d = H.wild({rng = Rng.new(5), rasse = "haflinger"})
  for _, k in ipairs(H.STATS) do d.gen[k], d.train[k], d.pot[k] = 50, 0, 100 end
  d.gen.staerke, d.gen.ausdauer = staerke, ausdauer
  d.bindung, d.gewicht = bindung or 100, 50
  return d
end

-- Spielt einen Parcours mit perfektem Timing (Sprung kurz vor jeder Stange) und gibt den Zustand zurück.
local function run(d, press)
  local s = Springen.new(d)
  local frames = 0
  while not s.done and frames < 3000 do
    frames = frames + 1
    local near = false
    if press then
      for _, h in ipairs(s.hurdles) do
        if h.state == "open" and h.x - s.x > 30 and h.x - s.x < 34 then near = true end
      end
    end
    Springen.update(s, near)
  end
  return s
end

return {
  {"Stangenhöhe 8 bis 30; Sprunghöhe wächst mit der Stärke, schwindet mit Ermüdung (Ausdauer)", function()
    C.near(Springen.hurdle_height(1), 8, 0.01)
    C.near(Springen.hurdle_height(10), 30, 0.01)
    local strong, weak = horse(90, 50), horse(10, 50)
    C.ok(Springen.reach(strong, 0) > Springen.reach(weak, 0))
    local lazy, fit = horse(60, 0), horse(60, 100)
    C.near(Springen.reach(fit, 1), Springen.reach(fit, 0), 0.01, "Ausdauer 100: kein Abfall")
    C.near(Springen.reach(lazy, 1), Springen.reach(lazy, 0) * 0.5, 0.5, "Ausdauer 0: halbe Höhe am Ende")
  end},
  {"Starkes Pferd mit gutem Timing schafft viele Stangen, schwaches wenige; ohne Sprung alles Fehler", function()
    local strong = run(horse(100, 100), true)
    local weak = run(horse(0, 100), true)
    local idle = run(horse(100, 100), false)
    C.ok(strong.done and weak.done and idle.done)
    C.ok(strong.clean >= 9, "stark: " .. strong.clean)
    C.ok(weak.clean < strong.clean, "schwach: " .. weak.clean)
    C.eq(idle.clean, 0)
    C.eq(idle.faults, Springen.HURDLES)
    C.eq(strong.clean + strong.faults, Springen.HURDLES)
  end},
  {"Ausdauer: müde Pferde fallen später ab", function()
    local fit = run(horse(60, 100), true)
    local tired = run(horse(60, 0), true)
    C.ok(fit.clean >= tired.clean)
  end},
  {"Punkte: saubere Stangen in % × Bindungsfaktor", function()
    local s = run(horse(100, 100, 100), true)
    C.near(Springen.punkte(s), s.clean * 10, 0.01)
    s.d.bindung = 0
    C.near(Springen.punkte(s), s.clean * 5, 0.01)
  end},
  {"Turnier mit Minispiel: Punkte ersetzen die Rechnung", function()
    local Stage = require("game.stage")
    local Area = require("game.area")
    local Turniere = require("game.turniere")
    Area.clear()
    local ctx = Stage.build(1, 51)
    ctx.money = 1000
    local d = horse(100, 100)
    local r = Turniere.teilnehmen(ctx, 1, d, 1, "springreiten", 100)
    C.eq(r.rank, 1)
    C.eq(r.wertung, 100)
    local r2 = Turniere.teilnehmen(ctx, 1, d, 1, "pferderennen", 0)
    C.ok(r2.rank >= 5, "0 Punkte: hinten")
  end},
}
