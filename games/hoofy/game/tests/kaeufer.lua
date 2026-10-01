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
  d.bindung, d.sauberkeit, d.gewicht = 50, 70, 50
  for k, v in pairs(extra or {}) do d[k] = v end
  return d
end

return {
  {"Preise nach Katalog-Formel (Haflinger/Fuchs 30/40/35/75, Bindung 50, Gewicht 50)", function()
    local d = horse()
    -- Leistung (30 + 40 + 35 + 25 × 2) / 400 = 0,3875; Wert 250 × 1 × 0,8875... (0,5 + 0,3875) = 221,875
    C.near(Value.wert_roh(d), 221.875, 0.05)
    -- Sammlerin: Wert × Farbfaktor × 1,5 (nur ab Sauberkeit 70)
    C.eq(Buyers.offer("sammlerin", d), flr(221.875 * 1 * 1.5 + 0.5))
    -- Reithof: Wert × 0,7 × (0,5 + Bindung/100) = 221,875 × 0,7 × 1,0
    C.eq(Buyers.offer("reithof", d), flr(221.875 * 0.7 + 0.5))
    -- Züchter: Wert × (1 + (30 + 40 + 25 × 2)/300) = 221,875 × 1,4
    C.eq(Buyers.offer("zuechter", d), flr(221.875 * (1 + 120 / 300) + 0.5))
    -- Hengst ×1,5
    d.sex = "m"
    C.eq(Buyers.offer("zuechter", d), flr(221.875 * (1 + 120 / 300) * 1.5 + 0.5))
    -- Schlachter: 5 × 50² / 50 + 250 × 0,3 = 250 + 75
    C.eq(Buyers.offer("schlachter", d), 325)
  end},
  {"Bedingungen und Gewichtung: Sammlerin nur ab Sauberkeit 70, Reithof mag Bindung, Schlachter Gewicht", function()
    local d = horse({sauberkeit = 69})
    local p, why = Buyers.offer("sammlerin", d)
    C.ok(p == nil and why:find("schmutzig"), "zu schmutzig")
    d.sauberkeit = 70
    C.ok(Buyers.offer("sammlerin", d))
    local lo, hi = horse({bindung = 0}), horse({bindung = 100})
    C.ok(Buyers.offer("reithof", hi) > Buyers.offer("reithof", lo) * 2, "hohe Bindung zahlt viel mehr")
    local duenn, dick = horse({gewicht = 30}), horse({gewicht = 80})
    C.ok(Buyers.offer("schlachter", dick) > Buyers.offer("schlachter", duenn) * 3, "Gewicht zählt quadratisch")
    local rare = horse({farbe = "palomino", farbe2 = "palomino"})       -- selten ×2
    C.ok(Buyers.offer("sammlerin", rare) > Buyers.offer("sammlerin", horse()) * 3, "Seltenheit zählt doppelt")
  end},
  {"Verkauf: Geld, Pferd weg, Folgen für die übrigen (+5 Reithof, −5 Züchter, −10 Schlachter, 0 Sammlerin)", function()
    for _, case in ipairs({{"reithof", 5}, {"zuechter", -5}, {"schlachter", -10}, {"sammlerin", 0}}) do
      local ctx = Stage.build(1)
      local w = Wild.new(ctx, 3)
      w.count = 0
      local a, b = w:add_own(), w:add_own()
      for _, h in ipairs({a, b}) do
        h.data.bindung, h.data.sauberkeit = 50, 80
        for _, k in ipairs(H.STATS) do h.data.gen[k] = 40 end
      end
      ctx.buyer = {typ = case[1], tag = 1, verkauft = false}
      ctx.money = 10
      local price = Buyers.offer(case[1], a.data)
      local got = Buyers.sell(ctx, case[1], a.data)
      C.eq(got, price, case[1] .. ": Preis")
      C.eq(ctx.money, 10 + price)
      C.eq(#ctx.herd, 1)
      C.ok(a.dead, "Figur entfernt")
      C.eq(ctx.herd[1].bindung, 50 + case[2], case[1] .. ": Folge")
      C.ok(ctx.buyer.verkauft)
    end
  end},
  {"Bindung der übrigen Pferde bleibt in 0–100", function()
    local ctx = Stage.build(1)
    local w = Wild.new(ctx, 3)
    w.count = 0
    local a, b = w:add_own(), w:add_own()
    b.data.bindung = 3
    Buyers.sell(ctx, "schlachter", a.data)
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
        local text, cat = Buyers.spruch(typ, d, 5)
        C.ok(#text > 10, "Spruch")
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
