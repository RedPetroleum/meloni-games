-- Selbsttests für Pferdewert und Pferdemarkt (Aufgabe B2).
local Stage = require("game.stage")
local Wild = require("game.wild")
local Value = require("game.value")
local Market = require("game.market")
local Clock = require("game.clock")
local Save = require("game.save")
local K = require("game.katalog")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local function horse(rasse, farbe, t, s, sp, a, alter)
  local d = H.wild({rng = Rng.new(2), rasse = rasse})
  d.farbe, d.farbe2, d.alter = farbe, farbe, alter or 1
  d.gen = {tempo = t, staerke = s, spuer = sp, ausdauer = a}
  d.train = {tempo = 0, staerke = 0, spuer = 0, ausdauer = 0}
  d.pot = {tempo = 100, staerke = 100, spuer = 100, ausdauer = 100}
  return d
end

return {
  {"Wert nach Formel: Shetlandpony/Brauner Basiswerte = 126 G, Kauf 163 G", function()
    -- Leistung (15 + 35 + 45 + 20 × 2) / 400 = 0,3375; 150 × 1 × 0,8375 = 125,625
    local d = horse("shetlandpony", "brauner", 15, 35, 45, 70)
    C.near(Value.leistung(d), 0.3375, 1e-6)
    C.near(Value.wert_roh(d), 125.625, 1e-3)
    C.eq(Value.wert(d), 126)
    C.eq(Value.kaufpreis(d), 188, "125,625 × 1,5 = 188,4")
  end},
  {"Farbfaktor, Fohlen ×0,6, Training zählt, Einhorn Gold", function()
    local a = horse("haflinger", "fuchs", 30, 40, 35, 75)           -- häufig ×1
    local b = horse("haflinger", "palomino", 30, 40, 35, 75)        -- selten ×2
    C.near(Value.wert_roh(b), Value.wert_roh(a) * 2, 1e-6, "selten ×2")
    local c = horse("haflinger", "fuchs", 30, 40, 35, 75, 0.5)
    C.near(Value.wert_roh(c), Value.wert_roh(a) * 0.6, 1e-6, "Fohlen")
    a.train.tempo = 20
    C.ok(Value.wert_roh(a) > Value.wert_roh(c) / 0.6, "Training erhöht den Wert")
    local e = horse("einhorn", "gold", 80, 50, 70, 90)              -- legendär ×10
    -- Leistung 280/400 = 0,7; 10000 × 10 × 1,2
    C.near(Value.wert_roh(e), 120000, 1)
  end},
  {"Markt: 4 Pferde, gleicher Seed und Zyklus = gleiche Auswahl, neue Auswahl alle 3 Tage", function()
    local a, b = Market.stock(5, 0, 1), Market.stock(5, 0, 1)
    C.eq(#a.horses, 4)
    for i = 1, 4 do
      C.eq(a.horses[i].name, b.horses[i].name)
      C.eq(a.horses[i].preis, b.horses[i].preis)
      C.eq(a.horses[i].farbe, b.horses[i].farbe)
    end
    local c = Market.stock(5, 1, 1)
    local same = 0
    for i = 1, 4 do if c.horses[i].name == a.horses[i].name and c.horses[i].farbe == a.horses[i].farbe then same = same + 1 end end
    C.ok(same < 4, "anderer Zyklus, andere Pferde")
    local ctx = Stage.build(1)
    local m1 = Market.refresh(ctx, 1)
    C.eq(Market.refresh(ctx, 2), m1, "Tag 2 gleicher Bestand")
    C.eq(Market.refresh(ctx, 3), m1, "Tag 3")
    C.ok(Market.refresh(ctx, 4) ~= m1, "Tag 4 neue Auswahl")
  end},
  {"Preise auf dem Markt: Wert × 1,5; Gebiet 1 nur Rassen aus Gebiet 1, weiter weg auch spätere", function()
    local m = Market.stock(9, 0, 1)
    for _, d in ipairs(m.horses) do
      C.eq(d.preis, Value.kaufpreis(d))
      C.eq(K.rasse(d.rasse).gebiet, 1, "Gebiet 1")
    end
    local seen = {}
    for cycle = 0, 40 do
      for _, d in ipairs(Market.stock(3, cycle, 4).horses) do seen[K.rasse(d.rasse).gebiet] = true end
    end
    C.ok(seen[1] and seen[2] and seen[3] and seen[4], "Gebiet 1–4 vertreten")
    C.ok(not seen[5], "Gebiet 5 nicht erreichbar")
  end},
  {"Kaufen: Geld ab, Pferd im Bestand und an der Leine; zu wenig Geld und volle Herde gehen nicht", function()
    local ctx = Stage.build(1)
    Wild.new(ctx, 3).count = 0
    Market.refresh(ctx, 1)
    local d = ctx.market.horses[1]
    local price, name = d.preis, d.name
    ctx.money = price - 1
    local ok, why = Market.buy(ctx, 1)
    C.ok(not ok and why == "Geld")
    C.eq(#ctx.herd, 0)
    ctx.money = price + 50
    local ok2, h = Market.buy(ctx, 1)
    C.ok(ok2)
    C.eq(ctx.money, 50)
    C.eq(#ctx.market.horses, 3, "weg vom Markt")
    C.eq(#ctx.herd, 1)
    C.eq(ctx.herd[1].name, name)
    C.ok(h.state == "led" or h.state == "follow", "an der Leine")
    C.eq(ctx.herd[1].preis, nil)
    -- Obergrenze 24
    ctx.money = 1e6
    while #ctx.herd < Market.MAX_HERD do ctx.wild:add_own() end
    local ok3, why3 = Market.buy(ctx, 1)
    C.ok(not ok3 and why3 == "voll")
  end},
  {"Markt im Spielstand: nach dem Laden dieselben Pferde, Screens zeichnen", function()
    local ctx = Stage.build(1, 11)
    Market.refresh(ctx, 7)
    local snap = Save.snapshot(ctx, Clock.new(7, 0), 11)
    local back = load("return " .. Save.encode(snap), "=x", "t", {})()
    C.eq(back.markt.cycle, 2)
    C.eq(#back.markt.horses, 4)
    C.eq(back.markt.horses[1].name, ctx.market.horses[1].name)
    local Screens = require("game.screens")
    ctx.money = 100
    Screens.market(ctx).draw()
    ctx.market.horses = {}
    Screens.market(ctx).draw()
    local d = horse("haflinger", "fuchs", 30, 40, 35, 75)
    Screens.info(ctx, d).draw()
  end},
}
