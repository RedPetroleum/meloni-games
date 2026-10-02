-- Selbsttests für Käufer (Aufgabe B3): Preise nach Formel, Folgen, Sprüche, Besuch.
local Stage = require("game.stage")
local Wild = require("game.wild")
local Buyers = require("game.buyers")
local Value = require("game.value")
local Clock = require("game.clock")
local Save = require("game.save")
local K = require("game.katalog")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

-- Haflinger (Grundwert 250), Fuchs (häufig ×1), Stats 30/40/35/75.
local function horse(extra)
  local d = H.wild({rng = Rng.new(2), rasse = "haflinger", zug = "faul"})
  d.farbe, d.farbe2, d.alter, d.sex, d.name = "fuchs", "fuchs", 1, "w", "Test"
  d.gen = {tempo = 30, staerke = 40, spuer = 35, ausdauer = 75}
  d.train = {tempo = 0, staerke = 0, spuer = 0, ausdauer = 0}
  d.pot = {tempo = 100, staerke = 100, spuer = 100, ausdauer = 100}
  d.bindung, d.sauberkeit, d.gewicht, d.hunger = 75, 95, 55, 20
  for k, v in pairs(extra or {}) do d[k] = v end
  return d
end

return {
  {"Preise nach Katalog-Formel (Haflinger 30/40/35/75, Bindung 75, Sauberkeit 95, Gewicht 55)", function()
    local d = horse()
    local w, wn = Value.wert_roh(d), Value.wert_neutral(d)
    C.near(wn, 250, 1e-6, "neutral = Durchschnittspferd der Rasse")
    -- Reithof: Wert × (0,6 + (75 − 70)/100)
    C.eq(Buyers.offer("reithof", d), flr(w * 0.65 + 0.5))
    -- Züchter: Wert × (1 + Stammbaum) × 1,05 Stute / 0,95 Hengst
    C.eq(Buyers.offer("zuechter", d), flr(w * 1.05 + 0.5))
    d.sex = "m"
    C.eq(Buyers.offer("zuechter", d), flr(w * 0.95 + 0.5))
    d.ahnen = {v = {id = "V"}, m = {id = "M"}}
    C.eq(Buyers.offer("zuechter", d), flr(Value.wert_roh(d) * 1.1 * 0.95 + 0.5), "Stammbaum zählt doppelt")
    d.ahnen = nil
    -- Schlachter: Wert (neutral) × (1 + 5/20) × (0,9 + 40/400)
    C.eq(Buyers.offer("schlachter", d), flr(250 * 1.25 * 1.0 + 0.5))
    -- Sammlerin: Wert (neutral) × (1 + (1,5 − 1) × 0,15) × Laune
    d.farbe = "palomino"
    local l = Buyers.laune(4)
    C.ok(l >= 0.9 and l <= 1.1, "Laune 0,9–1,1")
    C.eq(Buyers.laune(4), l, "gleicher Tag, gleiche Laune")
    C.eq(Buyers.offer("sammlerin", d, 4), flr(Value.wert_neutral(d) * 1.075 * l + 0.5))
  end},
  {"Bedingungen: Sauberkeit, Bindung, Hunger, Farbe, Gewicht", function()
    local function no(typ, extra, text)
      local p, why = Buyers.offer(typ, horse(extra))
      C.ok(p == nil and why:find(text), typ .. ": " .. text)
    end
    no("sammlerin", {farbe = "palomino", sauberkeit = 90}, "schmutzig")
    no("sammlerin", {farbe = "fuchs"}, "Farbe")
    C.ok(Buyers.offer("sammlerin", horse({farbe = "falbe"})), "gewöhnlich reicht")
    no("reithof", {bindung = 70}, "Bindung")
    no("reithof", {sauberkeit = 50}, "schmutzig")
    no("reithof", {hunger = 30}, "hungrig")
    no("zuechter", {bindung = 50}, "Bindung")
    no("zuechter", {sauberkeit = 50}, "schmutzig")
    no("schlachter", {gewicht = 50}, "leicht")
    C.ok(Buyers.offer("reithof", horse({bindung = 100})) > Buyers.offer("reithof", horse({bindung = 71})) * 1.4,
      "Reithof: Bindung zählt stark")
    C.eq(Buyers.offer("schlachter", horse({bindung = 100})), Buyers.offer("schlachter", horse()), "Schlachter: Bindung egal")
    C.ok(Buyers.offer("schlachter", horse({gewicht = 70})) > Buyers.offer("schlachter", horse()) * 1.5, "Gewicht zählt")
  end},
  {"Verkauf: Geld, Pferd weg, Folgen für die übrigen (nur Schlachter −20)", function()
    for _, case in ipairs({{"reithof", 0}, {"zuechter", 0}, {"schlachter", -20}, {"sammlerin", 0}}) do
      local ctx = Stage.build(1)
      local w = Wild.new(ctx, 3)
      w.count = 0
      local a, b = w:add_own(), w:add_own()
      for _, h in ipairs({a, b}) do
        h.data.bindung, h.data.sauberkeit = 50, 80
        for _, k in ipairs(H.STATS) do h.data.gen[k] = 40 end
      end
      a.data.bindung, a.data.sauberkeit, a.data.hunger, a.data.gewicht, a.data.farbe = 80, 95, 10, 60, "falbe"
      ctx.buyer = {typ = case[1], tag = 1, verkauft = false}
      ctx.money = 10
      local price = Buyers.offer(case[1], a.data, ctx.clock and ctx.clock.day)
      local got = Buyers.sell(ctx, case[1], a.data)
      C.eq(got, price, case[1] .. ": Preis")
      C.eq(ctx.money, 10 + price)
      C.eq(#ctx.herd, 1)
      C.ok(a.dead, "Figur entfernt")
      C.eq(ctx.herd[1].bindung, 50 + case[2], case[1] .. ": Folge")
      C.ok(ctx.buyer.verkauft)
    end
  end},
  {"Verkauf: Sattel, Taschen, Lampe und Schmuck bleiben im Vorrat (Rückmeldung 1.3.1)", function()
    local ctx = Stage.build(1)
    local w = Wild.new(ctx, 3)
    w.count = 0
    local a = w:add_own()
    a.data.sauberkeit, a.data.bindung, a.data.hunger = 80, 80, 10
    a.data.sattel, a.data.taschen, a.data.lampe = "einfacher_sattel", "satteltaschen_s", true
    a.data.schmuck = {blumenkranz = true, goldhufeisen = true}
    C.ok(Buyers.sell(ctx, "reithof", a.data))
    for _, id in ipairs({"einfacher_sattel", "satteltaschen_s", "sattellampe", "blumenkranz", "goldhufeisen"}) do
      C.eq(ctx.inv[id], 1, id)
    end
    local Orders = require("game.orders")
    local b = w:add_own()
    b.data.schmuck = {maehnenschleife = true}
    local o = Orders.for_horse(b.data, 1, "Frau Test")
    ctx.orders = {o}
    C.ok(Orders.deliver(ctx, o, b.data))
    C.eq(ctx.inv.maehnenschleife, 1, "auch beim Liefern")
  end},
  {"Bindung der übrigen Pferde bleibt in 0–100", function()
    local ctx = Stage.build(1)
    local w = Wild.new(ctx, 3)
    w.count = 0
    local a, b = w:add_own(), w:add_own()
    b.data.bindung, a.data.gewicht = 3, 60
    C.ok(Buyers.sell(ctx, "schlachter", a.data))
    C.eq(b.data.bindung, 0)
  end},
  {"Kein Verkauf eines Pferds, das nicht im Bestand ist oder geritten wird", function()
    local ctx = Stage.build(1)
    local w = Wild.new(ctx, 3)
    w.count = 0
    local a = w:add_own()
    local fremd = horse()
    local p, why = Buyers.sell(ctx, "reithof", fremd)
    C.ok(p == nil and why == "nicht im Bestand")
    local Ride = require("game.ride")
    w:attach(a)
    Ride.mount(ctx, a)
    a.data.bindung, a.data.sauberkeit, a.data.hunger = 80, 80, 10
    local p2, why2 = Buyers.sell(ctx, "reithof", a.data)
    C.ok(p2 == nil and why2 == "wird geritten")
    C.eq(#ctx.herd, 1)
  end},
  {"Mehrere Sprüche je Pferdetyp, stabil für dasselbe Pferd, Kategorien passen", function()
    local seen = {}
    for _, typ in ipairs(Buyers.TYPES) do
      local cats = {}
      for _, extra in ipairs({{sex = "m"}, {sex = "w"}, {alter = 0.3}, {farbe = "gold", farbe2 = "gold"}, {sauberkeit = 10},
        {bindung = 90}, {bindung = 10}, {gewicht = 80}, {gewicht = 20}}) do
        local d = horse(extra)
        d.gen.tempo, d.gen.staerke = extra.sex == "m" and 70 or 30, 40
        d.bindung = extra.bindung or 50
        local text, cat = Buyers.spruch(typ, d, 5)
        C.ok(#text > 10, "Spruch")
        C.ok(not text:find("[{|}]"), "Geschlechtsform aufgelöst: " .. text)
        C.eq(Buyers.spruch(typ, d, 5), text, "stabil")
        cats[cat] = true
        seen[text] = true
      end
      local n = 0
      for _ in pairs(cats) do n = n + 1 end
      C.ok(n >= 3, typ .. ": mindestens 3 Pferdetypen, " .. n)
    end
    local total = 0
    for _ in pairs(seen) do total = total + 1 end
    C.ok(total >= 15, "viele verschiedene Sprüche: " .. total)
  end},
  {"Täglich ein zufälliger Käufer aus Seed und Tag, alle vier kommen vor", function()
    local counts = {}
    for day = 21, 420 do counts[Buyers.visit(11, day).typ] = (counts[Buyers.visit(11, day).typ] or 0) + 1 end
    for _, t in ipairs(Buyers.TYPES) do C.between(counts[t], 70, 130, t) end
    C.eq(Buyers.visit(11, 7).typ, Buyers.visit(11, 7).typ)
    local other = 0
    for day = 21, 60 do if Buyers.visit(11, day).typ ~= Buyers.visit(12, day).typ then other = other + 1 end end
    C.ok(other > 10, "anderer Seed, andere Folge")
  end},
  {"Figur am Hoftor tagsüber, nachts und nach dem Verkauf weg; im Spielstand", function()
    local ctx = Stage.build(1, 4)
    Wild.new(ctx, 3)
    ctx.buyer = Buyers.visit(4, 11)
    Buyers.sync(ctx, false)
    C.ok(ctx.buyer_ent and not ctx.buyer_ent.dead, "da")
    local e = ctx.buyer_ent
    Buyers.sync(ctx, false)
    C.eq(ctx.buyer_ent, e, "nicht doppelt")
    Buyers.sync(ctx, true)
    C.ok(e.dead and ctx.buyer_ent == nil, "nachts weg")
    Buyers.sync(ctx, false)
    C.ok(ctx.buyer_ent ~= nil)
    ctx.buyer.verkauft = true
    Buyers.sync(ctx, false)
    C.eq(ctx.buyer_ent, nil, "nach dem Verkauf weg")
    ctx.buyer = Buyers.visit(4, 12)
    local snap = Save.snapshot(ctx, Clock.new(2, 0), 4)
    local back = load("return " .. Save.encode(snap), "=x", "t", {})()
    C.eq(back.kaeufer.typ, ctx.buyer.typ)
    local Screens = require("game.screens")
    Wild.new(ctx, 3):add_own({name = "Hilde"})
    Screens.buyer(ctx).draw()
  end},
}
