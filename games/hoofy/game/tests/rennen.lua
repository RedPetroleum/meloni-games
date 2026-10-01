-- Selbsttests für das Pferderennen-Minispiel (Aufgabe E3): Tempo, Ausdauer, Gegner, Platz und Punkte.
local Rennen = require("game.rennen")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local function horse(tempo, ausdauer, bindung)
  local d = H.wild({rng = Rng.new(5), rasse = "haflinger"})
  for _, k in ipairs(H.STATS) do d.gen[k], d.train[k], d.pot[k] = 50, 0, 100 end
  d.gen.tempo, d.gen.ausdauer = tempo, ausdauer
  d.bindung, d.gewicht = bindung or 100, 50
  return d
end

-- Läuft das Rennen; strategy(s) → ob A gehalten wird.
local function run(d, gegner, strategy)
  local s = Rennen.new(d, gegner, Rng.new(1))
  local n = 0
  while not s.done and n < 5000 do
    n = n + 1
    Rennen.update(s, strategy(s))
  end
  return s
end

local always = function() return true end

return {
  {"Höchstgeschwindigkeit wächst mit Tempo und Bindung (Tempo 100: 3,4 px/Frame)", function()
    C.near(Rennen.speed(100), 3.4, 0.001)
    C.near(Rennen.vmax(horse(100, 50, 100)), 3.4, 0.05)
    C.ok(Rennen.vmax(horse(80, 50)) > Rennen.vmax(horse(30, 50)))
    C.ok(Rennen.vmax(horse(80, 50, 0)) < Rennen.vmax(horse(80, 50, 100)), "Bindung 0: langsamer")
  end},
  {"Ausdauer bestimmt den Spurtvorrat; leer = erschöpft, im Trab erholt es sich", function()
    C.ok(Rennen.stamina(horse(50, 100)) > Rennen.stamina(horse(50, 10)))
    local d = horse(60, 0)
    local s = Rennen.new(d, {}, Rng.new(1))
    local cap = s.stamina
    for _ = 1, flr(cap) + 5 do Rennen.update(s, true) end
    C.eq(s.stamina, 0)
    local v_tired = s.v
    C.near(v_tired, s.vmax * Rennen.TIRED, 0.001)
    for _ = 1, 60 do Rennen.update(s, false) end
    C.ok(s.stamina > 25, "im Trab erholt")
    C.near(s.v, s.vmax * Rennen.JOG, 0.001)
  end},
  {"Starkes Pferd gewinnt gegen Gegner, schwaches wird Letztes; Spurt schlägt Trab", function()
    local gegner = {40, 35, 30, 25, 20}
    local strong = run(horse(100, 100), gegner, always)
    C.eq(Rennen.platz(strong), 1)
    local weak = run(horse(5, 20), gegner, always)
    C.eq(Rennen.platz(weak), 6)
    local trot = run(horse(100, 100), gegner, function() return false end)
    C.ok(trot.time > strong.time, "Trab langsamer")
    C.ok(Rennen.punkte(strong) > Rennen.punkte(trot))
  end},
  {"Punkte 0–100 aus der Durchschnittsgeschwindigkeit; Gegner laufen mit", function()
    local s = run(horse(100, 100), {50}, always)
    C.between(Rennen.punkte(s), 60, 100)
    C.ok(s.rivals[1].x > 0)
    C.ok(Rennen.punkte(s) <= 100)
  end},
  {"Rennbildschirm zeichnet und liefert Punkte und Platz an das Turnier", function()
    local Screens = require("game.screens")
    local d = horse(100, 100)
    local got = {}
    local s = Screens.rennen({}, d, {10, 10, 10, 10, 10}, function(p, platz) got.p, got.platz = p, platz end)
    local nav = {stack = {s}}
    function nav.pop() nav.stack[#nav.stack] = nil end
    local old = btn
    btn = function(b) return b == BTN_A end
    local oldp = btnp
    for _ = 1, 700 do s.update(nav) end
    s.draw()
    btnp = function(b) return b == BTN_A end
    s.update(nav)
    btn, btnp = old, oldp
    C.eq(got.platz, 1)
    C.ok(got.p > 50)
    C.eq(#nav.stack, 0)
  end},
}
