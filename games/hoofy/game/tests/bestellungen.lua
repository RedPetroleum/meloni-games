-- Selbsttests für Bestellungen (Aufgabe B4): Erzeugen, Erfüllen, Verfallen.
local Stage = require("game.stage")
local Wild = require("game.wild")
local Orders = require("game.orders")
local Value = require("game.value")
local Clock = require("game.clock")
local Save = require("game.save")
local K = require("game.katalog")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local function horse(extra)
  local d = H.wild({rng = Rng.new(2), rasse = "haflinger", zug = "faul"})
  d.farbe, d.farbe2, d.alter, d.sex, d.name = "fuchs", "fuchs", 1, "w", "Test"
  d.gen = {tempo = 55, staerke = 40, spuer = 35, ausdauer = 75}
  d.train = {tempo = 0, staerke = 0, spuer = 0, ausdauer = 0}
  d.pot = {tempo = 100, staerke = 100, spuer = 100, ausdauer = 100}
  for k, v in pairs(extra or {}) do d[k] = v end
  return d
end

local function ctx_new()
  local ctx = Stage.build(1, 5)
  Wild.new(ctx, 3).count = 0
  ctx.money = 100
  return ctx
end

return {
  {"Erzeugen: deterministisch, Frist 5–10 Tage, Farbe aus der Matrix einer erreichbaren Rasse", function()
    local a, b = Orders.generate(5, 4, 1), Orders.generate(5, 4, 1)
    C.eq(a.farbe, b.farbe)
    C.eq(a.kunde, b.kunde)
    C.eq(a.min, b.min)
    local fristen, stats = {}, {}
    for day = 1, 300, 3 do
      local o = Orders.generate(5, day, 1)
      local left = o.frist - o.erstellt
      C.between(left, 5, 10, "Frist")
      fristen[left] = true
      stats[o.stat] = true
      local found = false
      for _, r in ipairs(K.rassen.liste) do
        if r.gebiet <= 1 then
          for _, tier in ipairs(K.farben.matrix[r.id]) do
            for _, f in ipairs(tier) do if f == o.farbe then found = true end end
          end
        end
      end
      C.ok(found, "Farbe " .. o.farbe .. " kommt in Gebiet 1 vor")
      C.ok(o.sex == "m" or o.sex == "w")
      C.between(o.min, 40, 80, "Mindestwert")
    end
    C.ok(fristen[5] and fristen[10], "alle Fristen kommen vor")
    local n = 0
    for _ in pairs(stats) do n = n + 1 end
    C.eq(n, 4, "alle vier Stats")
  end},
  {"Tick: alle 3 Tage eine Bestellung (Tag 1, 4, 7 …), Verfall nach der Frist", function()
    local ctx = ctx_new()
    local neu = 0
    for day = 1, 30 do
      local r = Orders.tick(ctx, day)
      if r.neu then neu = neu + 1 end
      C.eq(r.neu ~= nil, (day - 1) % 3 == 0, "Tag " .. day)
      for _, o in ipairs(ctx.orders) do C.ok(day <= o.frist, "verfallene Bestellung noch offen an Tag " .. day) end
      C.ok(#ctx.orders <= 4, "höchstens 4 offen")
    end
    C.eq(neu, 10)
    local ctx2 = ctx_new()
    Orders.tick(ctx2, 1)
    local o = ctx2.orders[1]
    local r = Orders.tick(ctx2, o.frist + 1)
    local expired = false
    for _, e in ipairs(r.verfallen) do if e == o then expired = true end end
    C.ok(expired, "Bestellung verfallen")
  end},
  {"Passen: Farbe, Geschlecht und Mindestwert müssen stimmen", function()
    local o = {kunde = "X", farbe = "fuchs", sex = "w", stat = "tempo", min = 50, erstellt = 1, frist = 9}
    C.ok(Orders.matches(o, horse()))
    C.ok(not Orders.matches(o, horse({farbe = "rappe"})), "Farbe")
    C.ok(not Orders.matches(o, horse({sex = "m"})), "Geschlecht")
    local schwach = horse()
    schwach.gen.tempo = 49
    C.ok(not Orders.matches(o, schwach), "Tempo 49 < 50")
    schwach.train.tempo = 1
    C.ok(Orders.matches(o, schwach), "Training zählt mit")
    o.stat = "ausdauer"
    o.min = 76
    C.ok(not Orders.matches(o, horse()))
  end},
  {"Liefern: Wert × 1,5, Pferd weg, Bestellung erledigt; falsches Pferd wird abgelehnt", function()
    local ctx = ctx_new()
    local w = ctx.wild
    local a, b = w:add_own({name = "Hilde"}), w:add_own({name = "Bruno"})
    a.data.farbe, a.data.sex = "fuchs", "w"
    b.data.farbe, b.data.sex = "rappe", "m"
    local o = Orders.for_horse(a.data, 1, "Frau Schmitt")
    ctx.orders = {o}
    local p, why = Orders.deliver(ctx, o, b.data)
    C.ok(p == nil and why == "passt nicht")
    C.eq(#ctx.herd, 2)
    local sum = Orders.deliver(ctx, o, a.data)
    C.eq(sum, flr(Value.wert_roh(a.data) * 1.5 + 0.5))
    C.ok(a.dead)
    C.eq(ctx.money, 100 + sum)
    C.eq(#ctx.herd, 1)
    C.eq(#ctx.orders, 0, "erledigt")
    local p2, why2 = Orders.deliver(ctx, o, a.data)
    C.ok(p2 == nil, "nicht zweimal")
  end},
  {"Text der Bestellung und Bildschirme, Spielstand", function()
    local o = {kunde = "Frau Schmitt", farbe = "brauner", sex = "w", stat = "tempo", min = 50, erstellt = 10, frist = 20}
    C.eq(Orders.text(o), "Braune Stute, Geschwindigkeit über 50, bis Tag 20")
    o.farbe, o.sex, o.stat = "palomino", "m", "staerke"
    C.eq(Orders.text(o), "Palomino-Hengst, Stärke über 50, bis Tag 20")
    for _, f in ipairs(K.farben.liste) do
      C.ok(#Orders.text({farbe = f.id, sex = "w", stat = "spuer", min = 5, frist = 3}) > 20, f.id)
    end
    local ctx = ctx_new()
    local a = ctx.wild:add_own({name = "Hilde"})
    ctx.orders = {Orders.for_horse(a.data, 1), Orders.generate(5, 4, 1)}
    local snap = Save.snapshot(ctx, Clock.new(2, 0), 5)
    local back = load("return " .. Save.encode(snap), "=x", "t", {})()
    C.eq(#back.bestellungen, 2)
    C.eq(back.bestellungen[1].farbe, a.data.farbe)
    local Screens = require("game.screens")
    Screens.orders(ctx).draw()
    local nav = {stack = {}}
    function nav.push(s) nav.stack[#nav.stack + 1] = s end
    function nav.pop() nav.stack[#nav.stack] = nil end
    local sc = Screens.orders(ctx)
    nav.push(sc)
    local old = btnp
    btnp = function(b) return b == BTN_A end
    sc.update(nav)
    btnp = old
    C.eq(#nav.stack, 2, "Pferdeauswahl geöffnet")
    nav.stack[2].draw()
    ctx.orders = {}
    Screens.orders(ctx).draw()
  end},
}
