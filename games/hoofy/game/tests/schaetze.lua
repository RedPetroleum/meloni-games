-- Selbsttests für Schätze (Aufgabe D3): Verteilung, Radius und Chance, Aufspüren, Funde und Transport.
local Stage = require("game.stage")
local Area = require("game.area")
local Wild = require("game.wild")
local Schaetze = require("game.schaetze")
local Economy = require("game.economy")
local H = require("game.horse_model")
local K = require("game.katalog")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local function setup(nr)
  Area.clear()
  local ctx = Stage.build(nr or 1, 21)
  ctx.money = 0
  ctx.wild = Wild.new(ctx, 3)
  ctx.wild.count = 0
  ctx.fund_rng = Rng.new(1)
  ctx.lager = {}
  Schaetze.setup(ctx)
  return ctx
end

-- Ein folgendes Pferd mit Aufspürung spuer, direkt neben dem ersten Schatz (dist Kacheln entfernt).
local function scout(ctx, spuer, dist)
  local h = ctx.wild:add_own({rasse = "haflinger", name = "Nase"})
  h.data.gen.spuer, h.data.train.spuer, h.data.pot.spuer = spuer, 0, 100
  h.state = "follow"
  ctx.lead[#ctx.lead + 1] = h
  local t = ctx.schaetze[1]
  h.x, h.y = t.cx * 16 + 8 + dist * 16, t.cy * 16 + 8
  return h, t
end

return {
  {"15–30 Schätze je Gebiet auf Wiese, nie auf dem Hof oder im Dorf; ab Gebiet 3 Truhen möglich", function()
    local truhen = 0
    for nr = 1, 6 do
      Area.clear()
      local ctx = Stage.build(nr, 21)
      local list = Schaetze.generate(ctx.area)
      C.between(#list, 15, 30, "Gebiet " .. nr)
      local pl = ctx.area.plot
      for _, t in ipairs(list) do
        C.eq(ctx.map:code(t.cx, t.cy), ".")
        C.ok(not (t.cx >= pl.x and t.cx < pl.x + pl.w and t.cy >= pl.y and t.cy < pl.y + pl.h), "nicht auf dem Hof")
        if t.fund == "schatztruhe" then
          truhen = truhen + 1
          C.ok(nr >= 3, "Truhe erst ab Gebiet 3")
        end
      end
      local again = Schaetze.generate(ctx.area)
      C.eq(#again, #list)
      C.eq(again[1].cx, list[1].cx, "aus dem Seed")
    end
  end},
  {"Radius 2 + Aufspürung / 10 Kacheln, Chance Aufspürung / 2 %", function()
    local d = H.wild({rng = Rng.new(2)})
    d.gen.spuer, d.train.spuer = 50, 0
    C.near(Schaetze.radius(d), 7 * 16, 0.01)
    C.near(Schaetze.chance(d), 0.25, 0.0001)
  end},
  {"Aufspüren nur im Radius und mit Platz; 👃 am Pferd", function()
    local ctx = setup(1)
    local h = scout(ctx, 50, 10)
    local old = rnd
    rnd = function() return 0 end
    Schaetze.update(ctx, 0, 0)
    C.eq(h.schatz, nil, "10 Kacheln: außerhalb")
    h.x = h.x - 5 * 16
    Schaetze.update(ctx, 0, 60)
    C.ok(h.schatz ~= nil, "5 Kacheln: aufgespürt")
    rnd = old
    local ctx2 = setup(2)
    local h2 = scout(ctx2, 50, 2)
    rnd = function() return 0 end
    Schaetze.update(ctx2, 0, 0)
    C.eq(h2.schatz, nil, "Gebiet 2 ohne Satteltaschen: kein Platz")
    h2.data.taschen = "satteltaschen_s"
    Schaetze.update(ctx2, 0, 60)
    C.ok(h2.schatz ~= nil)
    rnd = old
  end},
  {"Nach 1 s ohne Steuern läuft das Pferd hin; Fund: im Heimattal sofort Geld/Samen, Aufspürung +", function()
    local ctx = setup(1)
    local h, t = scout(ctx, 50, 2)
    local fund = t.fund
    local old = rnd
    rnd = function() return 0 end
    Schaetze.update(ctx, 0, 0)
    rnd = old
    C.ok(h.schatz == t)
    local n = #ctx.schaetze
    local before = h.data.train.spuer
    for f = 1, 30 do Schaetze.update(ctx, 10, 61 + f) end
    C.ok(not h.laufen and h.schatz == t, "unter 1 s steht es noch")
    Schaetze.update(ctx, 70, 100)
    C.ok(h.laufen, "läuft los")
    local hx, hy = Schaetze.heading(h, h.x, h.y)
    C.ok(hx < 0, "Richtung zum Fund (links)")
    h.x = t.cx * 16 + 8                     -- angekommen (die Bewegung selbst macht Horse:update)
    Schaetze.update(ctx, 70, 101)
    C.ok(h.laufen == nil and h.schatz == nil, "Fund gemacht")
    C.eq(#ctx.schaetze, n - 1)
    C.ok(ctx.gefunden[1][t.nr])
    C.ok(h.data.train.spuer > before, "Aufspürung steigt mit dem Fund")
    local expect = 0
    for _, f in ipairs(K.schaetze.funde) do if f.id == fund then expect = f.wert end end
    if fund ~= "samen" then C.eq(ctx.money, expect) end
  end},
  {"Unterwegs: Funde in die Satteltasche, am Fahrzeug ins Lager, daheim ins Haus; Tasche voll = kein Spüren", function()
    local ctx = setup(3)
    local h, t = scout(ctx, 50, 0)
    h.data.taschen = "satteltaschen_s"
    local old = rnd
    rnd = function() return 0 end
    Schaetze.update(ctx, 0, 0)
    rnd = old
    for f = 1, 3 do Schaetze.update(ctx, 70, 10 + f) end
    C.eq(#h.data.fund, 1, "Tasche S fasst 1")
    C.eq(ctx.money, 0, "noch nichts verkauft")
    C.ok(not Schaetze.has_room(ctx, h), "voll")
    C.eq(Schaetze.abladen(ctx), 1)
    C.eq(#ctx.lager, 1)
    C.eq(h.data.fund, nil)
    ctx.lager = {"muenzbeutel", "goldhufeisen"}
    local n, sum = Schaetze.heimbringen(ctx)
    C.eq(n, 2)
    C.eq(sum, 230)
    C.eq(ctx.money, 230)
    C.eq(#ctx.lager, 0)
  end},
}
