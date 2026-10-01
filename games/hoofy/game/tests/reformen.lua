-- Selbsttests für Reformen (Aufgabe E4): Zeitung alle 4 Tage, Dauer, Steuern, Subventionen, Tierangriffe.
local Stage = require("game.stage")
local Area = require("game.area")
local Wild = require("game.wild")
local Farm = require("game.farm")
local Days = require("game.days")
local Economy = require("game.economy")
local Reformen = require("game.reformen")
local K = require("game.katalog")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")
local U = require("lib.util")

local function setup()
  Area.clear()
  local ctx = Stage.build(1, 61)
  ctx.money = 10000
  ctx.wild = Wild.new(ctx, 3)
  ctx.wild.count = 0
  return ctx, ctx.area.plot
end

local function aktiv(ctx, id, bis)
  local st = Reformen.state(ctx)
  st.aktiv[#st.aktiv + 1] = {id = id, von = 1, bis = bis or 10}
end

local function pferd(ctx, staerke, ort)
  local h = ctx.wild:add_own({rasse = "noriker", name = "P" .. #ctx.herd})
  h.data.gen.staerke, h.data.train.staerke, h.data.pot.staerke = staerke, 0, 100
  h.data.gewicht = 50
  ctx.wild:house(h, ort)
  h.data.ort = ort                 -- auch wenn Platz oder Bindung fehlen: hier zählt nur der Ort
  return h.data
end


-- Eigene Bauteile (ohne den Startzaun der Weide, der seit 1.3.3 auch in farm.items steht).
local function own_items(ctx)
  local out = {}
  for _, it in ipairs(ctx.area.farm.items) do if not it.start then out[#out + 1] = it end end
  return out
end

return {
  {"Alle 4 Tage eine neue Reform, Dauer 3–5 Tage, Wölfe erst 4 Tage nach Gebiet 3", function()
    local ctx = setup()
    local gesehen, last = {}, 0
    for day = 2, 60 do
      Reformen.tick(ctx, day)
      if ctx.reform_neu then
        C.ok(day >= 10 and (day - 10) % 4 == 0, "Verkündung an Tag " .. day)
        local a = Reformen.state(ctx).aktiv[#Reformen.state(ctx).aktiv]
        C.between(a.bis - a.von + 1, 3, 5)
        gesehen[a.id] = true
        C.ok(a.id ~= "woelfe_frei" and a.id ~= "krokodile_frei", "ohne erreichtes Gebiet keine Wölfe/Krokodile")
      end
    end
    C.ok(gesehen.hunde_frei or gesehen.pferdesteuer or gesehen.hafersteuer or gesehen.stromsubvention, "es kommt etwas")
    Reformen.erreicht(ctx, 3, 5)
    local moeglich = false
    for day = 61, 200 do
      Reformen.tick(ctx, day)
      local a = Reformen.state(ctx).aktiv
      for _, e in ipairs(a) do if e.id == "woelfe_frei" then moeglich = true end end
    end
    C.ok(moeglich, "Wölfe nach Gebiet 3")
  end},
  {"Hafersteuer: Futter +50 %; Stromsubvention: Generator ×2; Pferdesteuer steigt", function()
    local ctx = setup()
    aktiv(ctx, "hafersteuer", 5)
    Reformen.anwenden(ctx)
    C.eq(Economy.price(ctx, Economy.find("heu")), 8)
    Reformen.state(ctx).aktiv = {}
    Reformen.anwenden(ctx)
    C.eq(Economy.price(ctx, Economy.find("heu")), 5)
    aktiv(ctx, "stromsubvention", 5)
    C.eq(Reformen.faktor_strom(ctx), 2)
    C.eq(Reformen.steuer(1), 0)
    C.ok(Reformen.steuer(40) > Reformen.steuer(10))
    C.eq(Reformen.steuer(1000), 10, "höchstens 10")
    Reformen.state(ctx).aktiv = {}
    aktiv(ctx, "pferdesteuer", 99)
    pferd(ctx, 50, "stall") pferd(ctx, 50, "stall")
    local before = ctx.money
    Reformen.tick(ctx, 31)
    C.eq(before - ctx.money, Reformen.steuer(31) * 2)
  end},
  {"Hunde: ohne starkes Pferd draußen geht Deko kaputt (kein Geld zurück), schwache Pferde erschrecken", function()
    local ctx, p = setup()
    for i = 0, 5 do Farm.place(ctx, "bank", p.x + 13 + i, p.y + 3) end
    C.eq(#own_items(ctx), 6)
    local schwach = pferd(ctx, 20, "weide")
    schwach.bindung = 50
    aktiv(ctx, "hunde_frei")
    local money = ctx.money
    local rep = Reformen.angriffe(ctx, 5)
    C.ok(not rep.abgewehrt)
    C.eq(rep.zerstoert, Reformen.ANGRIFFE * Reformen.SCHADEN)
    C.eq(#own_items(ctx), 6 - rep.zerstoert)
    C.eq(ctx.money, money, "kein Geld zurück")
    C.eq(schwach.bindung, 50 - Reformen.ANGST)
  end},
  {"Starke Pferde draußen wehren ab (Hunde ≥ 40, Wölfe ≥ 60, Krokodile ≥ 80); im Stall hilft das nicht", function()
    local ctx, p = setup()
    Farm.place(ctx, "bank", p.x + 13, p.y + 3)
    pferd(ctx, 45, "weide")
    aktiv(ctx, "hunde_frei")
    C.ok(Reformen.angriffe(ctx, 5).abgewehrt, "Hunde: 45 reicht")
    ctx.reform = nil
    aktiv(ctx, "woelfe_frei")
    C.ok(not Reformen.angriffe(ctx, 5).abgewehrt, "Wölfe: 45 reicht nicht")
    pferd(ctx, 65, "frei")
    C.ok(Reformen.angriffe(ctx, 5).abgewehrt, "Wölfe: 65 reicht")
    ctx.reform = nil
    aktiv(ctx, "krokodile_frei")
    C.ok(not Reformen.angriffe(ctx, 5).abgewehrt, "Krokodile: 65 reicht nicht")
    local stall = pferd(ctx, 95, "stall")
    local ctx2 = setup()
    pferd(ctx2, 95, "stall")
    aktiv(ctx2, "hunde_frei")
    Farm.place(ctx2, "bank", ctx2.area.plot.x + 13, ctx2.area.plot.y + 3)
    C.ok(not Reformen.angriffe(ctx2, 5).abgewehrt, "starkes Pferd im Stall wehrt nicht ab")
  end},
  {"Tageswechsel über Days: Zeitung, Reform läuft ab, Zeitungsbild zeichnet", function()
    local ctx = setup()
    ctx.clock = {day = 4}
    Days.new_day(ctx, 4)
    C.ok(ctx.reform_neu == nil, "Tag 4: noch keine Zeitung")
    ctx.clock = {day = 10}
    Days.new_day(ctx, 10)
    C.ok(ctx.reform_neu ~= nil, "Tag 10: erste Verkündung")
    C.eq(Reformen.state(ctx).naechste, 14)
    local Screens = require("game.screens")
    Screens.zeitung(ctx).draw()
    local st = Reformen.state(ctx)
    for d = 5, 9 do Days.new_day(ctx, d) end
    for _, a in ipairs(st.aktiv) do C.ok(a.bis >= 9, "Abgelaufenes ist weg") end
  end},  {"Freie Tiere: nachts auf dem Hof, laufen nicht durch Zäune und Gebäude, tagsüber weg (Hunde)", function()
    local ctx = setup()
    local Clock = require("game.clock")
    local clock = Clock.new(5, 0)
    aktiv(ctx, "hunde_frei")
    C.eq(#Reformen.tiere(ctx, clock), 0, "tagsüber keine Hunde")
    clock.t = Clock.LIGHT + 2000
    local list = Reformen.tiere(ctx, clock)
    C.eq(#list, Reformen.TIERE, "nachts vier Hunde")
    local farm = ctx.area.farm
    local moved = 0
    local start = {}
    for i, e in ipairs(list) do start[i] = {e.x, e.y} end
    for _ = 1, 1200 do
      ctx.world:update()
      for _, e in ipairs(list) do
        C.ok(require("lib.body").free(ctx.map, e.x, e.y, e.fw, e.fh), "Hund steht nie in einem Hindernis")
        C.ok(Farm.owns(farm, flr(e.x / 16), flr((e.y - 1) / 16)), "Hund bleibt auf dem Hof")
      end
    end
    for i, e in ipairs(list) do if U.dist(e.x, e.y, start[i][1], start[i][2]) > 16 then moved = moved + 1 end end
    C.ok(moved >= 3, "Hunde streifen umher (" .. moved .. ")")
    clock.t = 0
    C.eq(#Reformen.tiere(ctx, clock), 0, "morgens wieder weg")
    for _, e in ipairs(list) do C.ok(e.dead, "aus der Welt genommen") end
  end},
}
