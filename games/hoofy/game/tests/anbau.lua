-- Selbsttests für den Anbau (Aufgabe C5): Beete, Pflanzen, Wachstum über Tage, Ernte, Futter.
local Stage = require("game.stage")
local Area = require("game.area")
local Wild = require("game.wild")
local Farm = require("game.farm")
local Care = require("game.care")
local Days = require("game.days")
local H = require("game.horse_model")
local K = require("game.katalog")
local Rng = require("lib.rng")
local Economy = require("game.economy")
local C = require("game.tests.check")

local function setup()
  Area.clear()
  local ctx = Stage.build(1, 10)
  ctx.money = 10000
  local p = ctx.area.plot
  ctx.player.x, ctx.player.y = (p.x + 10) * 16 + 8, (p.y + 8) * 16 + 8
  ctx.wild = Wild.new(ctx, 3)
  ctx.wild.count = 0
  ctx.clock = {day = 1}
  for _, pf in ipairs(K.futter.anbau) do ctx.inv["samen_" .. pf.id] = 20 end
  ctx.inv.hacke = 1
  return ctx, p
end

local function beds(ctx, x0, y0, w, h)
  for x = x0, x0 + w - 1 do
    for y = y0, y0 + h - 1 do
      local ok, why = Farm.place(ctx, "beet", x, y)
      if not ok then error("Beet " .. x .. "," .. y .. ": " .. tostring(why)) end
    end
  end
end

local function day(ctx, d)
  ctx.clock.day = d
  Farm.grow(ctx, d)
end

return {
  {"Beet/Feld kostet nichts, braucht aber die Hacke, ändert den Boden, Abreißen stellt das Gras her", function()
    local ctx, p = setup()
    ctx.inv.hacke = 0
    local ok, why = Farm.place(ctx, "beet", p.x + 13, p.y + 5)
    C.ok(not ok and why == "erst eine Hacke kaufen", tostring(why))
    C.eq(ctx.map:code(p.x + 13, p.y + 5), ".")
    ctx.inv.hacke = 1
    local m = ctx.money
    C.ok(Farm.place(ctx, "beet", p.x + 13, p.y + 5))
    C.eq(ctx.money, m)
    C.eq(ctx.map:code(p.x + 13, p.y + 5), "b")
    C.ok(not Farm.ITEMS.feld, "Feld gibt es nicht mehr, nur Beet")
    C.ok(ctx.map:walkable(p.x + 13, p.y + 5), "Beete sind begehbar")
    C.eq(Farm.remove(ctx, p.x + 13, p.y + 5), 0)
    C.eq(ctx.map:code(p.x + 13, p.y + 5), ".")
    C.eq(K.futter.beet_preis, 0)
    C.eq(Economy.find("hacke").kat, "zubehoer")
  end},
  {"Pflanzen: nur mit Samen, nur auf Beeten, nichts doppelt, Apfelbaum 2×2 auch auf Gras", function()
    local ctx, p = setup()
    ctx.inv.samen_karotte = 0
    beds(ctx, p.x + 13, p.y + 5, 3, 3)
    local ok, why = Farm.plant(ctx, "karotte", p.x + 13, p.y + 5)
    C.ok(not ok and why == "kein Samen")
    ctx.inv.samen_karotte = 1
    ok, why = Farm.plant(ctx, "karotte", p.x + 12, p.y + 5)
    C.ok(not ok and why == "braucht Beet", "Gras")
    C.ok(Farm.plant(ctx, "karotte", p.x + 13, p.y + 5))
    ok, why = Farm.plant(ctx, "gras", p.x + 13, p.y + 5)
    C.ok(not ok and why == "schon bepflanzt")
    ok, why = Farm.plant(ctx, "apfelbaum", p.x + 14, p.y + 5)
    C.ok(ok, "2×2 auf freien Beeten: " .. tostring(why))
    ok, why = Farm.plant(ctx, "apfelbaum", p.x + 15, p.y + 7)
    C.ok(ok, "Apfelbaum halb auf Beet, halb auf Gras: " .. tostring(why))
    ok, why = Farm.plant(ctx, "apfelbaum", p.x + 16, p.y + 14)
    C.ok(ok, "Apfelbaum auf Gras ohne Beet: " .. tostring(why))
    ok, why = Farm.plant(ctx, "apfelbaum", p.x + 8, p.y + 3)
    C.ok(not ok, "nicht im Stall")
    C.ok(not Farm.plant(ctx, "apfelbaum", p.x + p.w - 1, p.y + 5), "nicht über das Grundstück hinaus")
    -- jedes Pflanzen verbraucht einen Samen
    C.eq(ctx.inv.samen_karotte, 0, "Samen verbraucht")
    beds(ctx, p.x + 13, p.y + 8, 3, 1)
    ok, why = Farm.plant(ctx, "karotte", p.x + 13, p.y + 8)
    C.ok(not ok and why == "kein Samen", "zweites Feld braucht einen neuen Samen")
    ctx.inv.samen_karotte = 2
    C.ok(Farm.plant(ctx, "karotte", p.x + 13, p.y + 8))
    C.ok(Farm.plant(ctx, "karotte", p.x + 14, p.y + 8))
    C.eq(ctx.inv.samen_karotte, 0)
  end},
  {"Wachstum über Tage nach Katalog: Karotte reif nach 2, dann alle 2; Gras täglich; Apfelbaum 4 / 3", function()
    local ctx, p = setup()
    beds(ctx, p.x + 13, p.y + 5, 4, 3)
    Farm.plant(ctx, "karotte", p.x + 13, p.y + 5, 1)
    Farm.plant(ctx, "gras", p.x + 14, p.y + 5, 1)
    Farm.plant(ctx, "apfelbaum", p.x + 15, p.y + 5, 1)
    local karotte, gras, apfel = Farm.plant_at(ctx.area.farm, p.x + 13, p.y + 5), Farm.plant_at(ctx.area.farm, p.x + 14, p.y + 5),
      Farm.plant_at(ctx.area.farm, p.x + 15, p.y + 5)
    C.eq(karotte.stufe, 1)
    day(ctx, 2)
    C.eq(gras.stufe, 3, "Gras reif nach 1 Tag")
    C.eq(karotte.stufe, 2, "Karotte halbreif")
    day(ctx, 3)
    C.eq(karotte.stufe, 3, "Karotte reif nach 2 Tagen")
    C.eq(apfel.stufe, 2, "Apfelbaum nach 2 von 4 Tagen")
    day(ctx, 5)
    C.eq(apfel.stufe, 3, "Apfelbaum reif nach 4 Tagen")
    -- Ernte: Karotte 1, Gras 1 Heu, Apfelbaum 3 Äpfel
    local c0, h0 = ctx.inv.karotte, ctx.inv.heu
    local item, n = Farm.harvest(ctx, karotte, 5)
    C.ok(item == "karotte" and n == 1)
    C.eq(ctx.inv.karotte, c0 + 1)
    item, n = Farm.harvest(ctx, gras, 5)
    C.ok(item == "heu" and n == 1)
    C.eq(ctx.inv.heu, h0 + 1, "Gras gibt Heu")
    item, n = Farm.harvest(ctx, apfel, 5)
    C.ok(item == "apfel" and n == 3)
    C.eq(ctx.inv.apfel, 3)
    C.eq(apfel.stufe, 1, "nach der Ernte von vorn")
    C.eq(apfel.bereit, 8, "dann alle 3 Tage")
    C.eq(karotte.bereit, 7, "Karotte alle 2 Tage")
    C.eq(gras.bereit, 6)
    local no, why = Farm.harvest(ctx, apfel, 6)
    C.ok(no == nil and why == "noch nicht reif")
    day(ctx, 6); day(ctx, 7); day(ctx, 8)
    C.eq(apfel.stufe, 3)
    C.eq(karotte.stufe, 3)
  end},
  {"Ernte per A: nur reife Pflanzen in Reichweite", function()
    local ctx, p = setup()
    beds(ctx, p.x + 10, p.y + 8, 2, 1)
    Farm.plant(ctx, "gras", p.x + 10, p.y + 8, 1)
    Farm.plant(ctx, "karotte", p.x + 11, p.y + 8, 1)
    ctx.player.x, ctx.player.y = (p.x + 10) * 16 + 8, (p.y + 9) * 16 + 4
    C.eq(Farm.ripe_near(ctx), nil, "noch nichts reif")
    day(ctx, 2)
    local r = Farm.ripe_near(ctx)
    C.ok(r and r.id == "gras", "Gras reif und nah")
    ctx.player.x = (p.x + 3) * 16
    C.eq(Farm.ripe_near(ctx), nil, "zu weit weg")
  end},
  {"Ernte als Futter: Wirkung nach Katalog, Minze bei eitel doppelt, Drachenfrucht Training ×2, goldene Karotte Fohlen-Potenzial", function()
    local function horse(zug, alter)
      local d = H.wild({rng = Rng.new(2), rasse = "haflinger", zug = zug})
      for _, k in ipairs(H.STATS) do d.gen[k], d.train[k], d.pot[k] = 40, 0, 60 end
      d.bindung, d.hunger, d.sauberkeit, d.gewicht, d.energie, d.alter = 50, 80, 50, 50, 30, alter or 1
      d.gen.ausdauer = 90
      return d
    end
    local d = horse("faul")
    Care.feed(d, "apfel")                       -- Hunger −8, Bindung +4
    C.eq(d.hunger, 72)
    C.eq(d.bindung, 50 + 1 + 4)
    d = horse("faul")
    Care.feed(d, "sonnenblumenkerne")           -- Hunger −10, Sauberkeit +10
    C.eq(d.hunger, 70)
    C.eq(d.sauberkeit, 60)
    d = horse("faul"); Care.feed(d, "minze")    -- Bindung +2
    C.eq(d.bindung, 53)
    d = horse("eitel"); Care.feed(d, "minze")   -- Bindung +2 × 2
    C.eq(d.bindung, 55)
    d = horse("faul"); Care.feed(d, "zuckerruebe")   -- Hunger −20, Energie +25
    C.eq(d.hunger, 60)
    C.eq(d.energie, 55)
    d = horse("faul"); Care.feed(d, "luzerne")       -- Hunger −35, Gewicht +2
    C.eq(d.hunger, 45)
    C.eq(d.gewicht, 52)
    d = horse("faul"); Care.feed(d, "drachenfrucht")
    C.eq(d.hunger, 65)
    C.eq(d.boost, 1)
    local Care2 = require("game.care")
    local a = horse("faul")
    local g1 = Care2.training_gain(a, "tempo", 2)
    a.boost = 1
    C.near(Care2.training_gain(a, "tempo", 2), g1 * 2, 1e-6, "Training ×2")
    local fohlen = horse("faul", 0.3)
    Care.feed(fohlen, "goldene_karotte")
    C.eq(fohlen.pot.tempo, 62, "Max-Potenzial +2")
    Care.feed(fohlen, "premiumfutter")
    C.eq(fohlen.pot.tempo, 64, "zusammen mit Premiumfutter bis +10")
    local alt = horse("faul")
    Care.feed(alt, "goldene_karotte")
    C.eq(alt.pot.tempo, 60, "Erwachsene unverändert")
  end},
  {"Drachenfrucht-Tag: Boost gilt einen Tag, danach weg", function()
    local ctx, p = setup()
    local h = ctx.wild:add_own({name = "Test"})
    Care.feed(h.data, "drachenfrucht")
    C.eq(h.data.boost, 1)
    Days.new_day(ctx, 2)
    C.eq(h.data.boost, 0, "nach dem Tageswechsel zu Ende")
  end},
  {"Sonnenblume ist Deko: Schönheit +2 je Pflanze; Abreißen einer Pflanze lässt das Beet", function()
    local ctx, p = setup()
    beds(ctx, p.x + 13, p.y + 5, 3, 1)
    local m = ctx.money
    Farm.plant(ctx, "sonnenblume", p.x + 13, p.y + 5, 1)
    Farm.plant(ctx, "sonnenblume", p.x + 14, p.y + 5, 1)
    Farm.plant(ctx, "karotte", p.x + 15, p.y + 5, 1)
    C.eq(Farm.schoenheit(ctx.area.farm), 4, "2 Sonnenblumen (Karotten zählen nicht)")
    C.eq(Farm.remove(ctx, p.x + 13, p.y + 5), 0, "Pflanze weg, kein Geld zurück")
    C.eq(ctx.map:code(p.x + 13, p.y + 5), "b", "Beet bleibt")
    C.eq(Farm.schoenheit(ctx.area.farm), 2)
    C.eq(ctx.inv.samen_sonnenblume, 18, "kein Samen zurück")
    C.eq(Farm.remove(ctx, p.x + 13, p.y + 5), 0, "zweiter Abriss: das Beet (kostenlos)")
    C.eq(ctx.money, m)
  end},
  {"Spielstand: Pflanzen mit Wachstumsstand bleiben, Bilder kommen beim Laden wieder", function()
    local Save = require("game.save")
    local Clock = require("game.clock")
    local ctx, p = setup()
    beds(ctx, p.x + 13, p.y + 5, 3, 1)
    Farm.plant(ctx, "karotte", p.x + 13, p.y + 5, 1)
    Farm.plant(ctx, "gras", p.x + 14, p.y + 5, 1)
    day(ctx, 2)
    local snap = Save.snapshot(ctx, Clock.new(2, 0), 10)
    local text = Save.encode(snap)
    local back = load("return " .. text, "=x", "t", {})()
    Area.clear()
    local ctx2 = Stage.build(1, 10, back.hof)
    C.eq(#ctx2.area.farm.pflanzen, 2)
    C.eq(ctx2.map:code(p.x + 13, p.y + 5), "b")
    local k = Farm.plant_at(ctx2.area.farm, p.x + 13, p.y + 5)
    C.eq(k.stufe, 2)
    local found = false
    for b = 1, ctx2.map.bw * ctx2.map.bh do
      for _, o in ipairs(ctx2.map.blocks[b] or {}) do if o[1] == "pflanze_gras_3" then found = true end end
    end
    C.ok(found, "reifes Gras wieder sichtbar")
    log("ANBAU Spielstand mit 2 Pflanzen und 3 Beeten: " .. #text .. " Bytes")
  end},
  {"Alter Spielstand mit Feldern (bis 1.3.1): werden beim Laden zu Beeten, bepflanzt bleibt bepflanzt", function()
    local Save = require("game.save")
    local Clock = require("game.clock")
    local ctx, p = setup()
    beds(ctx, p.x + 13, p.y + 5, 2, 1)
    Farm.plant(ctx, "karotte", p.x + 14, p.y + 5, 1)
    Farm.item_at(ctx.area.farm, p.x + 14, p.y + 5).id = "feld"   -- so stand es in alten Spielständen
    local back = load("return " .. Save.encode(Save.snapshot(ctx, Clock.new(2, 0), 10)), "=x", "t", {})()
    Area.clear()
    local ctx2 = Stage.build(1, 10, back.hof)
    for _, it in ipairs(ctx2.area.farm.items) do C.ok(it.id ~= "feld", "kein Feld mehr") end
    C.eq(Farm.item_at(ctx2.area.farm, p.x + 14, p.y + 5).id, "beet")
    C.eq(ctx2.map:code(p.x + 14, p.y + 5), "b")
    C.ok(Farm.plant_at(ctx2.area.farm, p.x + 14, p.y + 5), "Karotte noch da")
    ctx2.money, ctx2.inv = 0, {}
    C.eq(Farm.remove(ctx2, p.x + 13, p.y + 5), 0, "abreißbar")
    C.ok(Farm.schoenheit(ctx2.area.farm) >= 0)
  end},
  {"Baumodus: Pflanzen-Reiter zeigt gekaufte Samen, Pflanzen per A", function()
    local Screens = require("game.screens")
    local ctx, p = setup()
    ctx.player.x, ctx.player.y = (p.x + 10) * 16 + 8, (p.y + 8) * 16 + 8
    for _, pf in ipairs(K.futter.anbau) do ctx.inv["samen_" .. pf.id] = 0 end
    ctx.inv.samen_hafer = 1
    local cats = Farm.categories(ctx)
    local pf
    for _, c in ipairs(cats) do if c.id == "pflanzen" then pf = c end end
    C.eq(#pf.items, 1)
    C.eq(pf.items[1], "hafer")
    local b = Screens.build(ctx)
    b.draw()
  end},
  {"Apfelbaum bleibt nach der Ernte groß: erst ohne, dann mit grünen Äpfeln (Rückmeldung 1.3.3)", function()
    local ctx, p = setup()
    Farm.plant(ctx, "apfelbaum", p.x + 15, p.y + 5, 1)
    local a = Farm.plant_at(ctx.area.farm, p.x + 15, p.y + 5)
    local function bild()
      for b = 1, ctx.map.bw * ctx.map.bh do
        for _, o in ipairs(ctx.map.blocks[b] or {}) do if o[1]:find("^pflanze_apfelbaum") then return o[1] end end
      end
    end
    C.eq(bild(), "pflanze_apfelbaum_1", "Setzling")
    day(ctx, 5)
    C.eq(bild(), "pflanze_apfelbaum_3")
    Farm.harvest(ctx, a, 5)
    C.eq(bild(), "pflanze_apfelbaum_leer", "groß, ohne Äpfel")
    day(ctx, 7)
    C.eq(bild(), "pflanze_apfelbaum_gruen", "grüne Äpfel")
    day(ctx, 8)
    C.eq(bild(), "pflanze_apfelbaum_3", "wieder reif")
    -- alter Spielstand: schon geernteter Baum ohne gross
    Farm.harvest(ctx, a, 8)
    a.gross = nil
    local Save = require("game.save")
    local Clock = require("game.clock")
    local back = load("return " .. Save.encode(Save.snapshot(ctx, Clock.new(8, 0), 10)), "=x", "t", {})()
    Area.clear()
    local ctx2 = Stage.build(1, 10, back.hof)
    C.ok(Farm.plant_at(ctx2.area.farm, p.x + 15, p.y + 5).gross, "beim Laden erkannt")
  end},
}
